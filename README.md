# Mothership Project

## Overview
This project contains infrastructure as code (IaC) for deploying resources to Azure using Terraform. It includes scripts for setting up a secret store, recreating a Terraform service principal, and deploying the Terraform state to Azure.

## Prerequisites
- Azure CLI

## Usage

### Using secret store
```powershell
# 1. Install and register the PowerShell SecretManagement and SecretStore modules (Windows only)
.\01-win-install-secret-store.ps1

# 2. Create or recreate the Terraform service principal and store credentials in vault
.\02-recreate-terraform-sp-service-prinicipal.ps1 [-secretVaultName az-sp-vault]

# 3. Deploy Terraform state to Azure
.\03-deploy-azure-terraform-state.ps1 [-secretVaultName az-sp-vault]

# 4. Generate SAS token and store it in the secret vault
.\04-generate-sas-token.ps1 [-secretVaultName az-sp-vault]
```

### Using .env file
```powershell
# 1. Create or recreate the Terraform service principal and store credentials in .env file
.\02-recreate-terraform-sp-service-prinicipal.ps1 -dotEnvFile .env

# 2. Deploy Terraform state to Azure
.\03-deploy-azure-terraform-state.ps1 -dotEnvFile .env

# 3. Generate SAS token and append it to the .env file
.\04-generate-sas-token.ps1 -dotEnvFile .env
```

## Scripts

### 01-win-install-secret-store.ps1
Installs and registers the PowerShell SecretManagement and SecretStore modules (Windows only).

Usage:
```powershell
.\01-win-install-secret-store.ps1
```

### 02-recreate-terraform-sp-service-prinicipal.ps1
Creates or recreates a Terraform service principal and stores its credentials.

Parameters:
- `-tenantId` (string): Azure Tenant ID.
- `-subscriptionId` (string): Subscription ID (optional).
- `-spName` (string): Service principal name (default `terraform-sp`).
- `-secretVaultName` (string): Secret Vault name (default `az-sp-vault`).
- `-showPasswordOnConsoleOutput` (bool): Toggle full password display (defualt: False).
- `-dotEnvFile` (string): Path to write a `.env` file instead of vault.

Examples:
```powershell
# Store credentials in Secret Vault:
.\02-recreate-terraform-sp-service-prinicipal.ps1 [-secretVaultName az-sp-vault]

# Write credentials to .env and export into session:
.\02-recreate-terraform-sp-service-prinicipal.ps1 -dotEnvFile .env
```

### load-env-variables.ps1
Loads all ARM_* variables from a Secret Vault or a `.env` file into the current PowerShell environment.

Parameters:
- `-secretVaultName` (string): Vault name to read secrets from (default `az-sp-vault`).
- `-dotEnvFile` (string): Path to `.env` file to load.

Usage:
```powershell
.\load-env-variables.ps1 [-secretVaultName az-sp-vault]
``` 
or:
```powershell
.\load-env-variables.ps1 -dotEnvFile .\terraform.env
```

### 03-deploy-azure-terraform-state.ps1
Runs Terraform `init` and `apply` in Docker, passing ARM variables via vault or `.env`.

Parameters:
- `-dotEnvFile` (string): Path to `.env` file (optional).
- `-secretVaultName` (string): Vault name for credential retrieval (default `az-sp-vault`).

Usage:
```powershell
# Using Secret Vault:
.\03-deploy-azure-terraform-state.ps1

# Using .env file:
.\03-deploy-azure-terraform-state.ps1 -dotEnvFile .env
```

### 04-generate-sas-token.ps1
Generates a SAS token for the Terraform backend container and stores it.

Parameters:
- `-secretVaultName` (string): Vault holding SP and backend info (default `az-sp-vault`).
- `-dotEnvFile` (string): Path to `.env` file to write.

Usage:
```powershell
# Store SAS token in Secret Vault:
.\04-generate-sas-token.ps1 [-secretVaultName az-sp-vault]

# Append SAS token to .env file:
.\04-generate-sas-token.ps1 -dotEnvFile .\terraform.env
```

## Notes
- Ensure that sensitive information such as keys and passwords are not committed to the repository.
- Use the `.gitignore` file to exclude sensitive files and Terraform state files.
- Both "WAYS" will add all the ARM_* env variables