# Service Principal for Terraform Deployment

By default, this project is deployed by running `terraform apply` while
authenticated as your own Azure AD user (`az login`). This file documents an
alternative: authenticating as a dedicated **Service Principal (SPN)** instead.

## Why use an SPN instead of your own user account?

- **Reproducibility**: a service principal has fixed, explicit permissions
  (only what is granted via role assignment), whereas your own user account
  may have broader subscription-level access that masks missing permissions
  in the Terraform configuration itself.
- **Separation of identity from person**: deployments aren't tied to a
  specific human's session or MFA; any team member (or a future CI job) can
  use the same SPN credential, scoped to exactly this project.
- **Consistency with the rest of the project**: GitHub Actions already
  authenticates to Azure as its own service principal (via OIDC, see
  `deployment-notes.md`). Using a separate SPN for manual/local Terraform
  runs follows the same pattern, just for a different actor.

This SPN is intentionally **separate** from the one used by the GitHub
Actions pipeline (`github-cloud-project-deploy`). They serve different
purposes: this one is for a human running `terraform apply` from their own
machine; the pipeline's SPN is for the automated deployment of the
*application code*, scoped to `Website Contributor` on the resource group
only (it cannot create or destroy infrastructure).


## 1. Create the Service Principal

```powershell
az ad sp create-for-rbac `
  --name "sp-terraform-husi42firstwebapp" `
  --role "Contributor" `
  --scopes /subscriptions/<subscription-id> `
  --query "{appId:appId, password:password, tenant:tenant}"
```

This prints three values: `appId`, `password`, `tenant`. The `password`
value is shown **only once** — store it immediately in a password manager
or secret store, never in a file inside this repository.

> **Scope note**: `--scopes /subscriptions/<subscription-id>` grants
> Contributor access to the entire subscription, which is necessary because
> this SPN needs to create the Resource Group itself (a narrower scope, like
> an existing resource group, would not allow that). If the Resource Group
> is created once manually and never re-created by Terraform, the scope
> could be narrowed to just that Resource Group instead.


## 2. Authenticate Terraform as the Service Principal

Instead of `az login`, export these environment variables in the same shell
session before running Terraform commands:

```powershell
$env:ARM_CLIENT_ID       = "<appId>"
$env:ARM_CLIENT_SECRET   = "<password>"
$env:ARM_TENANT_ID       = "<tenant>"
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
```

The `azurerm` provider automatically picks up these `ARM_*` environment
variables — no change to any `.tf` file is needed. Then proceed as usual:

```powershell
terraform init
terraform plan
terraform apply
```

To switch back to your own user account afterward, simply close the
terminal session (or unset the four variables) and run `az login` again.


## 3. Clean-up

The SPN itself does not incur any cost, but it remains a standing credential
as long as it exists. Once it is no longer needed (e.g. after grading),
remove it:

```powershell
az ad sp delete --id <appId>
```
