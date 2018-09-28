# Backup-AzureServicePrincipal
This script makes use of "Get-AzureADServicePrincipal" and "Get-AzureADServicePrincipalOwner" to export all Service Principal Names (SPNs) in the current tenant. It includes the ownership, reply URL and Home Page information too. The export is stored in XML format using Export-Clixml so it can be easily re-imported later.

## Syntax
```powershell
.\Backup-AzureServicePrincipal.ps1 [<CommonParameters>]
```

## Parameters
There are no parameters available

## Output
It creates "AAD_ServicePrincipal.xml" in the same location as the script is being executed from.