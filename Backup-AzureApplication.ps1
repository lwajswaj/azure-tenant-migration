#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

try { Get-AzureADTenantDetail -ErrorAction SilentlyContinue | Out-Null } catch { throw 'You must call the Connect-AzureAD cmdlet before calling any other cmdlets.' }

Write-Host "Getting Applications"
$output = foreach($Application In (Get-AzureADApplication -All $true)){
$owners = Get-AzureADApplicationOwner -ObjectId $Application.ObjectId
if ($owners){
   New-Object PSObject -Property @{"ObjectId"=$Application.ObjectId;"AppId"=$Application.AppId;"DisplayName"=$Application.DisplayName;"Owners"=$owners.DisplayName}
}
else {
   New-Object PSObject -Property @{"ObjectId"=$Application.ObjectId;"AppId"=$Application.AppId;"DisplayName"=$Application.DisplayName;"Owners"="None"}
}
}

Write-Host "Exporting CliXML"
$output | Export-Clixml "$here\AAD_Applications.xml"