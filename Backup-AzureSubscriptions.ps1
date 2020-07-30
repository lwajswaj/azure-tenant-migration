Param(
  [string] $SubscriptionName = "*"
)
#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

$context = $null
try {$context = Get-AzContext} catch {}
if($null -eq $context.Subscription.Id) { throw 'You must call the Login-AzAccount cmdlet before calling any other cmdlets.' }

Write-Host "Getting Subscriptions"
$output = ForEach($Subscription In (Get-AzSubscription | Where-Object -Property Name -like -Value $SubscriptionName)) {
  Set-AzContext -SubscriptionObject $Subscription | Out-Null

  New-Object psobject -Property @{"SubscriptionId"=$Subscription.Id;"SubscriptionName"=$Subscription.Name;"RBAC"=(Get-AzRoleAssignment | Select-Object -Unique ObjectId, DisplayName, ObjectType, RoleDefinitionName)}
}

Write-Host "Exporting CliXML"
$output | Export-Clixml "$here\Subscriptions.xml"
