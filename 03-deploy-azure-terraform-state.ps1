# PowerShell script to deploy Azure Terraform state using Docker
param(
    [string]$dotEnvFile = "",
    [string]$secretVaultName = "az-sp-vault"
)

$terraformImage = "hashicorp/terraform:latest"
$infraDir = "infra"

if (-not $dotEnvFile) {
    ./load-env-variables.ps1 -secretVaultName $secretVaultName
    if (-not $env:ARM_CLIENT_ID -or -not $env:ARM_CLIENT_SECRET -or -not $env:ARM_TENANT_ID -or -not $env:ARM_SUBSCRIPTION_ID) {
        Write-Error "Required environment variables are not set. Exiting."
        exit 1
    }
}

# Initialize Terraform
Write-Output "Initializing Terraform..."
if ($dotEnvFile) {
    if (-not (Test-Path $dotEnvFile)) {
        Write-Error "Env file not found: $dotEnvFile"
        exit 1
    }
    docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
      --env-file $dotEnvFile `
      "$terraformImage" init
} else {
    docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
      -e ARM_SUBSCRIPTION_ID=$env:ARM_SUBSCRIPTION_ID `
      -e ARM_CLIENT_ID=$env:ARM_CLIENT_ID `
      -e ARM_CLIENT_SECRET=$env:ARM_CLIENT_SECRET `
      -e ARM_TENANT_ID=$env:ARM_TENANT_ID `
      "$terraformImage" init
}

# Apply Terraform
Write-Output "Applying Terraform configuration..."
if ($dotEnvFile) {
    docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
      --env-file $dotEnvFile `
      "$terraformImage" apply -auto-approve
} else {
    docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
      -e ARM_CLIENT_ID=$env:ARM_CLIENT_ID `
      -e ARM_CLIENT_SECRET=$env:ARM_CLIENT_SECRET `
      -e ARM_SUBSCRIPTION_ID=$env:ARM_SUBSCRIPTION_ID `
      -e ARM_TENANT_ID=$env:ARM_TENANT_ID `
      "$terraformImage" apply -auto-approve
}

# Retrieve the Terraform outputs
Write-Output "Retrieving Terraform outputs..."
$terraformOutput = docker run --rm -v "${PWD}/$($infraDir):/workspace" -w /workspace `
  "$terraformImage" output -json | ConvertFrom-Json

if ($terraformOutput) {
    $env:ARM_STORAGE_ACCOUNT_NAME = $terraformOutput.storage_account_name.value
    $env:ARM_CONTAINER_NAME = $terraformOutput.container_name.value

    Write-Output "Backend info obtained."
    # Save backend settings into dotEnvFile or SecretVault
    if ($dotEnvFile) {
        Write-Output "Appending backend variables to .env file: $dotEnvFile"
        if (-not (Test-Path $dotEnvFile)) { Remove-Item $dotEnvFile -ErrorAction Ignore }
        "ARM_STORAGE_ACCOUNT_NAME=$env:ARM_STORAGE_ACCOUNT_NAME" | Add-Content -Path $dotEnvFile -Encoding utf8
        "ARM_CONTAINER_NAME=$env:ARM_CONTAINER_NAME" | Add-Content -Path $dotEnvFile -Encoding utf8
        Write-Output "Appended ARM_STORAGE_ACCOUNT_NAME and ARM_CONTAINER_NAME to $dotEnvFile"
    } else {
        Write-Output "Storing backend variables in SecretVault: $secretVaultName"
        Set-Secret -Vault $secretVaultName -Name ARM_STORAGE_ACCOUNT_NAME -Secret $env:ARM_STORAGE_ACCOUNT_NAME
        Set-Secret -Vault $secretVaultName -Name ARM_CONTAINER_NAME -Secret $env:ARM_CONTAINER_NAME
        Write-Output "Stored ARM_STORAGE_ACCOUNT_NAME and ARM_CONTAINER_NAME in vault '$secretVaultName'"
    }
} else {
    Write-Output "Error: Failed to retrieve Terraform outputs. Exiting."
    exit 1
}

Write-Output "Terraform deployment complete."