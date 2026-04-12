#!/usr/bin/env bash
###############################################################################
# deploy.sh — Build and deploy the Portfolio App to Azure
#
# Prerequisites:
#   - Azure CLI (az) installed and logged in:  az login
#   - Docker installed and running
#   - Node.js installed (for building the frontend)
#   - Terraform installed (>= 1.5)
#
# Usage (run from the root of 5 - Terraform/):
#   chmod +x deploy.sh
#   ./deploy.sh
###############################################################################

set -euo pipefail

# ── 1. Provision ACR and database (not the Container App yet) ───────────────
# The Container App requires the Docker image to already exist in ACR.
# We use -target to provision only the prerequisite resources first.
echo "==> Initialising Terraform..."
cd terraform
terraform init

echo "==> Provisioning ACR and database..."
terraform apply -auto-approve \
  -target=azurerm_resource_group.main \
  -target=azurerm_container_registry.acr \
  -target=azurerm_postgresql_flexible_server.db \
  -target=azurerm_postgresql_flexible_server_database.portfolio \
  -target=azurerm_postgresql_flexible_server_firewall_rule.azure_services \
  -target=azurerm_log_analytics_workspace.main \
  -target=azurerm_container_app_environment.main

ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
cd ..

echo "==> ACR: $ACR_LOGIN_SERVER"

# ── 2. Build the React frontend ───────────────────────────────────────────────
echo "==> Installing frontend dependencies..."
npm install --prefix frontend

echo "==> Building frontend..."
npm run build --prefix frontend

# ── 3. Log in to ACR ─────────────────────────────────────────────────────────
echo "==> Logging in to ACR..."
az acr login --name "$ACR_LOGIN_SERVER"

# ── 4. Build & push the Docker image ─────────────────────────────────────────
# Build context is the repo root so the Dockerfile can access both
# backend/ and the freshly-built frontend/dist/.
IMAGE="$ACR_LOGIN_SERVER/portfolio:latest"

echo "==> Building image (linux/amd64)..."
docker build --platform linux/amd64 -t "$IMAGE" -f backend/Dockerfile .

echo "==> Pushing image..."
docker push "$IMAGE"

# ── 5. Provision the Container App (image now exists in ACR) ─────────────────
echo "==> Provisioning Container App..."
cd terraform
terraform apply -auto-approve
APP_URL=$(terraform output -raw app_url)
cd ..

# ── 6. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Deployment complete!"
echo "==> Portfolio is live at: $APP_URL"