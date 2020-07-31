[CmdletBinding(SupportsShouldProcess)]
Param(
  [Parameter(Mandatory)]
  [ValidateScript({Test-Path $_})]
  [String]$GroupExport,
  [Parameter(Mandatory)]
  [ValidateScript({Test-Path $_})]
  [String]$UserExport,
  [Parameter(Mandatory)]
  [ValidateScript({Test-Path $_})]
  [String]$ServicePrincipalExport,
  [Parameter(Mandatory)]
  [ValidateScript({Test-Path $_})]
  [String]$SubscriptionExport,
  [String]$Prefix = "",
  [switch]$Verify,
  [switch]$SkipKeyVault,
  [switch]$SkipSubscription
)

$context = $null
try {$context = Get-AzContext} catch {}
if($null -eq $context.Subscription.Id) { throw 'You must call the Login-AzAccount cmdlet before calling any other cmdlets.' }

try { Get-AzureADTenantDetail -ErrorAction SilentlyContinue | Out-Null } catch { throw 'You must call the Connect-AzureAD cmdlet before calling any other cmdlets.' }

#region "Global Objects"
$OldTenant = New-Object PSObject -Property @{
  "Groups" = (Import-Clixml -Path $GroupExport);
  "Users" = (Import-Clixml -Path $UserExport);
  "ServicePrincipals" = (Import-Clixml -Path $ServicePrincipalExport);
  "Subscriptions" = (Import-Clixml -Path $SubscriptionExport)
}

if($Verify){
	Write-Host ("Loaded {0} Groups" -f $OldTenant.Groups.Count)
	Write-Host ("Loaded {0} Users" -f $OldTenant.Users.Count)
	Write-Host ("Loaded {0} ServicePrincipals" -f $OldTenant.ServicePrincipals.Count)
	Write-Host ("Loaded {0} Subscriptions" -f $OldTenant.Subscriptions.Count)
	exit(0)
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if($null -eq $here){$here="."}

$ObjectIdTranslation = @{}
$BackupPath = "$here\Backup_{0}" -f (Get-Date).ToString("yyyyMMdd")
#endregion

#region "Functions"
Function Find-AzureUser {
  Param(
    [Parameter(Mandatory)]
    [String] $userPrincipalName
  )

  Write-Verbose "######## BEGIN - Find-AzureUser ########"
  Write-Verbose "Parameter userPrincipalName is now = $userPrincipalName"
  Write-Verbose "Executing Get-AzureADUser by looking for $userPrincipalName UPN"
  $User = Get-AzureADUser -Filter "userPrincipalName eq '$userPrincipalName'"

  if(!$User){
    Write-Verbose "User with that UPN was not found"
    if($userPrincipalName.Contains("#EXT#")){
      Write-Verbose "UPN seems to be a B2B UPN"
      $userPrincipalName = $userPrincipalName.SubString(0,$userPrincipalName.IndexOf("#")).Replace("_","@")
  
      Write-Verbose "Executing Get-AzureADUser by looking for $userPrincipalName UPN"
      $User = Get-AzureADUser -Filter "userPrincipalName eq '$userPrincipalName'"

      if($User) {
        Write-Verbose "User found :)"
      }
      else {
        Write-Verbose "User NOT found... :("
      }
    }
  }
  else {
    Write-Verbose "User found :)"
  }

  Write-Verbose "######## END - Find-AzureUser ########"
  $User | Write-Verbose
  $User
}

Function Find-AzureObjectId {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Mandatory)]
    [string] $ObjectId,
    [ValidateSet("User","Group","ServicePrincipal")]
    [string] $ObjectType = ""
  )

  Write-Verbose "######## BEGIN - Find-AzureObjectId ########"
  Write-Verbose "Parameter ObjectID is now = $ObjectId"
  Write-Verbose "Parameter ObjectType is now = $ObjectType"

  $NewObjectId = $ObjectIdTranslation.$ObjectId

  If(!$NewObjectId){
    If($ObjectType -eq "Group") {
      $OldObject = $OldTenant.Groups | Where-Object -Property ObjectId -EQ -Value $ObjectId
      $GroupName = "{0}{1}" -f $Prefix,$OldObject.DisplayName
      
      $Group = Get-AzureADGroup -Filter "DisplayName eq '$GroupName'"

      If(!$Group) {
        Write-Verbose "Group '$GroupName' was NOT found in this tenant"

        if($PSCmdlet.ShouldProcess($GroupName,'New-AzureADGroup')){
          $Group = New-AzureADGroup -DisplayName $GroupName -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
          New-Object PSObject -Property @{"ObjectType"="Azure AD Group";"Name"=$GroupName;"Action"="Created";"Timestamp"=(Get-Date)} | Export-Csv "$here\ChangeLog.csv" -NoType -Append
  
          ForEach($Member In $OldObject.Members) {
            Add-AzureADGroupMember -ObjectId $Group.ObjectId -RefObjectId (Find-AzureObjectId -ObjectId $Member.ObjectId -ObjectType $Member.ObjectType)
            New-Object PSObject -Property @{"ObjectType"="Azure AD Group";"Name"=$GroupName;"Action"="Added member";"Timestamp"=(Get-Date)} | Export-Csv "$here\ChangeLog.csv" -NoType -Append
          }
        }
        else {
          $Group = New-Object PSObject -Property @{"ObjectId" = (New-Guid).Guid}
        }
      }
      else {
        Write-Verbose "Group '$GroupName' was found"
        $Group | Write-Verbose
      }

      Write-Verbose ("Caching {0} object id for old object ({1})" -f $Group.ObjectId,$OldObject.ObjectId)
      $ObjectIdTranslation.Add($OldObject.ObjectId,$Group.ObjectId)
      $NewObjectId = $Group.ObjectId
    }
    elseIf($ObjectType -eq "ServicePrincipal") {
      $OldObject = $OldTenant.ServicePrincipals | Where-Object -Property ObjectId -EQ -Value $ObjectId
      $SPNName = "{0}{1}" -f $Prefix,$OldObject.DisplayName
      $SPN = Get-AzureADServicePrincipal -Filter "DisplayName eq '$SPNName'"

      If(!$SPN) {
        Write-Verbose "Service Principal '$SPNName' was NOT found in this tenant"

       if($PSCmdlet.ShouldProcess($SPNName,'New-AzureADApplication')) {
         $App = Get-AzureADApplication -Filter "DisplayName eq '$SPNName'"

         If(!$App) {
            Write-Verbose "Azure AD Application does NOT exists. Creating it..."
            if(!$OldObject.ReplyURLs){
              $OldObject.ReplyURLs = "http://localhost"
            }
            
            if(!$OldObject.HomePage){
              $OldObject.HomePage = "http://localhost"
            }
           $App = New-AzureADApplication -DisplayName $SPNName -Homepage $OldObject.HomePage -ReplyUrls $OldObject.ReplyURLs

           $SPN = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $true -DisplayName $SPNName -Tags {WindowsAzureActiveDirectoryIntegratedApp}
           New-Object PSObject -Property @{"ObjectType"="Azure AD Service Principal";"Name"=$SPNName;"Action"="Created";"Timestamp"=(Get-Date)} | Export-Csv "$here\ChangeLog.csv" -NoType -Append
         }
         else {
            Write-Verbose "Azure AD Application exists. Verifying if SPN exists"
            $SPN = Get-AzureADServicePrincipal -Filter ("AppID eq '{0}'" -f $App.AppId)

            if(!$SPN) {
              $SPN = New-AzureADServicePrincipal -AccountEnabled $true -AppId $App.AppId -AppRoleAssignmentRequired $true -DisplayName $SPNName -Tags {WindowsAzureActiveDirectoryIntegratedApp}
              New-Object PSObject -Property @{"ObjectType"="Azure AD Service Principal";"Name"=$SPNName;"Action"="Created";"Timestamp"=(Get-Date)} | Export-Csv "$here\ChangeLog.csv" -NoType -Append
            }
         }
         

         if($OldObject.Owners -ne "None") {
           Add-AzureADApplicationOwner -ObjectId $App.ObjectId -RefObjectId (Find-AzureUser -userPrincipalName $OldObject.UserPrincipalName).ObjectId
           New-Object PSObject -Property @{"ObjectType"="Azure AD Service Principal";"Name"=$SPNName;"Action"="Owner Added";"Timestamp"=(Get-Date)} | Export-Csv "$here\ChangeLog.csv" -NoType -Append
         }
       }
       else {
         $SPN = New-Object PSObject -Property @{"ObjectId" = (New-Guid).Guid}
       }
      }
      else {
        Write-Verbose "Service Principal '$SPNName' was found"
        $SPN | Write-Verbose
      }

      Write-Verbose ("Caching {0} object id for old object ({1})" -f $SPN.ObjectId,$OldObject.ObjectId)
      $ObjectIdTranslation.Add($OldObject.ObjectId,$SPN.ObjectId)
      $NewObjectId = $SPN.ObjectId
    }
    elseIf($ObjectType -eq "User") {
      $OldObject = $OldTenant.Users | Where-Object -Property ObjectId -EQ -Value $ObjectId
      
	  if($OldObject.UserPrincipalName) {
		  $User = Find-AzureUser -userPrincipalName $OldObject.UserPrincipalName

		  If($User)
		  {
			Write-Verbose ("Caching {0} object id for old object ({1})" -f $User.ObjectId,$OldObject.ObjectId)
			$ObjectIdTranslation.Add($OldObject.ObjectId,$User.ObjectId)
			$NewObjectId = $User.ObjectId
		  }
	  }
	  else {
		return $ObjectId
	  }
    }
    else{
      $Object = $OldTenant.Groups | Where-Object -Property ObjectId -EQ -Value $ObjectId

      If($Object){
        Write-Verbose "Object id $ObjectId has been identified as a GROUP"
        $NewObjectId = Find-AzureObjectId -ObjectId $ObjectId -ObjectType "Group"
      }
      else {
        $Object = $OldTenant.ServicePrincipals | Where-Object -Property ObjectId -EQ -Value $ObjectId

        If($Object){
          Write-Verbose "Object id $ObjectId has been identified as a SERVICE PRINCIPAL"
          $NewObjectId = Find-AzureObjectId -ObjectId $ObjectId -ObjectType "ServicePrincipal"
        }
        else {
          Write-Verbose "Object id $ObjectId has been identified as an USER"
          $NewObjectId = Find-AzureObjectId -ObjectId $ObjectId -ObjectType "User"
        }
      }
    }
  }

  Write-Verbose "Returning ObjectId: $NewObjectId"
  Write-Verbose "######## END - Find-AzureObjectId ########"
  return $NewObjectId
}
#endregion

Write-Verbose "Checking if $BackupPath exists"
If(!(Test-Path $BackupPath)) {
  if($PSCmdlet.ShouldProcess($BackupPath,'New-Item')){
    New-Item -Path $BackupPath -ItemType Directory | Out-Null
  }
}

ForEach($Subscription In $OldTenant.Subscriptions) {
  Write-Output ("Working on subscription {0} ({1})" -f $Subscription.SubscriptionName, $Subscription.SubscriptionId)

  $Scope = "/subscriptions/{0}" -f $Subscription.SubscriptionId
  Write-Verbose ("Scope is {0}" -f $Scope)
  $FirstTime = $true

  do {
    if(!$FirstTime){
      Write-Output "Azure moment.... waiting 15 seconds..."
      Start-Sleep -Seconds 15
    }

    $FirstTime = $false
    Select-AzSubscription -SubscriptionId $Subscription.SubscriptionId
  } while((Get-AzContext).Subscription.Id -ne $Subscription.SubscriptionId)
  
  if(!$SkipSubscription) {
    Write-Output "Retrieving current RBAC..."
    $CurrentRights = Get-AzRoleAssignment -Scope $Scope
  }
  
  $TenantId = (Get-AzContext).Tenant.Id
  Write-Verbose "Tenant ID is: $TenantId"

  if(!$SkipKeyVault) {
  Write-Output "`t Azure KeyVault"
  ForEach($KeyVault In (Get-AzKeyVault | Get-AzResource | Where-Object -FilterScript {$_.Properties.tenantId -ne $TenantId})) {
  
    Write-Output ("`t`t Vault {0} at Resource Group {1}" -f $KeyVault.Name, $KeyVault.ResourceGroupName)
    
    if(!(Test-Path ("$BackupPath\{0}_{1}.xml" -f $KeyVault.ResourceGroupName, $KeyVault.Name))){
      Export-Clixml -InputObject $KeyVault -Path ("$BackupPath\{0}_{1}.xml" -f $KeyVault.ResourceGroupName, $KeyVault.Name)
    }

    Write-Verbose ("`t`t`tCurrent TenantId: {0}"  -f $KeyVault.Properties.tenantId)
    $KeyVault.Properties.tenantId = $TenantId

    ForEach($AccessPolicy In $KeyVault.Properties.accessPolicies) {
	  $NewObjectId = Find-AzureObjectId -ObjectId $AccessPolicy.objectId
	  
	  if($NewObjectId) {
		Write-Verbose ("Updating Access Policy - Old Tenant Id: {0} - Old Object Id: {1}" -f $AccessPolicy.tenantid, $AccessPolicy.objectId)
		$AccessPolicy.tenantid = $TenantId
		$AccessPolicy.objectId = Find-AzureObjectId -ObjectId $AccessPolicy.objectId
		Write-Verbose ("Updating Access Policy - New Tenant Id: {0} - New Object Id: {1}" -f $AccessPolicy.tenantid, $AccessPolicy.objectId)
	  }
    }

    if($PSCmdlet.ShouldProcess($KeyVault,'Set-AzResource')){
      Write-Output "`t`tSaving changes"
      Set-AzResource -ResourceId $KeyVault.Id -Properties $KeyVault.Properties -Force -Verbose
    }
    else
    {
      Write-Verbose ("SAVING - Tenant Id: {0}" -f $KeyVault.Properties.tenantId)
    }
  }
  }

  if(!$SkipSubscription) {
  Write-Output "Adding permissions to the Subscription"
  ForEach($OldRight In $Subscription.RBAC){
    if($OldRight.ObjectType -eq "User"){
      $VerboseDisplayName = $OldRight.DisplayName
    }
    else {
      $VerboseDisplayName = "{0}{1}" -f $Prefix, $OldRight.DisplayName
    }

    Write-Verbose ("Granting {0} to '{1}'" -f $OldRight.RoleDefinitionName, $VerboseDisplayName)
    if($PSCmdlet.ShouldProcess($VerboseDisplayName,'New-AzRoleAssignment')) {
      $ObjectId = (Find-AzureObjectId -ObjectId $OldRight.ObjectId -ObjectType $OldRight.ObjectType)

      if($ObjectId) {
        #if(-not (Get-AzRoleAssignment -ObjectId $ObjectId -Scope $Scope -RoleDefinitionName $OldRight.RoleDefinitionName)) {
        if(-not ($CurrentRights | Where-Object -FilterScript {$_.ObjectId -eq $ObjectId -and $_.ObjectType -eq $OldRight.ObjectType -and $_.RoleDefinitionName -eq $OldRight.RoleDefinitionName})){
          New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $OldRight.RoleDefinitionName -Scope $Scope
        }
      }
    }
    else{
      Write-Verbose "Cmdlet: New-AzRoleAssignment"
      Write-Verbose "Param - ObjectId: $(Find-AzureObjectId -ObjectId $OldRight.ObjectId -ObjectType $OldRight.ObjectType)"
      Write-Verbose "Param - RoleDefinitionName: $($OldRight.RoleDefinitionName)"
    }
  }
  }

  Write-Output "`n"
  Write-Output "`n"
}

if($PSCmdlet.ShouldProcess($ObjectIdTranslation,'Save object')) {
  $ObjectIdTranslation | ConvertTo-Json | Out-File "$here\ObjectIdTranslation.json"
}
