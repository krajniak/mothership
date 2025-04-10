# PowerShell script to deploy Azure Terraform state using Docker and SecretVault

# Variables
$secretVaultName = "az-sp-vault"
$secretName = "TerraformSP"
$outputSecretName = "TerraformBackend"
$terraformImage = "hashicorp/terraform:latest"
$infraDir = "infra"

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
} else {
    Write-Output "Error: SecretsManagement module is not installed. Exiting."
    exit 1
}

# Pass local variables directly to the Docker container
Write-Output "Initializing Terraform..."
docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
  -e ARM_CLIENT_ID=$armClientId `
  -e ARM_CLIENT_SECRET=$armClientSecret `
  -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
  -e ARM_TENANT_ID=$armTenantId `
  "$terraformImage" init

# Apply the Terraform configuration
Write-Output "Applying Terraform configuration..."
docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
  -e ARM_CLIENT_ID=$armClientId `
  -e ARM_CLIENT_SECRET=$armClientSecret `
  -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
  -e ARM_TENANT_ID=$armTenantId `
  "$terraformImage" apply -auto-approve

# Retrieve the Terraform outputs
Write-Output "Retrieving Terraform outputs..."
$terraformOutput = docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
  "$terraformImage" output -json | ConvertFrom-Json

if ($terraformOutput) {
    $storageAccountName = $terraformOutput.storage_account_name.value
    $containerName = $terraformOutput.container_name.value

    Write-Output "Storing storage account name and container name in SecretVault in a flat structure..."
    Set-Secret -Vault $secretVaultName -Name "$outputSecretName" -Secret (@{
        storage_account_name = $storageAccountName
        container_name = $containerName
    } | ConvertTo-Json -Depth 1)

    Write-Output "Storage account name and container name successfully stored in $secretVaultName SecretVault under $outputSecretName."
} else {
    Write-Output "Error: Failed to retrieve Terraform outputs. Exiting."
    exit 1
}

Write-Output "Terraform deployment complete."