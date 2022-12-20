<#
$users=Get-ADUser -LDAPFilter "(displayName=*)" -Properties Title,Name,department,SamAccountName,telephoneNumber,LastLogonDate,enabled,accountExpires,mail,objectSid | Select-Object Title,Name,SamAccountName,telephoneNumber,LastLogonDate,enabled,accountExpires,mail,objectSid,Abfragedatum
foreach ($u in $users){
    $u.accountExpires.Value
}
#>

#$Users = Get-ADUser -filter * -Properties samaccountname,name,surname,lastlogondate,enabled,msDS-UserPasswordExpiryTimeComputed,PasswordLastSet,CannotChangePassword
#Get-ADUser -filter {samaccountname -eq "lm26"} -Properties samaccountname,name,surname,lastlogondate,enabled,msDS-UserPasswordExpiryTimeComputed,PasswordLastSet,CannotChangePassword | select-object samaccountname,name,surname,lastlogondate,enabled,@{Name="ExpiryDate";Expression={if ($null -ne $u."msDS-UserPasswordExpiryTimeComputed") {[datetime]::FromFileTime($u."msDS-UserPasswordExpiryTimeComputed")} else {"Never"}}},PasswordLastSet,CannotChangePassword | ft

$maxlastlogondays=90  # Maximum days since last logon
$today=Get-Date # Current Timestamp
$users = Get-ADUser -filter * -Properties Title,Name,department,SamAccountName,telephoneNumber,LastLogonDate,enabled,AccountExpirationDate,mail,objectSid 

# Get all members of the two target groups. This way is faster, than retrieving all groups for each user
$membersofnetapp=Get-ADGroupMember -Identity site-EigDat-Storage-NetApp
$membersofoceanstore=Get-ADGroupMember -Identity site-EigDat-Storage-OceanStor

[System.Collections.ArrayList]$usersidsofnetapp = @()
[System.Collections.ArrayList]$usersidsofoceanstore = @()

# gather all SID's
foreach ($member in $membersofnetapp){
	$null=$usersidsofnetapp.add($member.SID)
}

foreach ($member in $membersofoceanstore){
	$null=$usersidsofoceanstore.add($member.SID)
}

[int]$counter=1
foreach ($u in $users) {
	[int]$percs=100/$users.Count * $counter # calculate procentual progress
	Write-Progress -Activity ("Processing User " + $counter + "/" + $users.Count) -Status "$percs% Progress:" -PercentComplete $percs # show progressbar

	if ($null -eq $u){
        $myreturn = 2
    }
    if ($null -eq $u.objectSid){
        $myreturn = 3
    }

	#Write-Host ($u.samaccountname + " " + $u.Name + " " + $u.objectSid)

	# Get the days since last logon
	$lastlogondays=0
	if ($null -ne $u.LastLogonDate){
		# LastLogonDate is set
		$ts = New-TimeSpan -Start $u.LastLogonDate -End $today # Timespan since last logon
		$lastlogondays=([math]::Ceiling($ts.TotalDays))  # Days since last logon
	}
	
	# Get the days since account expiry
	$dayssinceexpiry=0
	if ($null -ne $u.AccountExpirationDate){
		# AccountExpirationDate is set
		$ts2 = New-TimeSpan -Start $u.AccountExpirationDate -End $today # Timespan since ExpiryDate
		$dayssinceexpiry=([math]::Ceiling($ts2.TotalDays)) # Days since account-expiry
	}	

	$u | Add-Member -MemberType NoteProperty -Value $lastlogondays -Name LastLogonDays -Force

	$suggestdeactivate="?"  # should the account be deactivated
	$suggestdelete=$false # should the account be deleted
	if (!$u.enabled) { # account is disabled
		$suggestdeactivate="bereits deaktiviert"
		if ($ts.Days -gt 180){
			$suggestdelete=$true # account is not in use for at least 180 Days and is already deactivated
		}
	}
	else { #Account is enabled
		if ($dayssinceexpiry -gt 0 -or $lastlogondays -gt $maxlastlogondays){
			$suggestdeactivate="Ja"  # account has been expired or last logon was at least x days ago
		}
		else {
			$suggestdeactivate="Nein"  # account has not been expired and last logon was less than x days ago
		}
	}
	$u | Add-Member -MemberType NoteProperty -Value $suggestdeactivate -Name SuggestDeactivate -Force
	$u | Add-Member -MemberType NoteProperty -Value $suggestdelete -Name SuggestDelete -Force
    $u | Add-Member -MemberType NoteProperty -Value $today -Name Abfragedatum -Force

	# Check user's group-memberships
	$ismemberofNetApp=$false
	$ismemberofOceanStore=$false
	
	try {
		foreach ($mnu in $membersofnetapp){
			if ($mnu.SID.Equals($u.SID)){
				$ismemberofNetApp=$true
				break;
			}
		}

		foreach ($mou in $membersofoceanstore){
			if ($mou.SID.Equals($u.SID)){
				$ismemberofOceanStore=$true
				break;
			}
		}
		<#$gms=Get-ADPrincipalGroupMembership  $u | Select-Object name
		if ($null -ne $gms){ # if at least one group exists
			 
			[System.Collections.ArrayList]$groups = @()
			$groups.AddRange(@($gms))
			
			foreach ($group in $groups){
				if ($group.Name.equals("site-EigDat-Storage-NetApp")){
					$ismemberofNetApp=$true
					continue
				}
				if ($group.Name.equals("site-EigDat-Storage-OceanStor")){
					$ismemberofOceanStore=$true
					
				}
			}
			
		}#>
	}
	catch {
		Write-Warning ("Unable to get group information for user " + $u.samaccountname)
        $myreturn = 1
	}
	
	
	$u | Add-Member -MemberType NoteProperty -Value $ismemberofNetApp -Name ismemberofNetApp -Force
	$u | Add-Member -MemberType NoteProperty -Value $ismemberofOceanStore -Name ismemberofOceanStore -Force

	$counter++
    #$u
} 
$users | Select-Object Title,Name,department,SamAccountName,telephoneNumber,LastLogonDate,LastLogonDays,enabled,AccountExpirationDate,mail,objectSid,SuggestDeactivate,SuggestDelete,ismemberofNetApp,ismemberofOceanStore,Abfragedatum | ft
Get-ADGroup -Filter * -Properties Name,samaccountname,SID,objectGUID,groupcategory | select-object -Property Name,samaccountname,SID,objectGUID,groupcategory | Export-Csv -Path \\apofakt\DEBUG\Get-Aduser\get-adgroups.csv -Delimiter ";" -NoTypeInformation -Encoding UTF8
#foreach ($u in $users){
	#$u | ft
	#$u | select-object @{Name="ExpiryDate";Expression={if ($null -ne $u."msDS-UserPasswordExpiryTimeComputed" -and $u."msDS-UserPasswordExpiryTimeComputed" -gt 0) {[datetime]::FromFileTime($u."msDS-UserPasswordExpiryTimeComputed")} else {"Never"}}} 
#}