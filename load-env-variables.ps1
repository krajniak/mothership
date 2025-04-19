param(
    [string]$secretVaultName = "az-sp-vault",
    [string]$dotEnvFile = ""
)

# Load environment variables from .env file if provided
if ($dotEnvFile) {
    Write-Output "Loading environment variables from .env file: $dotEnvFile"
    if (-not (Test-Path $dotEnvFile)) {
        Write-Error "The specified .env file does not exist: $dotEnvFile"
        exit 1
    }
    Get-Content $dotEnvFile | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
            Write-Output "Set environment variable: $($matches[1])"
        }
    }
} else {
    # Load all environment variables from SecretVault
    Write-Output "Loading all environment variables from SecretVault: $secretVaultName"
    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
        Write-Error "Microsoft.PowerShell.SecretManagement module is not installed. Please install it and try again."
        exit 1
    }

    $secrets = Get-SecretInfo -Vault $secretVaultName
    foreach ($secret in $secrets) {
        $secretValue = Get-Secret -Vault $secretVaultName -Name $secret.Name -AsPlainText
        if ($secretValue) {
            [Environment]::SetEnvironmentVariable($secret.Name, $secretValue)
            Write-Output "Set environment variable: $($secret.Name)"
        } else {
            Write-Error "Failed to retrieve secret: $($secret.Name) from vault: $secretVaultName"
            exit 1
        }
    }
}

Write-Output "Environment variables successfully loaded."