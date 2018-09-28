# Backup-AzureGroups
This script makes use of "Get-AzureADGroup" and "Get-AzureADGroupMember" to export all Azure AD Groups in the current tenant. It includes group membership as well. The export is stored in XML format using Export-Clixml so it can be easily re-imported later.

## Syntax
```powershell
.\Backup-AzureGroups [<CommonParameters>]
```

## Parameters
There are no parameters available

## Output
It creates "AAD_Groups.xml" in the same location as the script is being executed from.