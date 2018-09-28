#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

try { Get-AzureADTenantDetail -ErrorAction SilentlyContinue | Out-Null } catch { throw 'You must call the Connect-AzureAD cmdlet before calling any other cmdlets.' }

Write-Host "Getting & Exporting Users"
Get-AzureADUser -All $true | Select-Object -Property ObjectId, DisplayName, UserPrincipalName, UserType  | Export-Clixml "$here\AAD_Users.xml"