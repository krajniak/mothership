# Mothership Project

## Overview
This project contains infrastructure as code (IaC) for deploying resources to Azure using Terraform. It includes scripts for setting up a secret store, recreating a Terraform service principal, and deploying the Terraform state to Azure.

## Project Structure
- **01-win-install-secret-store.ps1**: Script to install a secret store on Windows.
- **02-recreate-terraform-sp-service-prinicipal.ps1**: Script to initialize or recreate the Terraform service principal.
- **03-deploy-azure-terraform-state.ps1**: Script to deploy the Terraform state to Azure.
- **infra/**: Contains Terraform configuration files.

## Prerequisites
- Terraform v1.11.3 or later
- Azure CLI

## Usage
1. **Initialize the Secret Store**:
   Run the `01-win-install-secret-store.ps1` script to set up a secure secret store for storing service principal (SP) credentials.

2. **Initialize or Recreate the Service Principal**:
   Use the `02-recreate-terraform-sp-service-prinicipal.ps1` script to initialize or recreate the Terraform service principal. Ensure you have the Tenant ID available. The default values are as follows:
   Service Principial Name = "terraform-sp"
   Vault Name = "az-sp-vault"
   Secret in Vault Name = "TerraformSP"

   To retrieve SP credentials, use the following PowerShell command:
   ```powershell
   Get-AzKeyVaultSecret -VaultName "az-sp-vault" -Name "TerraformSP"
   ```
   
3. **Deploy the Terraform State**:
   Run the `03-deploy-azure-terraform-state.ps1` script to deploy the Terraform state to Azure. This script sets up the necessary storage account and container in Azure to store the Terraform state file securely.

## Notes
- Ensure that sensitive information such as keys and passwords are not committed to the repository.
- Use the `.gitignore` file to exclude sensitive files and Terraform state files.