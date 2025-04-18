# Setup-AzureSP.ps1
# This script logs you in to Azure using device code (which is MFA-friendly),
# checks for an existing service principal named "terraform-sp", deletes it if found,
# creates a new service principal, and then stores the credentials securely.

# Variables
$tenantId = "1caf5d6b-58cb-40e6-88b3-eb9ab9c0c010"
$subscriptionId = ""
$spName = "terraform-sp"
$secretVaultName = "az-sp-vault"
$secretName = "TerraformSP" # Added variable for secret name
$obfuscatePassword = $true # Set to $true to obfuscate the password in the output

# Save the current value of core.login_experience_v2
$currentLoginExperience = az config get core.login_experience_v2 --query "value" -o tsv

# Function to reset core.login_experience_v2 to its original value
function ResetLoginExperience {
    if ($currentLoginExperience) {
        Write-Output "Resetting core.login_experience_v2 to its original value: $currentLoginExperience."
        az config set core.login_experience_v2=$currentLoginExperience
    } else {
        Write-Output "No original value for core.login_experience_v2 found. Leaving it unchanged."
    }
}

# Failsafe: Set core.login_experience_v2=on and attempt az login
function Failsafe {
    Write-Output "Entering failsafe mode..."
    az config set core.login_experience_v2=on
    Write-Output "Attempting to log in to Azure..."
    az login --tenant $tenantId
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Error: Login failed. Exiting script."
        ResetLoginExperience
        exit 1
    }
}

# 1. If tenantId is not set or empty, prompt the user to enter it
if (-not $tenantId) {
    Write-Output "Tenant ID is not set or empty. Please enter the Tenant ID:"
    $tenantId = Read-Host -Prompt "Tenant ID"
}

# 2. If tenantId is set
Write-Output "Tenant ID is set. Setting core.login_experience_v2 to 'off'."
az config set core.login_experience_v2=off

Write-Output "Logging in to Azure with tenant ID..."
az login --tenant $tenantId --allow-no-subscriptions
if ($LASTEXITCODE -ne 0) {
    Write-Output "Error: Login failed with tenant ID. Entering failsafe mode."
    Failsafe
}

# Check subscriptions and set the account based on subscriptionId or isDefault
$subscriptions = az account list -o json | ConvertFrom-Json

if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
    Write-Output "Setting the subscription to '$subscriptionId'."
    az account set --subscription $subscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Error: Failed to set subscription. Entering failsafe mode."
        Failsafe
    }
} else {
    # Ensure $defaultSubscriptions is always treated as a list
    $defaultSubscriptions = @($subscriptions | Where-Object { $_.isDefault -eq $true })
    if ($defaultSubscriptions.Count -eq 1) {
        $subscriptionId = $defaultSubscriptions[0].id
        Write-Output "Default subscription found. Automatically selecting subscription '$subscriptionId'."
        az account set --subscription $subscriptionId
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error: Failed to set subscription. Entering failsafe mode."
            Failsafe
        }
    } else {
        Write-Output "No valid default subscription found or multiple default subscriptions. Entering failsafe mode."
        Failsafe
    }
}

# Call ResetLoginExperience at the end of the script
ResetLoginExperience

# 2. Get current subscription id (needed for SP creation)
$account = az account show | ConvertFrom-Json
$subscriptionId = $account.id

# 3. Check for an existing service principal with the name "terraform-sp"
Write-Output "Checking for an existing service principal named '$spName'..."
$existingSP = az ad sp list --display-name $spName | ConvertFrom-Json
if ($existingSP -and $existingSP.Count -gt 0) {
    foreach ($sp in $existingSP) {
        Write-Output "Deleting existing service principal with appId: $($sp.appId)"
        az ad sp delete --id $sp.appId
    }
} else {
    Write-Output "No existing service principal named '$spName' found."
}

# 4. Create a new service principal with Contributor role over your subscription
Write-Output "Creating a new service principal '$spName'..."
$spOutput = az ad sp create-for-rbac `
    --name $spName `
    --role Owner `
    --scopes "/subscriptions/$subscriptionId" | ConvertFrom-Json

# Add subscriptionId as a field into spOutput
$spOutput | Add-Member -MemberType NoteProperty -Name subscription -Value $subscriptionId

# Modify the output logic based on obfuscatePassword
if ($obfuscatePassword) {
    $spOutputCopy = $spOutput | ConvertTo-Json -Depth 10 | ConvertFrom-Json  # Create a copy of spOutput
    $spOutputCopy.password = "********"  # Obfuscate the password field
    Write-Output "New service principal created (password obfuscated):"
    $spOutputCopy | Format-List
} else {
    Write-Output "New service principal created:"
    $spOutput | Format-List
}

# 5. Securely store the service principal credentials for later use by Terraform.
#    Best practice: use the PowerShell SecretManagement module (requires Microsoft.PowerShell.SecretStore as the vault backend).
if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
    # Register a default vault if not already done
    try {
        $defaultVault = Get-SecretVault -Name $secretVaultName -ErrorAction Stop
    } catch {
        Write-Output "Registering a new secret vault '$secretVaultName'..."
        Register-SecretVault -Name $secretVaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
    }
    # Convert $spOutput to JSON so it becomes a string
    $jsonSecret = $spOutput | ConvertTo-Json -Depth 10

    # Store the JSON string as the secret
    Set-Secret -Name $secretName -Secret $jsonSecret -Vault $secretVaultName
    Write-Output "Service principal credentials stored securely in the '$secretVaultName' vault as '$secretName'."
    Write-Output "To retrieve them later in PowerShell, run: Get-Secret -Name $secretName"
} else {
    # Fallback: store the credentials in a file with NTFS permissions restricting access.
    # (This is less flexible than using the SecretManagement module.)
    $secureFolder = "$env:USERPROFILE\.securecreds"
    if (!(Test-Path -Path $secureFolder)) {
        New-Item -ItemType Directory -Path $secureFolder | Out-Null
    }
    $filePath = Join-Path $secureFolder "$secretName.json"
    $spOutput | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8
    Write-Output "Service principal credentials saved to $filePath."
    Write-Output "Please ensure that this file is secured by NTFS permissions so that only your user account can read it."
}

Write-Output "Setup complete."
