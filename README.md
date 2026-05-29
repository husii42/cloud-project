# Cloud Project – Part I
### Principles of Cloud and DevOps Engineering | Aalen University

---

## Approach

This project provisions a reusable Azure infrastructure using **Terraform** (Infrastructure-as-Code).  
The design prioritises **modularity**: every resource lives in its own module so Part II can extend the infrastructure without rewriting anything.

**Authentication** uses **Azure CLI** (`az login`) locally.  
No secrets are stored in `.tf` files. Sensitive values (e.g. storage keys) are written to **Azure Key Vault** automatically by Terraform.

---

## Architecture – Connections Between Resources

```
┌─────────────────────────────────────────────────────────┐
│                  Azure Resource Group                   │
│                                                         │
│  ┌──────────────┐       ┌──────────────────────────┐   │
│  │ Storage Acct │◄──────│       Key Vault           │   │
│  │              │       │  secret: conn-string      │   │
│  │ [images]     │       └──────────────┬───────────┘   │
│  └──────────────┘                      │               │
│                                        │ Access Policy  │
│  ┌──────────────────────────┐          │               │
│  │   App Service (Part II)  │──────────┘               │
│  │   Managed Identity       │  reads secrets via MSI   │
│  └──────────────────────────┘                          │
└─────────────────────────────────────────────────────────┘

Current user (az login) ──► Key Vault (full access policy)
```

**Data flows:**
- Terraform reads the Storage Account's primary key and stores it as a Key Vault secret
- The App Service (Part II) reads the secret via its **System-Assigned Managed Identity** – no credentials in code
- The Storage Container `images` is public-read so uploaded blobs are accessible via URL

---

## Authentication / Identity Context

| Identity | Type | Access |
|---|---|---|
| Developer (`az login`) | Azure CLI user | Key Vault – full secret/key CRUD |
| App Service | System-Assigned Managed Identity | Key Vault – read secrets (added in Part II) |
| Terraform | Azure CLI session | Subscription – create/manage resources |

Secrets are **never** stored in:
- `.tf` source files
- Git repository
- `terraform.tfvars` (listed in `.gitignore`)

---

## Repository Structure

```
terraform-project/
├── main.tf                  # Root module – wires all modules together
├── variables.tf             # Input variables
├── outputs.tf               # Exported values
├── providers.tf             # Azure provider + Terraform version
├── terraform.tfvars.example # Template – copy to terraform.tfvars (git-ignored)
├── .gitignore
├── README.md
└── modules/
    ├── storage/             # Azure Storage Account + Blob Container
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── keyvault/            # Azure Key Vault + Access Policies + Secrets
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── appservice/          # App Service Plan + Linux Web App (prepared for Part II)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | ≥ 1.5 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | latest | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Azure Subscription | – | Student subscription works |

---

## Getting Started

```bash
# 1. Authenticate with Azure
az login

# 2. (Optional) Select a specific subscription
az account set --subscription "<subscription-id>"

# 3. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars – set project_name, environment, location

# 4. Initialise Terraform (downloads providers)
terraform init

# 5. Preview the changes
terraform plan

# 6. Apply – creates all resources in Azure
terraform apply
```

After `terraform apply` succeeds, the outputs show all resource names and endpoints.

---

## Naming Conventions

| Resource | Name pattern | Example |
|---|---|---|
| Resource Group | `rg-<project>-<env>` | `rg-cloudproject-dev` |
| Storage Account | `st<project><env>` | `stcloudprojectdev` |
| Key Vault | `kv-<project>-<env>` | `kv-cloudproject-dev` |
| App Service Plan | `asp-<project>-<env>` | `asp-cloudproject-dev` |
| Web App | `app-<project>-<env>` | `app-cloudproject-dev` |

---

## What Part II Will Add

- Pipeline YAML (Azure DevOps or GitHub Actions) for automated deployment
- Application code (Web Page 1: list blobs / Web Page 2: upload form)
- Key Vault access policy for the App Service Managed Identity
- App Settings wiring (`KEY_VAULT_URI`, `STORAGE_CONTAINER_NAME`)

> The infrastructure defined here requires **no changes** for Part II – only additions.
