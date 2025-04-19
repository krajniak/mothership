# PowerShell script to sign in, generate SAS token, and store secrets

param(
    [string]$secretVaultName     = "az-sp-vault",
    [string]$dotEnvFile          = ""
)

# Step 1: Sign in using either .env or SecretVault
Write-Output "Signing in to Azure using environment variables..."
az login --service-principal -u $env:ARM_CLIENT_ID -p $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed. Exiting."
    exit 1
}

# Generate SAS token
try {
    $sasToken = az storage container generate-sas `
        --account-name $env:ARM_STORAGE_ACCOUNT_NAME `
        --name $env:ARM_CONTAINER_NAME `
        --permissions rwdl `
        --expiry 9999-12-31T23:59:59Z `
        --auth-mode key -o tsv
    if (-not $sasToken) { throw "SAS generation failed." }

    # Export to environment
    $env:ARM_SAS_TOKEN = $sasToken

    # Persist SAS token
    if ($dotEnvFile) {
        Write-Output "Appending ARM_SAS_TOKEN to .env file: $dotEnvFile"
        "ARM_SAS_TOKEN=$sasToken" | Add-Content -Path $dotEnvFile -Encoding utf8
        Write-Output "Appended ARM_SAS_TOKEN to $dotEnvFile"
    } else {
        Write-Output "Storing ARM_SAS_TOKEN in SecretVault: $secretVaultName"
        Set-Secret -Vault $secretVaultName -Name 'ARM_SAS_TOKEN' -Secret $sasToken
        Write-Output "Stored ARM_SAS_TOKEN in vault '$secretVaultName'"
    }
    Write-Output "SAS token handling complete."
} catch {
    Write-Error "Error generating or storing SAS token: $_"
    exit 1
}