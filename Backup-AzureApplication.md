# Backup-AzureApplication
This script makes use of "Get-AzureADApplication" to export all Application Registrations in the current tenant. It includes the ownership information as well. The export is stored in XML format using Export-Clixml so it can be easily re-imported later.

## Syntax
```powershell
.\Backup-AzureApplication.ps1 [<CommonParameters>]
```

## Parameters
There are no parameters available

## Output
It creates "AAD_Applications.xml" in the same location as the script is being executed from.