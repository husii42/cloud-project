# Cloud and DevOps Engineering: Part I

*Aalen University  ·  Infrastructure as Code with Terraform on Azure  ·  Sweden Central*


## 1. What is this?

This project provisions a cloud infrastructure on Microsoft Azure using Terraform, an Infrastructure as Code (IaC) tool.
    Instead of manually creating resources in the Azure Portal, everything is defined in code and deployed automatically.

The following Azure resources are created:


## 2. Prerequisites

The following tools must be installed before running the Terraform definition:

```
$env:path += ";C:\Program Files\Terraform"
```


### How to Run

```
# 1. Clone the repository
git clone https://github.com/husii42/cloud-project.git
cd cloud-project

# 2. (Windows only) Add Terraform to PATH if not recognised
$env:path += ";C:\Program Files\Terraform"
# Restart PowerShell afterwards

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


### Local Terraform state

The Terraform state file ( terraform.tfstate ) is stored locally on the developer's machine.
    This means only the person who ran terraform apply can manage the infrastructure, and if the file is lost, Terraform loses track of all created resources.
    In a production setup, the state would be stored remotely in an Azure Storage Account (Remote Backend).
    However, this introduces a chicken-and-egg problem: the Storage Account is created by Terraform, but Terraform needs the Storage Account to exist before it can start.
    The solution is to create a separate Storage Account manually in the Azure Portal solely for the state, before running Terraform for the first time.
    For this project, local state is acceptable as it is managed by a single developer.


### Public blob container

The images container is set to public blob access, meaning anyone who knows the URL of a file can access it directly.
    For sensitive data this would be a problem. For this project, which stores images intended to be displayed on a public web page, public read access is intentional.


### No monitoring

There are no alerts, diagnostics, or logging resources configured.
    If the application crashes or unexpected usage occurs (e.g. a large number of uploads), there is no automated notification.
    In a production setup, Azure Monitor and Application Insights would be added to the infrastructure.


## 6. Outlook: Part II

Part II extends this infrastructure with application code and a deployment pipeline. The following will be added:

The infrastructure defined in Part I requires no changes. Part II only adds to it.

