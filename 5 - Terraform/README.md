# Activity 5 — Deploying to Azure with Terraform

In this activity we deploy a full-stack portfolio app to Azure using Terraform to manage all the cloud infrastructure.

## What we're building

A portfolio website with:
- **Frontend** — React app built with Vite, showing your profile, skills, and projects
- **Backend** — Node.js/Express API that reads data from a PostgreSQL database
- **Database** — Azure Database for PostgreSQL (Flexible Server)

Everything runs as a single Docker container inside **Azure Container Apps** — a serverless container platform that's simpler than Kubernetes for single-service apps.

```
Browser → Azure Container App (React + Express) → Azure PostgreSQL
```

---

## Project structure

```
5 - Terraform/
├── frontend/               # Vite React app
│   ├── src/
│   │   ├── main.jsx
│   │   └── App.jsx         # Fetches /api/* and renders the portfolio
│   ├── index.html
│   ├── vite.config.js      # Proxies /api to backend in dev
│   └── package.json
│
├── backend/                # Express API
│   ├── src/
│   │   └── index.js        # API routes + serves built frontend
│   ├── Dockerfile          # Build context is repo root
│   └── package.json
│
├── terraform/              # Azure infrastructure
│   ├── main.tf             # Resource definitions
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Values printed after apply
│   └── terraform.tfvars.example
│
├── deploy.sh               # One-command deploy script
└── README.md
```

---

## What Terraform provisions

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all resources |
| Azure Container Registry (ACR) | Stores the Docker image |
| Azure PostgreSQL Flexible Server | Managed PostgreSQL database |
| Log Analytics Workspace | Collects container logs |
| Container Apps Environment | Shared runtime for Container Apps |
| Azure Container App | Runs the portfolio container, exposed publicly |

---

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker](https://www.docker.com/products/docker-desktop/) installed and running
- [Node.js](https://nodejs.org/) >= 18

---

## Step 1 — Register Azure resource providers

Azure organizes its services into **resource providers**. Before Terraform can create Container Apps or Log Analytics resources, your subscription needs to be registered to use those providers. This is a one-time step per subscription.

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

Wait for registration to complete (about 1 minute), then verify:

```bash
az provider show --namespace Microsoft.App --query registrationState
az provider show --namespace Microsoft.OperationalInsights --query registrationState
```

Both should return `"Registered"` before proceeding.

> **Why is this needed?** When you use a service through the Azure portal for the first time, it auto-registers the provider for you. When using Terraform or the CLI directly, that auto-registration doesn't always happen — so you register manually instead.

---

## Step 2 — Configure your variables

Copy the example vars file and fill in your own values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
resource_group_name = "portfolio-rg"
location            = "canadacentral"
acr_name            = "myportfolioacr123"   # Must be globally unique, alphanumeric only
app_name            = "portfolio"
db_server_name      = "myportfolio-db-123"  # Must be globally unique
db_admin_user       = "pgadmin"
db_admin_password   = "ChangeMe123!"
```

> **Never commit `terraform.tfvars`** — it contains your database password. Add it to `.gitignore`.

---

## Step 3 — Log in to Azure

```bash
az login
```

---

## Step 4 — Deploy everything

From the `5 - Terraform/` directory:

```bash
chmod +x deploy.sh
./deploy.sh
```

The script does the following in order:

1. **`terraform init`** — downloads the Azure provider plugin
2. **`terraform apply`** — provisions the Resource Group, ACR, PostgreSQL, and Container App
3. **`npm run build`** — builds the React frontend into `frontend/dist/`
4. **`docker build`** — packages the backend + built frontend into a single `linux/amd64` image
5. **`docker push`** — pushes the image to ACR
6. **`az containerapp update`** — forces the Container App to pull and run the new image

At the end it prints your app's public URL:

```
==> Portfolio is live at: https://portfolio.nicedomain.azurecontainerapps.io
```

---

## Step 5 — Verify it works

Open the URL in your browser. You should see the portfolio page with profile, skills, and projects loaded from the database.

To check the API directly:

```bash
curl https://<your-url>/api/profile
curl https://<your-url>/api/skills
curl https://<your-url>/api/projects
```

---

## Running locally (without Azure)

Start a local PostgreSQL instance (e.g. via Docker):

```bash
docker run -d \
  --name portfolio-db \
  -e POSTGRES_DB=portfolio \
  -e POSTGRES_USER=pgadmin \
  -e POSTGRES_PASSWORD=localpassword \
  -p 5432:5432 \
  postgres:16
```

Install dependencies and start the backend:

```bash
cd backend && npm install
DB_HOST=localhost DB_NAME=portfolio DB_USER=pgadmin DB_PASSWORD=localpassword node src/index.js
```

In a separate terminal, start the frontend dev server:

```bash
cd frontend && npm install && npm run dev
```

Open [http://localhost:5173](http://localhost:5173). The Vite dev server proxies `/api` calls to the backend at `localhost:3000`.

---

## How the deployment works — key concepts

### Why Terraform?

Instead of clicking through the Azure portal to create each resource by hand, Terraform lets you describe your infrastructure as code. This means:
- The setup is **repeatable** — anyone can run `terraform apply` and get the same result
- It's **version controlled** — infrastructure changes are tracked in git like code changes
- It's **easy to tear down** — `terraform destroy` removes everything cleanly

### Why Azure Container Apps instead of AKS?

AKS (Kubernetes) is powerful but has a lot of moving parts. Azure Container Apps is a managed layer on top of Kubernetes — you don't manage nodes, deployments, or services directly. For a single-service app, Container Apps is much simpler.

### Why one container for frontend and backend?

The backend serves the built React files as static assets. This means:
- One image to build and push
- One service to deploy and scale
- No CORS configuration needed (frontend and API are on the same origin)

In production you might separate them — but for a course project, this approach is clean and straightforward.

### The `:latest` tag problem

Docker tags like `:latest` don't change when you push a new image — the tag name stays the same. Azure Container Apps won't automatically redeploy when the image contents change. That's why the deploy script runs `az containerapp update` at the end — it forces Azure to pull and run the new image.

---

## Cleaning up

To delete all Azure resources and avoid ongoing charges:

```bash
cd terraform
terraform destroy
```

Terraform will list everything it plans to delete and ask for confirmation before proceeding.