#Requires -Modules AzureAD

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

try { Get-AzureADTenantDetail -ErrorAction SilentlyContinue | Out-Null } catch { throw 'You must call the Connect-AzureAD cmdlet before calling any other cmdlets.' }

Write-Host "Getting Groups"
$output = ForEach($Group In (Get-AzureADGroup -All $true)){
  $Members = @()
  
  ForEach($Member In (Get-AzureADGroupMember -ObjectId $Group.ObjectId)) {
    if($Member.ObjectType -eq "Group"){
      $Members += $Member | Select-Object -Property ObjectId, DisplayName, ObjectType
    }
    elseif($Member.ObjectType -eq "User"){
      $Members += $Member | Select-Object -Property ObjectId, DisplayName, ObjectType, userPrincipalName
    }
  }

  New-Object PSObject -Property @{"ObjectId"=$Group.ObjectId;"DisplayName"=$Group.DisplayName;"Members"=$Members}
}

Write-Host "Exporting CliXML"
$output | Export-Clixml "$here\AAD_Groups.xml"