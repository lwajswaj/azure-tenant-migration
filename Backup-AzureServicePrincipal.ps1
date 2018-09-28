#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

try { Get-AzureADTenantDetail -ErrorAction SilentlyContinue | Out-Null } catch { throw 'You must call the Connect-AzureAD cmdlet before calling any other cmdlets.' }

Write-Host "Getting Service Principal Names"
$output = foreach($SPN In (Get-AzureADServicePrincipal -All $true)){
$owners = Get-AzureADServicePrincipalOwner -ObjectId $SPN.ObjectId
if ($owners){
New-Object PSObject -Property @{"ObjectId"=$SPN.ObjectId;"AppId"=$SPN.AppId;"DisplayName"=$SPN.DisplayName;"HomePage"=$owners.HomePage;"ReplyURLs"=$owners.ReplyURLs;"Owners"=$owners.DisplayName;"UserPrincipalName"=$owners.UserPrincipalName}
}
else {
New-Object PSObject -Property @{"ObjectId"=$SPN.ObjectId;"AppId"=$SPN.AppId;"DisplayName"=$SPN.DisplayName;"HomePage"=$SPN.HomePage;"ReplyURLs"=$SPN.ReplyURLs;"Owners"="None"}
}
}

Write-Host "Exporting CliXML"
$output | Export-Clixml "$here\AAD_ServicePrincipal.xml"