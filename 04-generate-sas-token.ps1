# PowerShell script to sign in, generate SAS token, and store secrets

$secretVaultName = "az-sp-vault"
$spSecretName = "TerraformSP"
$backendSecretName = "TerraformBackend"  

# Step 1: Sign in to Azure using Service Principal credentials from Secret Vault

Write-Output "Retrieving Azure service principal credentials from SecretVault..."
$spCredentials = Get-Secret -Vault $secretVaultName -Name $spSecretName -AsPlainText
if (-not $spCredentials) {
    Write-Output "Error: Failed to retrieve service principal credentials. Exiting."
    exit 1
}

# Parse the plain text JSON output and extract ARM variables
$spCredentialsJson = $spCredentials | ConvertFrom-Json
$armClientId = $spCredentialsJson.appId
$armClientSecret = $spCredentialsJson.password
$armTenantId = $spCredentialsJson.tenant

az login --service-principal -u $armClientId -p $armClientSecret --tenant $armTenantId

Write-Output "Retrieving storage information from SecretVault..."
$storeInfo = Get-Secret -Vault $secretVaultName -Name $backendSecretName -AsPlainText
if (-not $storeInfo) {
    Write-Output "Error: Failed to retrieve storage information. Secret '$backendSecretName' not found. Exiting."
    exit 1
}

# Step 2: Generate SAS token for a specified storage account and container
$storeInfoJson = $storeInfo | ConvertFrom-Json
$storageAccountName = $storeInfoJson.storage_account_name
$containerName = $storeInfoJson.container_name

try {
    $sasToken = az storage container generate-sas `
        --account-name $storageAccountName `
        --name $containerName `
        --permissions rwdl `
        --expiry 9999-12-31T23:59:59Z `
        --auth-mode key -o tsv

    if (-not $sasToken) {
        throw "Failed to generate SAS token. Please check the storage account and container details."
    }

    # Step 3: Update the existing TerraformStorage secret to include the SAS token
    $updatedBackendInfo = $storeInfoJson
    $updatedBackendInfo | Add-Member -MemberType NoteProperty -Name "sas_token" -Value $sasToken -Force
    
    Set-Secret -Vault $secretVaultName -Name $backendSecretName -Secret ($updatedBackendInfo | ConvertTo-Json -Depth 1)
    Write-Host "SAS token has been added to the $backendSecretName secret in the $secretVaultName Secret Vault."
} catch {
    Write-Error "An error occurred: $_"
}