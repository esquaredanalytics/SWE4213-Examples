#!/usr/bin/env bash
###############################################################################
# deploy.sh — Build, push, and deploy the Video Streaming app to Azure
#
# Prerequisites:
#   - Azure CLI (az) installed and logged in:  az login
#   - Docker installed and running
#   - kubectl installed
#   - Terraform installed (>= 1.5)
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
###############################################################################

set -euo pipefail

# ── 1. Provision infrastructure with Terraform ──────────────────────────────
echo "==> Initialising Terraform..."
terraform init

echo "==> Applying Terraform configuration..."
terraform apply -auto-approve

# Read outputs
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
echo "==> ACR login server: $ACR_LOGIN_SERVER"

# ── 2. Configure kubectl ─────────────────────────────────────────────────────
echo "==> Fetching AKS credentials..."
eval "$(terraform output -raw kubeconfig_command)"

# ── 3. Log in to ACR ─────────────────────────────────────────────────────────
echo "==> Logging in to ACR..."
az acr login --name "$ACR_LOGIN_SERVER"

# ── 4. Build & push Docker images ────────────────────────────────────────────
# Build for linux/amd64 explicitly — AKS nodes are x86_64.
# Using plain docker build (not buildx) to produce a simple single-arch image
# that AKS containerd can pull without manifest-list resolution issues.
SERVICES=("gateway" "video-streaming" "video-storage" "history")
CONTEXT_DIRS=("../gateway" "../video-streaming" "../video-storage" "../history")

for i in "${!SERVICES[@]}"; do
  SERVICE="${SERVICES[$i]}"
  CONTEXT="${CONTEXT_DIRS[$i]}"
  IMAGE="$ACR_LOGIN_SERVER/$SERVICE:latest"

  echo "==> Building $IMAGE from $CONTEXT (linux/amd64)..."
  docker build --platform linux/amd64 -t "$IMAGE" "$CONTEXT"

  echo "==> Pushing $IMAGE ..."
  docker push "$IMAGE"
done

# ── 5. Patch Kubernetes manifests to use ACR image paths ────────────────────
echo "==> Patching kubernetes manifests..."
TMP_K8S=$(mktemp -d)
cp -r ../kubernetes/* "$TMP_K8S/"

# Replace bare image names with fully qualified ACR paths.
# sed -i '' is required on macOS; GNU sed ignores the empty string.
for SERVICE in gateway video-streaming video-storage history; do
  find "$TMP_K8S" -name "*.yaml" -exec \
    sed -i '' "s|image: $SERVICE:latest|image: $ACR_LOGIN_SERVER/$SERVICE:latest|g" {} \;
done

# ── 6. Apply Kubernetes manifests ────────────────────────────────────────────
echo "==> Applying secrets & configmap..."
kubectl apply -f "$TMP_K8S/secrets.yaml"
kubectl apply -f "$TMP_K8S/configmap.yaml"

echo "==> Applying infrastructure resources..."
kubectl apply -f "$TMP_K8S/postgres.yaml"
kubectl apply -f "$TMP_K8S/rabbitmq.yaml"

echo "==> Waiting for postgres and rabbitmq to be ready..."
kubectl rollout status deployment/db       --timeout=180s
kubectl rollout status deployment/rabbitmq --timeout=120s

echo "==> Applying application services..."
kubectl apply -f "$TMP_K8S/video-storage.yaml"
kubectl apply -f "$TMP_K8S/history.yaml"
kubectl apply -f "$TMP_K8S/video-streaming.yaml"
kubectl apply -f "$TMP_K8S/gateway.yaml"

# Ensure imagePullPolicy is Always so AKS always fetches the latest image from ACR.
# This is required when deploying from an Apple Silicon Mac because the nodes are
# amd64 — without Always, AKS reuses any cached ARM image already on the node.
echo "==> Setting imagePullPolicy to Always on all app deployments..."
for DEP in video-storage video-streaming history gateway; do
  kubectl patch deployment "$DEP" \
    -p '{"spec":{"template":{"spec":{"containers":[{"name":"'"$DEP"'","imagePullPolicy":"Always"}]}}}}'
done

echo "==> Waiting for all deployments to be ready..."
kubectl rollout status deployment/video-storage   --timeout=180s
kubectl rollout status deployment/history         --timeout=180s
kubectl rollout status deployment/video-streaming --timeout=180s
kubectl rollout status deployment/gateway         --timeout=180s

# ── 7. Print the gateway's public IP ─────────────────────────────────────────
echo ""
echo "==> Deployment complete! Waiting for gateway external IP..."
echo "    (This may take 1–2 minutes while Azure provisions the load balancer)"
echo ""

for i in $(seq 1 24); do
  EXTERNAL_IP=$(kubectl get service gateway \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [[ -n "$EXTERNAL_IP" ]]; then
    echo "==> Gateway is live at: http://$EXTERNAL_IP:3000"
    break
  fi
  echo "    Waiting... ($i/24)"
  sleep 5
done

if [[ -z "${EXTERNAL_IP:-}" ]]; then
  echo "==> IP not yet assigned. Run: kubectl get service gateway"
fi

# Cleanup temp directory
rm -rf "$TMP_K8S"
