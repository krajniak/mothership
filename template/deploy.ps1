# PowerShell script to deploy the template resources using Terraform

param (
    [Parameter(Mandatory = $false)]
    [string]$Env = "local"
)

# Variables
$secretVaultName = "az-sp-vault"
$secretName = "TerraformSP"
$backendSecretName = "TerraformBackend"
$terraformImage = "hashicorp/terraform:latest"
$varFile = "env/$Env.tfvars"

# Check if the SecretsManagement module is installed
if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
    # Retrieve Azure service principal credentials from SecretVault
    Write-Output "Retrieving Azure service principal credentials from SecretVault..."
    $spCredentials = Get-Secret -Vault $secretVaultName -Name $secretName -AsPlainText
    if (-not $spCredentials) {
        Write-Output "Error: Failed to retrieve service principal credentials. Exiting."
        exit 1
    }

    # Parse the plain text JSON output and extract ARM variables
    $spCredentialsJson = $spCredentials | ConvertFrom-Json
    $armClientId = $spCredentialsJson.appId
    $armClientSecret = $spCredentialsJson.password
    $armSubscriptionId = $spCredentialsJson.subscription
    $armTenantId = $spCredentialsJson.tenant

    # Retrieve storage backend information from SecretVault
    Write-Output "Retrieving storage backend information from SecretVault..."
    $backendInfo = Get-Secret -Vault $secretVaultName -Name $backendSecretName -AsPlainText
    if (-not $backendInfo) {
        Write-Output "Error: Failed to retrieve backend information. Exiting."
        exit 1
    }

    # Parse the backend information
    $backendInfoJson = $backendInfo | ConvertFrom-Json
    $storageAccountName = $backendInfoJson.storage_account_name
    $containerName = $backendInfoJson.container_name
    $sasToken = $backendInfoJson.sas_token
} else {
    Write-Output "Error: SecretsManagement module is not installed. Exiting."
    exit 1
}

# Extract backend key from tfvars file
$tfvarsContent = Get-Content $varFile
$backendKeyMatch = $tfvarsContent | Select-String -Pattern 'backend_key\s*=\s*"([^"]+)"'
if ($backendKeyMatch) {
    $backendKey = $backendKeyMatch.Matches[0].Groups[1].Value
    Write-Output "Using backend key: $backendKey"
} else {
    Write-Output "Error: backend_key is required in $varFile but was not found. Exiting."
    exit 1
}

# Reinitialize Terraform backend with the -reconfigure flag
Write-Output "Reinitializing Terraform backend..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" init `
    -backend-config="storage_account_name=$storageAccountName" `
    -backend-config="container_name=$containerName" `
    -backend-config="key=$backendKey" `
    -backend-config="sas_token=$sasToken"

if ($LASTEXITCODE -ne 0) {
    Write-Output "Error: Failed to initialize Terraform backend. Exiting."
    exit 1
}

# List workspaces
Write-Output "Listing available Terraform workspaces..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" workspace list

# Check if workspace exists or create it
Write-Output "Checking for workspace '$Env'..."
$workspaceExists = docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" workspace list | Select-String -Pattern "^\s*\*?\s*$Env\s*$"

if (-not $workspaceExists) {
    Write-Output "Creating new workspace '$Env'..."
    docker run --rm -v "${PWD}:/workspace" -w /workspace `
        -e ARM_CLIENT_ID=$armClientId `
        -e ARM_CLIENT_SECRET=$armClientSecret `
        -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
        -e ARM_TENANT_ID=$armTenantId `
        "$terraformImage" workspace new $Env
}

# Select the workspace
Write-Output "Selecting workspace '$Env'..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" workspace select $Env

# Plan the deployment
Write-Output "Planning deployment for workspace '$Env'..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" plan -var-file="$varFile" -out=tfplan

# Apply the deployment
Write-Output "Applying deployment for workspace '$Env'..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" apply tfplan

Write-Output "Deployment complete for workspace '$Env'."