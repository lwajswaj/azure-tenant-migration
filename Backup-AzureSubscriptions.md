# Backup-AzureSubscriptions
This script makes use of "Get-AzureRmRoleAssignment" to export RBAC of all subscriptions matching its paramter in the current tenant. The export is stored in XML format using Export-Clixml so it can be easily re-imported later.

## Syntax
```powershell
.\Backup-AzureSubscriptions.ps1 [-SubscriptionName <string>] [<CommonParameters>]
```

## Parameters
| Name | Type | Mandatory | Description |
| --- | --- | --- | --- |
| SubscriptionName | String | No | Subscription Name or wildcard to export certain subscriptions only |

## Output
It creates "Subscriptions.xml" in the same location as the script is being executed from.

## Examples

### Example 1
Export all subscription containing the word "PROD" in their name

```powershell
.\Backup-AzureSubscriptions.ps1 -SubscriptionName "*PROD*"
```

### Example 2
Export all subscriptions

```powershell
.\Backup-AzureSubscriptions.ps1
```