# Deployment Setup Notes

One-time setup required before the GitHub Actions pipeline (`.github/workflows/deploy.yml`)
can deploy successfully. This only needs to be done once per Azure subscription /
GitHub repository pair.

## 1. Why OIDC instead of a stored secret

The rest of this project deliberately avoids storing any credential (the Web
App authenticates to Storage and Key Vault via its Managed Identity, not a
key or connection string). The deployment pipeline follows the same
principle: instead of putting an Azure Service Principal **secret** into
GitHub, we use **OpenID Connect (OIDC) / Workload Identity Federation**.
GitHub issues a short-lived signed token for each workflow run; Azure AD
trusts that token for one specific repository and branch, and exchanges it
for a short-lived Azure access token. No password or client secret is ever
stored in GitHub.

## 2. Create an Azure AD App Registration

```bash
az ad app create --display-name "github-cloud-project-deploy"
```

Note the returned `appId` (this is your `AZURE_CLIENT_ID`).

Create a Service Principal for it and grant it permission to deploy to the
Web App's resource group:

```bash
az ad sp create --id <appId>

az role assignment create \
  --assignee <appId> \
  --role "Website Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-cloudproject-dev
```

## 3. Add a Federated Credential

This tells Azure AD to trust tokens issued by GitHub Actions for this
specific repository and branch:

```bash
az ad app federated-credential create \
  --id <appId> \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:husii42/cloud-project:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## 4. Add GitHub Repository Secrets

In GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
None of these are passwords; they are public identifiers (IDs), not secrets
in the cryptographic sense — but they still configure who is allowed to
authenticate, so keep them as Actions secrets rather than plain variables.

| Secret name              | Value                                  |
|---------------------------|-----------------------------------------|
| `AZURE_CLIENT_ID`          | `appId` from step 2                    |
| `AZURE_TENANT_ID`           | Your Azure AD tenant ID                |
| `AZURE_SUBSCRIPTION_ID`     | Your Azure subscription ID             |

## 5. Confirm the Web App name matches

The pipeline deploys to the App Service named in
`.github/workflows/deploy.yml` under `env.AZURE_WEBAPP_NAME`. This must
exactly match the name Terraform creates:
`app-${var.project_name}-${var.environment}` (see `modules/appservice/main.tf`).
With the default `terraform.tfvars` values, this is `app-cloudproject-dev`.
If you change `project_name` or `environment`, update the workflow file to match.
