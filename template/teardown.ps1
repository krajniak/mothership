# PowerShell script to tear down the template resources using Terraform

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

# Attempt to select the workspace
Write-Output "Selecting workspace '$Env'..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" workspace select $Env

if ($LASTEXITCODE -ne 0) {
    Write-Output "Error: Workspace '$Env' does not exist. Exiting."
    exit 1
}

# Proceed with Terraform destroy
Write-Output "Destroying resources for workspace '$Env'..."
docker run --rm -v "${PWD}:/workspace" -w /workspace `
    -e ARM_CLIENT_ID=$armClientId `
    -e ARM_CLIENT_SECRET=$armClientSecret `
    -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
    -e ARM_TENANT_ID=$armTenantId `
    "$terraformImage" destroy -var-file="env/$Env.tfvars" -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Output "Error: Failed to destroy resources for workspace '$Env'. Exiting."
    exit 1
}

Write-Output "Teardown complete for workspace '$Env'."