# Bicep Labs — Azure Function + Key Vault with RBAC

Infrastructure-as-Code project that deploys an **Azure Function App** and an **Azure Key Vault**, then grants the Function App's **system-assigned managed identity** least-privilege access to both Key Vault and the Storage Account via Azure RBAC role assignments. The Function App uses **Entra ID (identity-based) authentication** to the Storage Account — no storage keys or connection strings are used. Deployment is automated through a **GitHub Actions** CI/CD pipeline.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Resource Group                                │
│                                                                         │
│  ┌──────────────────┐     ┌───────────────────────────────────┐         │
│  │   Key Vault      │◄────│   Key Vault Role Assignments      │         │
│  │  (RBAC-enabled)  │     │  • Key Vault Secrets User         │         │
│  └──────────────────┘     │  • Key Vault Crypto User          │         │
│           ▲               │  • Key Vault Reader               │         │
│           │ KEY_VAULT_URI  └──────────────────┬────────────────┘         │
│           │                                  │                          │
│  ┌────────┴──────────────────────────────────┴─────────────────────┐    │
│  │                   Function App (Linux)                          │    │
│  │              System-Assigned Managed Identity                   │    │
│  │           (Entra ID identity-based storage access)              │    │
│  │                                                                 │    │
│  │  ┌─────────────────┐    ┌────────────────────┐                  │    │
│  │  │ App Service Plan │    │  Storage Account   │                  │    │
│  │  │  (Consumption)   │    │  (Functions runtime)│                 │    │
│  │  └─────────────────┘    └────────┬───────────┘                  │    │
│  └──────────────────────────────────┼──────────────────────────────┘    │
│                                     │                                   │
│                          ┌──────────▼───────────────────────────┐       │
│                          │  Storage Role Assignments            │       │
│                          │  • Storage Blob Data Owner           │       │
│                          │  • Storage Queue Data Contributor    │       │
│                          │  • Storage File Data Priv. Contrib.  │       │
│                          │  • Storage Account Contributor       │       │
│                          └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy-infra.yml             # Infrastructure deployment pipeline
│       └── deploy-function.yml          # Function App code deployment pipeline
├── src/
│   ├── function_app.py                  # Python function: list Key Vault keys & secrets
│   ├── host.json                        # Functions host configuration
│   ├── requirements.txt                 # Python dependencies
│   ├── local.settings.json              # Local development settings
│   └── .funcignore                      # Files to exclude from deployment
├── infra/
│   ├── modules/                         # Reusable Bicep modules
│   │   ├── appInsights.bicep            # App Insights + Log Analytics workspace
│   │   ├── keyVault.bicep               # Key Vault resource
│   │   ├── functionApp.bicep            # Function App + Plan + Storage
│   │   └── roleAssignments.bicep        # Generic RBAC role assignments (any scope)
│   └── stacks/                          # Deployable stacks (each has main.bicep + params)
│       ├── core/
│       │   ├── main.bicep               # Function App + Key Vault + Storage + RBAC
│       │   └── main.bicepparam          # Parameters for core stack
│       └── monitoring/
│           ├── main.bicep               # Application Insights + Log Analytics
│           └── main.bicepparam          # Parameters for monitoring stack
├── setup/
│   ├── create-app-registration.sh       # Create Azure AD app + service principal + role assignments
│   └── create-federated-credentials.sh  # Create OIDC federated credentials for GitHub Actions
└── README.md
```

## Stacks

The project organizes deployable templates into **stacks** — self-contained directories under `infra/stacks/`, each with its own `main.bicep` and `main.bicepparam`. Stacks share reusable modules from `infra/modules/`.

| Stack | Directory | Description |
|---|---|---|
| `core` | `infra/stacks/core/` | Function App + Key Vault + Storage + RBAC role assignments |
| `monitoring` | `infra/stacks/monitoring/` | Application Insights + Log Analytics workspace |

## Resources Deployed

| Resource | Type | Description |
|---|---|---|
| **Key Vault** | `Microsoft.KeyVault/vaults` | Standard SKU, RBAC authorization enabled, soft-delete (90 days) |
| **Function App** | `Microsoft.Web/sites` | Linux, Python 3.11, system-assigned managed identity |
| **App Service Plan** | `Microsoft.Web/serverfarms` | Consumption tier (Y1/Dynamic) |
| **Storage Account** | `Microsoft.Storage/storageAccounts` | Standard LRS, required by the Functions runtime |
| **Key Vault Role Assignments** | `Microsoft.Authorization/roleAssignments` | Key Vault Secrets User + Key Vault Crypto User + Key Vault Reader |
| **Storage Role Assignments** | `Microsoft.Authorization/roleAssignments` | Blob Data Owner + Queue Data Contributor + File Data Privileged Contributor + Account Contributor |

### `main-appinsights.bicep`

| Resource | Type | Description |
|---|---|---|
| **Log Analytics Workspace** | `Microsoft.OperationalInsights/workspaces` | PerGB2018 SKU, configurable retention (default 30 days) |
| **Application Insights** | `Microsoft.Insights/components` | Workspace-based, web type, 90-day retention, LogAnalytics ingestion mode |

## Bicep Modules

### `stacks/core/main.bicep`

The orchestration file that ties everything together. It accepts a `baseName` and `environment` parameter and derives all resource names using Azure naming conventions:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `location` | `string` | Resource group location | Azure region for all resources |
| `baseName` | `string` | *(required)* | Base name used to derive resource names |
| `tenantId` | `string` | Current subscription tenant | Azure AD tenant ID for Key Vault |
| `environment` | `string` | `dev` | Target environment (`dev`, `staging`, `prod`) |

**Naming convention:**

| Resource | Pattern | Example |
|---|---|---|
| Key Vault | `kv-{baseName}-{env}` | `kv-myapp-dev` |
| Function App | `func-{baseName}-{env}` | `func-myapp-dev` |
| App Service Plan | `asp-{baseName}-{env}` | `asp-myapp-dev` |
| Storage Account | `st{baseName}{env}` | `stmyappdev` |
| Log Analytics | `log-{baseName}-{env}` | `log-myapp-dev` |
| App Insights | `appi-{baseName}-{env}` | `appi-myapp-dev` |

### `modules/keyVault.bicep`

Deploys an Azure Key Vault with:

- **RBAC authorization** enabled (no access policies — all access is managed through Azure role assignments)
- **Soft-delete** enabled with 90-day retention
- Network ACLs allowing Azure services bypass
- Deployment, disk encryption, and template deployment features disabled by default

### `modules/functionApp.bicep`

Deploys a complete Azure Function App stack:

- **Storage Account** — required by the Functions runtime for internal state management
- **App Service Plan** — Consumption tier (serverless, pay-per-execution)
- **Function App** — Linux-based, Python 3.11, with a **system-assigned managed identity** automatically enabled

The Function App uses **Entra ID identity-based authentication** to the Storage Account instead of connection strings with storage keys. This is configured via the `__accountName` suffix convention:

| App Setting | Value | Purpose |
|---|---|---|
| `AzureWebJobsStorage__accountName` | Storage account name | Functions runtime storage (identity-based) |
| `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__accountName` | Storage account name | Content share access (identity-based) |
| `WEBSITE_CONTENTSHARE` | Function app name | File share name for deployment content |
| `KEY_VAULT_URI` | Key Vault URI | Allows code to use `DefaultAzureCredential` for secrets |

> **No storage keys or connection strings are stored.** The managed identity authenticates via Entra ID at runtime.

### `modules/roleAssignments.bicep`

A **generic, reusable** module that creates Azure RBAC role assignments for any target resource. It accepts a `principalId`, a `scopeResourceId` (used for GUID uniqueness), and an array of `roleDefinitions`. The same module is used for both Key Vault and Storage Account assignments in the core stack.

| Parameter | Type | Description |
|---|---|---|
| `principalId` | `string` | Managed identity principal ID |
| `scopeResourceId` | `string` | Target resource ID (used in assignment GUID for uniqueness) |
| `roleDefinitions` | `roleDefinitionInfo[]` | Array of role definition IDs and descriptions |

The module exports a `roleDefinitionInfo` user-defined type. To add roles, extend the role definition arrays in the stack's `main.bicep`.

**Key Vault roles (core stack):**

| Role | ID | Purpose |
|---|---|---|
| **Key Vault Secrets User** | `4633458b-17de-408a-b874-0445c86b69e6` | Read secret contents from Key Vault |
| **Key Vault Crypto User** | `12338af0-0e69-4776-bea7-57ae8d297424` | List and use cryptographic keys in Key Vault |
| **Key Vault Reader** | `21090545-7ca7-4776-b22c-e363652d74d2` | Read Key Vault metadata (list vaults, properties) |

**Storage Account roles (core stack):**

| Role | ID | Purpose |
|---|---|---|
| **Storage Blob Data Owner** | `b7e6dc6d-f1e8-4753-8033-0f276bb0955b` | Read/write blob data (AzureWebJobsStorage internal state) |
| **Storage Queue Data Contributor** | `974c5e8b-45b9-4653-ba55-5f855dd0fb88` | Process queue messages (triggers, bindings, internal scheduling) |
| **Storage File Data Privileged Contributor** | `69566ab7-960f-475b-8e7c-b3118f30c6bd` | Access file shares (WEBSITE_CONTENTSHARE for deployment artifacts) |
| **Storage Account Contributor** | `17d1049b-9a84-46fb-8f53-869881c3d3ab` | Manage storage account (content share provisioning on first deploy) |

### `modules/appInsights.bicep`

Deploys a workspace-based Application Insights instance backed by a Log Analytics workspace:

- **Log Analytics Workspace** — PerGB2018 pricing tier, configurable retention (30–730 days)
- **Application Insights** — workspace-based (LogAnalytics ingestion mode), web type, 90-day data retention

This module is consumed by `main-appinsights.bicep` and can also be referenced from `main.bicep` if you want to add monitoring to the Function App stack.

## Deployment Order

Bicep resolves dependencies automatically based on module output references:

### `stacks/core/`

```
1. Key Vault                    (no dependencies)
2. Function App                 (depends on Key Vault URI output)
3. Key Vault Role Assignments   (depends on Function App principal ID + Key Vault ID)
4. Storage Role Assignments     (depends on Function App principal ID + Storage Account ID)
```

Steps 3 and 4 run in parallel since they have no dependency on each other.

### `stacks/monitoring/`

```
1. Application Insights + Log Analytics   (single module, no external dependencies)
```

## GitHub Actions Pipelines

The project has **two workflows**:

| Workflow | File | Triggers on | Purpose |
|---|---|---|---|
| **Deploy Infrastructure** | `deploy-infra.yml` | Changes in `infra/` | Deploys Bicep templates (infrastructure) |
| **Deploy Function App Code** | `deploy-function.yml` | Changes in `src/` | Builds and deploys the Python function code |

### Infrastructure Workflow (`deploy-infra.yml`)

Runs a three-stage pipeline:

```
┌────────────┐     ┌──────────────┐     ┌────────────┐
│  Validate  │────▶│   What-If    │────▶│   Deploy   │
│            │     │  (preview)   │     │ (main only)│
└────────────┘     └──────────────┘     └────────────┘
```

### Stages

| Stage | Purpose | Runs on |
|---|---|---|
| **Validate** | Compiles the Bicep template and runs a preflight validation against Azure | Every push & PR |
| **What-If** | Shows a diff of what would change in your Azure environment | Every push & PR |
| **Deploy** | Creates/updates the resource group and deploys the template | Pushes to `main` only |

### Workflow Inputs

On manual dispatch, the workflow accepts four inputs:

| Input | Type | Default | Description |
|---|---|---|---|
| `environment` | choice | `dev` | Target environment (`dev`, `staging`, `prod`) |
| `template` | choice | `core` | Bicep stack to deploy (`core`, `monitoring`) |
| `location` | string | `swedencentral` | Azure region for the deployment |
| `resource_group` | string | `rg-bicep-labs` | Target resource group name |

On push/PR triggers all inputs fall back to their defaults (`core` stack, `swedencentral`, `rg-bicep-labs`, `dev`).

### Stack Selector

| Input value | Template file | Parameters file |
|---|---|---|
| `core` *(default)* | `infra/stacks/core/main.bicep` | `infra/stacks/core/main.bicepparam` |
| `monitoring` | `infra/stacks/monitoring/main.bicep` | `infra/stacks/monitoring/main.bicepparam` |

### Triggers

- **Push** to `main` branch (when files in `infra/` change)
- **Pull request** to `main` branch (when files in `infra/` change) — runs validate + what-if only
- **Manual dispatch** — select target environment, stack, location, and resource group from the Actions UI

### Authentication

The pipeline uses **OpenID Connect (OIDC) federated credentials** for passwordless authentication to Azure. This is the recommended approach — no client secrets are stored in GitHub.

### Function App Workflow (`deploy-function.yml`)

Builds and deploys the Python function code to Azure Functions:

```
┌────────────┐     ┌────────────┐
│   Build    │────▶│   Deploy   │
│            │     │ (main only)│
└────────────┘     └────────────┘
```

| Stage | Purpose | Runs on |
|---|---|---|
| **Build** | Installs Python dependencies and uploads the package as an artifact | Every push & PR |
| **Deploy** | Downloads the artifact and deploys to the Function App using `Azure/functions-action` | Pushes to `main` only |

**Triggers:**

- **Push** to `main` branch (when files in `src/` change)
- **Pull request** to `main` branch (when files in `src/` change) — runs build only
- **Manual dispatch** — select target environment from the Actions UI

**Configuration:** Update the `FUNCTION_APP_NAME` env var in the workflow to match your Function App name (must match the name deployed by the infrastructure workflow):

```yaml
env:
  FUNCTION_APP_NAME: func-myapp-dev    # Must match: func-{baseName}-{env}
```

## Function App Code

The `src/` folder contains a Python Azure Function (v2 programming model) that lists all cryptographic keys in the configured Key Vault.

### Endpoint

```
GET https://<function-app>.azurewebsites.net/api/list-keys?code=<function-key>
```

### How it works

1. Reads the `KEY_VAULT_URI` environment variable (set by the Bicep template)
2. Authenticates to Key Vault using `DefaultAzureCredential` (leverages the Function App's system-assigned managed identity)
3. Uses `azure-keyvault-keys` SDK to list all key properties
4. Returns a JSON response with key metadata (name, type, status, dates)

### Example response

```json
{
  "vault_uri": "https://kv-myapp-dev.vault.azure.net/",
  "key_count": 2,
  "keys": [
    {
      "name": "my-rsa-key",
      "id": "https://kv-myapp-dev.vault.azure.net/keys/my-rsa-key",
      "enabled": true,
      "key_type": "RSA",
      "created_on": "2026-02-13T10:00:00+00:00",
      "updated_on": "2026-02-13T10:00:00+00:00",
      "expires_on": null,
      "vault_url": "https://kv-myapp-dev.vault.azure.net"
    }
  ]
}
```

### Local development

```bash
cd src
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Update local.settings.json with your Key Vault URI
# Login to Azure for DefaultAzureCredential to work locally
az login

func start
```

## Prerequisites

### 1. Azure AD App Registration

Create an app registration with a service principal and role assignments. You can use the provided setup script or run the commands manually.

**Using the setup script (recommended):**

```bash
# Login to Azure first
az login

# Create app registration, service principal, and role assignments
./setup/create-app-registration.sh

# Or with a custom display name
./setup/create-app-registration.sh "my-custom-app-name"
```

The script will output the values needed for GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`).

<details>
<summary><b>Manual steps (click to expand)</b></summary>

```bash
# Create the app registration
az ad app create --display-name "github-bicep-labs"

# Get the app ID
APP_ID=$(az ad app list --display-name "github-bicep-labs" --query "[0].appId" -o tsv)

# Create a service principal
az ad sp create --id $APP_ID

# Get the object ID of the service principal
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query "id" -o tsv)

# Assign Contributor + User Access Administrator on the subscription (or resource group)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

az role assignment create \
  --assignee-object-id $SP_OBJECT_ID \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

> **Note:** The **User Access Administrator** role is required because the deployment creates role assignments on both the Key Vault and the Storage Account.

</details>

### 2. Federated Credentials

Add OIDC federated credentials so GitHub Actions can authenticate to Azure without secrets. You can use the provided setup script or run the commands manually.

**Using the setup script (recommended):**

```bash
# Pass your GitHub repo (owner/repo) — optionally pass the app client ID
./setup/create-federated-credentials.sh "myorg/bicep-labs"

# Or with an explicit app client ID
./setup/create-federated-credentials.sh "myorg/bicep-labs" "00000000-0000-0000-0000-000000000000"
```

The script creates federated credentials for:
- `main` branch pushes
- Pull requests
- `dev`, `staging`, and `prod` environments

<details>
<summary><b>Manual steps (click to expand)</b></summary>

```bash
# For the main branch
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<OWNER>/<REPO>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

# For pull requests
az ad app federated-credential create --id $APP_ID --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<OWNER>/<REPO>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

Replace `<OWNER>/<REPO>` with your GitHub repository (e.g., `myorg/bicep-labs`).

</details>

### 3. GitHub Repository Secrets

Add these secrets to your GitHub repository (**Settings → Secrets and variables → Actions**):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App registration Application (client) ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |

### 4. Configure Defaults

The workflow inputs have sensible defaults that are used for push/PR triggers. To change them, edit the `default` values in `.github/workflows/deploy-infra.yml`:

```yaml
      location:
        description: 'Azure region for deployment'
        default: 'swedencentral'        # Change default region here
      resource_group:
        description: 'Target resource group name'
        default: 'rg-bicep-labs'        # Change default RG here
```

Update the parameters in `infra/stacks/core/main.bicepparam`:

```bicep
using './main.bicep'

param baseName = 'myapp'       # Your application name
param environment = 'dev'       # Target environment
```

## Customization

### Setting Up the GitHub Action

Follow these steps to configure the workflow in your GitHub repository:

#### 1. Push the workflow file

The workflow file is already at `.github/workflows/deploy-infra.yml`. Push it to your repository:

```bash
git add .github/workflows/deploy-infra.yml
git commit -m "Add infrastructure deployment workflow"
git push origin main
```

GitHub automatically detects any YAML file under `.github/workflows/` and registers it as a workflow.

#### 2. Create GitHub Environments (optional but recommended)

Environments add manual approval gates and environment-specific secrets. The workflow references `${{ inputs.environment || 'dev' }}` in the deploy job.

1. Go to your repository on GitHub
2. Navigate to **Settings → Environments**
3. Click **New environment** and create one for each target:
   - `dev`
   - `staging`
   - `prod`
4. For `staging` and `prod`, configure **Required reviewers** to add an approval gate before deployment
5. Optionally set **Deployment branches** to restrict which branches can deploy to each environment (e.g., only `main` can deploy to `prod`)

#### 3. Add repository secrets

The workflow authenticates to Azure using OIDC federated credentials. Add these secrets:

1. Go to **Settings → Secrets and variables → Actions**
2. Click **New repository secret** and add each one:

| Secret name | Value | Where to find it |
|---|---|---|
| `AZURE_CLIENT_ID` | App registration Application (client) ID | Azure Portal → App registrations → your app → Overview |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Azure Portal → Microsoft Entra ID → Overview |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID | Azure Portal → Subscriptions |

> **Tip:** You can also set secrets per-environment if you deploy to different subscriptions. Go to **Settings → Environments → (env name) → Environment secrets**.

#### 4. Verify the workflow is registered

1. Go to the **Actions** tab in your repository
2. You should see **Deploy Infrastructure** in the left sidebar
3. If the workflow doesn't appear, check that the YAML is valid and committed under `.github/workflows/`

#### 5. Run a manual deployment

1. Go to **Actions → Deploy Infrastructure**
2. Click **Run workflow** (top right)
3. Select the **branch**, **environment**, **stack**, **location**, and **resource group** from the inputs
4. Click **Run workflow**

The pipeline will execute: **Validate → What-If → Deploy**

#### 6. Monitor the deployment

- Click on the running workflow to see real-time logs for each job
- The **What-If** stage shows a preview of what will change in Azure before deploying
- The **Deploy** stage (last step) prints the deployment outputs (resource names, endpoints, etc.)

#### Troubleshooting

| Issue | Solution |
|---|---|
| `AADSTS700016: Application not found` | Verify `AZURE_CLIENT_ID` secret matches the app registration |
| `AADSTS70021: No matching federated identity` | Check federated credential `subject` matches your repo and branch/PR pattern |
| `AuthorizationFailed` on deployment | Ensure the service principal has **Contributor** + **User Access Administrator** on the target scope |
| `ResourceGroupNotFound` on validate/what-if | The resource group must exist for validation. Create it manually or run the deploy job first (it creates it automatically) |
| Workflow doesn't trigger on push | Verify files changed are under `infra/**` — the workflow only triggers on that path |

### Adding more roles

Edit the role definition arrays in `infra/stacks/core/main.bicep`. The generic `roleAssignments.bicep` module loops over whatever roles you provide:

```bicep
var keyVaultRoleDefinitions = [
  {
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    description: 'Allow Function App to read secrets from Key Vault'
  }
  {
    roleDefinitionId: '21090545-7ca7-4776-b22c-e363652d74d2'
    description: 'Allow Function App to read Key Vault metadata'
  }
  // Add more roles here, e.g. Key Vault Certificates Officer:
  // {
  //   roleDefinitionId: 'a4417e6f-fecd-4de8-b567-7b0420556985'
  //   description: 'Allow Function App to manage certificates'
  // }
]
```

### Changing the Function App runtime

Edit `linuxFxVersion` and `FUNCTIONS_WORKER_RUNTIME` in `infra/modules/functionApp.bicep`:

| Runtime | `linuxFxVersion` | `FUNCTIONS_WORKER_RUNTIME` |
|---|---|---|
| Python 3.11 *(current)* | `Python\|3.11` | `python` |
| .NET 8 (isolated) | `DOTNET-ISOLATED\|8.0` | `dotnet-isolated` |
| Node.js 20 | `Node\|20` | `node` |
| Java 17 | `Java\|17` | `java` |

### Changing the App Service Plan SKU

Override the `appServicePlanSku` parameter in `functionApp.bicep` from the main template to use a dedicated plan instead of Consumption:

```bicep
appServicePlanSku: {
  name: 'EP1'
  tier: 'ElasticPremium'
}
```

## License

This project is provided as-is for learning and reference purposes.
