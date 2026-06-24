# Cloud and DevOps Engineering: Part I & II

*Aalen University  ·  Infrastructure as Code with Terraform on Azure  ·  Hüseyin Simsek  ·  Summer Semester 2026*


## 1. What is this?

This project provisions a cloud infrastructure on Microsoft Azure using Terraform, an Infrastructure as Code (IaC) tool.
    Instead of manually creating resources in the Azure Portal, everything is defined in code and deployed automatically.

The following Azure resources are created:


## 2. Prerequisites

The following tools must be installed before running the Terraform definition:

```
- Terraform ≥ 1.5.0 https://developer.hashicorp.com/terraform/install
- Azure CLI latest https://learn.microsoft.com/cli/azure/install-azure-cli
- Git any https://git-scm.com
- Azure Subscription active A student subscription is sufficient
```

### How to Run (in PowerShell)

```
# 1. Clone the repository
git clone https://github.com/husii42/cloud-project.git
cd cloud-project

# 2. (Windows only) Add Terraform to PATH if not recognised
$env:path += ";C:\Program Files\Terraform"

# 3. Create the variables file and set a unique project_name
cp terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars

# 4. Authenticate with Azure
az login

# 5. Initialise Terraform (downloads the Azure provider)
terraform init

# 6. Preview what will be created
terraform plan

# 7. Deploy the infrastructure
terraform apply
```


## 3. Repository Structure

```
cloud-project/
├── main.tf                   # Root module: connects all modules together
├── variables.tf              # Input variables (project_name, environment, location)
├── outputs.tf                # Values displayed after terraform apply
├── providers.tf              # Azure provider version and configuration
├── terraform.tfvars.example  # Template for local variables (copy to .tfvars)
├── .gitignore                # Excludes state files and .tfvars from Git
└── modules/
    ├── storage/
    │   ├── main.tf           # Creates Storage Account and images container
    │   ├── variables.tf      # Input variables for the module
    │   └── outputs.tf        # Exports storage name, endpoint, access key
    ├── keyvault/
    │   ├── main.tf           # Creates Key Vault, access policies and secrets
    │   ├── variables.tf      # Input variables for the module
    │   └── outputs.tf        # Exports Key Vault name and URI
    └── appservice/
        ├── main.tf           # Creates App Service Plan and Web App
        ├── variables.tf      # Input variables for the module
        └── outputs.tf        # Exports hostname and Managed Identity ID
```


### How the files work together

terraform.tfvars provides the values (project name, region, environment). variables.tf defines which values are expected. main.tf passes those values into each module and connects their outputs —
    for example, the Storage Account access key is read from the storage module and passed directly into the Key Vault module, which stores it as a secret.
    After deployment, outputs.tf displays all relevant resource names and URLs in the terminal.


## 4. Approach & Reasoning


### Modular structure

The infrastructure is split into three modules (Storage, Key Vault, App Service) rather than placing everything in a single main.tf file.
    Each module is responsible for exactly one concern: it receives input variables, creates its resources, and exposes outputs.
    The root main.tf acts as the orchestrator: it passes values into each module and connects their outputs where needed.

This separation has a practical benefit for this project: in Part II, nothing in the existing code needs to be modified.
    New resources, pipeline configuration, and application settings are simply added on top.
    Had everything been written in one file, adding Part II would require editing existing resources, which risks unintended changes or data loss.


### Key Vault for sensitive data

The Storage Account access key is a sensitive credential: anyone who holds it has full read and write access to the storage.
    Storing it directly in application code or committing it to Git would expose it to anyone with access to the repository.

Instead, Terraform reads the access key from the Storage Account after creation and stores it automatically as a secret in Azure Key Vault.
    The application in Part II will retrieve this secret at runtime, meaning the actual credential never appears in code or configuration files.
    Access to the Key Vault is controlled via Access Policies: the developer has full access during deployment, and the App Service will be granted read-only access in Part II.


### Managed Identity instead of passwords

A common approach for giving an application access to Azure resources is to create a service principal with a client secret (essentially a username and password).
    The problem with this approach is that the secret needs to be stored somewhere: in environment variables, configuration files, or a pipeline, which creates another credential that can be accidentally exposed.

By assigning the App Service a System-Assigned Managed Identity, Azure manages the authentication automatically.
    The application proves its identity to the Key Vault through Azure's internal infrastructure, so no password is ever created, stored, or rotated manually.
    This removes an entire category of credential management from the project.


### Full infrastructure defined in Part I

The App Service, Key Vault, and Storage Account are all provisioned in Part I, even though the application code is not written until Part II.
    These resources form the foundation the web application needs to run securely in the cloud.

Provisioning everything upfront also avoids a practical problem with Terraform: if a resource is created, used to store data, and then needs to be replaced in a later apply, Terraform must destroy the existing resource first.
    This would delete any data already stored in it. By defining the full infrastructure from the beginning, Part II can simply extend what is already there without triggering any destructive changes.


### Upload authentication

The Storage Account currently permits GET, POST and PUT requests from any origin via CORS.
    This is intentional at the infrastructure level: the Storage Account itself does not need to know who is allowed to upload files, because uploads do not go directly from the browser to Azure Storage.
    Instead, the request flows through the App Service, which acts as an intermediary:

```
Browser → App Service → Storage Account
```

The App Service is the only component that communicates directly with the Storage Account.
    Authentication, meaning deciding whether a specific user is allowed to upload, is therefore handled in the application code in Part II, not by Terraform.
    Terraform governs access at the Azure infrastructure level; the application governs access at the user level.


## 5. Known Limitations


### Cost

The App Service Plan (B1) costs approximately €13/month. If terraform destroy is not run after the project is complete,
    the resources continue to run and incur charges. This is especially relevant for student subscriptions with a fixed budget limit.


### No environment separation

The infrastructure currently only has a single environment ( dev ).
    In a production context, separate environments (e.g. staging, prod) would be used so that changes can be tested before affecting live data.
    For this project scope, a single environment is sufficient.


### Remote Terraform state (addressed)

Originally, the Terraform state file (`terraform.tfstate`) was stored only locally on the developer's machine, meaning
    only the person who ran `terraform apply` could manage the infrastructure, and a lost file would mean Terraform losing
    track of all created resources. This has since been addressed with a `bootstrap/` configuration: a small, separate
    Terraform setup that creates a dedicated Storage Account solely for holding the main project's state, solving the
    chicken-and-egg problem where the main Storage Account is created by Terraform but a remote backend needs a Storage
    Account to exist first. See `bootstrap/main.tf` and the commented-out `backend "azurerm" {}` block in `providers.tf`
    for the exact migration steps. The bootstrap configuration's own state remains local, since it consists of a handful
    of resources that essentially never change after creation.


### Globally unique resource names (addressed)

Storage Account and Key Vault names must be unique across all of Azure, not just within this subscription. Relying on
    `project_name` alone risked a naming collision with someone else's resource of the same name. A `random_string` resource
    now generates a short suffix once (kept stable in the state file across subsequent applies) and appends it to both
    names, e.g. `stcloudprojectdevab12c`.


### Consistent authorization model (addressed)

Storage access for the Web App's Managed Identity was already implemented as an Azure RBAC role assignment
    (`Storage Blob Data Contributor`). Key Vault access, however, originally used the older, Key-Vault-specific
    Access Policy model instead of RBAC — two different authorization systems within the same project. The Key Vault
    now has `enable_rbac_authorization = true`, and both the developer's own access (`Key Vault Administrator`) and the
    Web App's access (`Key Vault Secrets User`) are granted via `azurerm_role_assignment`, consistent with the Storage Account.


### Deployment identity (addressed, optional)

By default, `terraform apply` is run authenticated as the developer's own Azure AD user via `az login`. As an alternative,
    `spn-deployment-notes.md` documents creating a dedicated Service Principal for Terraform deployments specifically —
    separate from the Service Principal used by the GitHub Actions pipeline, since the two serve different actors and purposes
    (a human running Terraform locally vs. an automated pipeline deploying application code). This is offered as an option
    rather than a requirement, since a single-developer student project does not strictly need this separation, but it
    demonstrates the pattern used in team/production settings.


### Public blob container

The images container is set to public blob access, meaning anyone who knows the URL of a file can access it directly.
    For sensitive data this would be a problem. For this project, which stores images intended to be displayed on a public web page, public read access is intentional.


### No monitoring

There are no alerts, diagnostics, or logging resources configured.
    If the application crashes or unexpected usage occurs (e.g. a large number of uploads), there is no automated notification.
    In a production setup, Azure Monitor and Application Insights would be added to the infrastructure.


## 6. Part II: Application & Deployment Pipeline

Part II adds the application layer and CI/CD pipeline on top of the Part I infrastructure.
    No resources defined in Part I were modified in a destructive way; only new resources
    (role assignments, access policies, app settings) and a new `app/` directory were added.


### 6.1 Description

The application is a small Flask web app with two pages:

- **Web Page 1 (`/`)**: lists every file currently stored in the Blob Storage container,
    showing its name, size and last-modified date, with a direct download link for each file.
    It also links to Web Page 2.
- **Web Page 2 (`/upload`)**: a form that lets a user choose a file and upload it to the
    same Blob Storage container.

The app is packaged and deployed automatically by a GitHub Actions pipeline whenever the
    application code changes on the `main` branch.


### 6.2 Approach

```
Browser → Web Page 1 / Web Page 2 → Flask App (App Service) → Blob Storage Container
```

The Flask app is the only component that talks to Azure directly. The browser never
    receives any Azure credential; it only ever talks to the Flask app, which in turn
    authenticates to Storage on the app's own identity. This matches the approach already
    described in Part I (`Upload authentication`): the Storage Account does not need to know
    who is allowed to upload, because the App Service sits between the browser and the storage.

The Python `azure-storage-blob` and `azure-identity` SDKs are used. `DefaultAzureCredential`
    automatically uses the Web App's Managed Identity when running on Azure, and falls back to
    the developer's own `az login` session when running locally — so the same code works in
    both places without any code change or local secret.


### 6.3 Connections between resources

| From | To | How |
|------|----|-----|
| Web App (Managed Identity) | Storage Account | `azurerm_role_assignment` granting "Storage Blob Data Contributor" on the Storage Account, scoped to the Web App's `principal_id` |
| Web App (Managed Identity) | Key Vault | `azurerm_key_vault_access_policy` granting `Get`/`List` on secrets, scoped to the Web App's `principal_id` |
| Web App | Storage Account / Key Vault names | Passed in as App Settings (`AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_STORAGE_CONTAINER_NAME`, `KEY_VAULT_URI`) so the app code never hardcodes resource names |
| GitHub Actions | Azure subscription | OIDC / Workload Identity Federation (no stored client secret); see `deployment-notes.md` |
| GitHub Actions | Web App | `azure/webapps-deploy` action pushes the packaged Flask app to the App Service |

A note on module wiring in Terraform: `module.appservice` is evaluated independently of
    `module.storage` and `module.keyvault` (it only needs the Resource Group), while both of
    those modules depend on `module.appservice.managed_identity_principal_id` to grant access.
    The Key Vault URI and Storage Account name passed into `appservice` are computed directly
    from the shared naming convention (`var.project_name` / `var.environment`) rather than read
    back from the other modules' outputs — referencing those outputs directly would create a
    circular dependency between modules (`appservice → keyvault → appservice`), which Terraform
    cannot resolve.


### 6.4 Authentication / Identity context

No credential (key, password, or connection string) is stored in the application code,
    GitHub repository secrets, or App Service configuration:

- **App → Storage**: System-Assigned Managed Identity, granted the **Storage Blob Data
    Contributor** role (read/write/delete blobs only — not account keys or account-level
    settings, following least privilege).
- **App → Key Vault**: same Managed Identity, granted read-only (`Get`, `List`) secret access.
    The app does not currently need to read any Key Vault secret at runtime (it authenticates
    to Storage via the Managed Identity directly), but the access policy demonstrates the same
    identity can be used uniformly across both resources. The Storage Account access key
    remains stored in Key Vault as in Part I, purely as a demonstration of the secret-management
    pattern — it is not read by the application.
- **GitHub Actions → Azure**: OIDC / Workload Identity Federation. GitHub issues a short-lived
    signed token per workflow run; Azure AD trusts it for this specific repository and branch
    and exchanges it for a short-lived Azure access token. See `deployment-notes.md` for the
    one-time setup.
- **Browser → App**: no authentication is implemented at this layer (anyone with the URL can
    upload). This mirrors the Part I decision that upload authorization is an application-level
    concern, and is acceptable for this project's scope (see Known Limitations).


### 6.5 Repository structure addition

```
cloud-project/
├── app/
│   ├── app.py                 # Flask application (both pages + health check)
│   ├── requirements.txt       # Python dependencies
│   ├── templates/             # Jinja2 templates (base, index, upload)
│   └── static/style.css        # Shared styling
├── .github/workflows/
│   └── deploy.yml             # CI/CD pipeline: build → test → deploy → verify
├── bootstrap/
│   └── main.tf                 # Separate config: creates the remote-state Storage Account
├── deployment-notes.md        # One-time OIDC setup instructions (GitHub Actions)
└── spn-deployment-notes.md    # Optional: dedicated Service Principal for `terraform apply`
```


### 6.6 Known limitations (Part II)

- No upload authentication at the application layer (see 6.4) — acceptable for this
    project's scope, since the goal is to demonstrate the infrastructure and identity
    pattern, not a production-grade access control system.
- The Key Vault secret holding the Storage Account access key is unused by the application
    code; it is retained from Part I purely to show the secret-storage pattern still works
    alongside Managed Identity access.
- The pipeline deploys directly to a single environment (`dev`); there is no staging slot
    or blue-green deployment, consistent with the single-environment scope from Part I.


