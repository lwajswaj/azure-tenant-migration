Param(
  [string] $SubscriptionName = "*"
)
#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

$context = null
try {$context = Get-AzureRmContext} catch {}
if($null -eq $context.Subscription.Id) { throw 'You must call the Login-AzureRmAccount cmdlet before calling any other cmdlets.' }

Write-Host "Getting Subscriptions"
$output = ForEach($Subscription In (Get-AzureRmSubscription | Where-Object -Property Name -like -Value $SubscriptionName)) {
  Set-AzureRmContext -SubscriptionObject $Subscription | Out-Null

  New-Object psobject -Property @{"SubscriptionId"=$Subscription.Id;"SubscriptionName"=$Subscription.Name;"RBAC"=(Get-AzureRmRoleAssignment | Select-Object -Unique ObjectId, DisplayName, ObjectType, RoleDefinitionName)}
}

Write-Host "Exporting CliXML"
$output | Export-Clixml "$here\Subscriptions.xml"