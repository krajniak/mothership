# PowerShell script to deploy Azure Terraform state using Docker and SecretVault

# Variables
$secretVaultName = "az-sp-vault"
$secretName = "TerraformSP"
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

Write-Output "Applying Terraform configuration..."
docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
  -e ARM_CLIENT_ID=$armClientId `
  -e ARM_CLIENT_SECRET=$armClientSecret `
  -e ARM_SUBSCRIPTION_ID=$armSubscriptionId `
  -e ARM_TENANT_ID=$armTenantId `
  "$terraformImage" apply -auto-approve

Write-Output "Terraform deployment complete."