<#
Migrate's user's from one AD-Groups to another.
D. Maienhöfer, 2021/11
#>

param(
    $sourcegroup="site-EigDat-Storage-NetApp",
    $targetgroup=" site-EigDat-Storage-OceanStor",
    $userlist="C:\temp\fas-migration-list.txt"
)

function printhelp(){
    Write-Host "Migrates users from one AD-group to another."
    write-host ""
    Write-Host "Usage: migrate-user-group -sourcegroup <SOURCEGROUP> -targetgroup <TARGETGROUP> [-userlist <USERLISTFILE>]"
    Write-Host
    Write-Host "If no userlist is specified all mebers (users) of the sourcegroup are referenced."
    
}

if ($null -eq $sourcegroup -or $null -eq $targetgroup){
    printhelp
    exit 1
}

# Get current members of source and target-groups
Write-Host ("Gathering info about members of sourcegroup `"" + $sourcegroup + "`"")
$sourcegroupmembers=Get-ADGroupMember -Identity $sourcegroup
if ($sourcegroupmembers.Count -lt 1) {
    Write-Warning ("Group `"" + $sourcegroup + "`" contains no users! - Make sure you specified the correct group.")
    exit 2
}

Write-Host ("Gathering info about members of targetgroup `"" + $targetgroup + "`"")
$targetgroupmembers=Get-ADGroupMember -Identity $targetgroup 

[System.Collections.ArrayList]$usersidssourcegroupmembers = @()
[System.Collections.ArrayList]$usersidstargetgroupmembers = @()

# gather all SID's
foreach ($member in $sourcegroupmembers){
    if ($member.SamAccountName -eq "bs38")
    {
        write-verbose "DEBUG"
    }
    
	$null=$usersidssourcegroupmembers.add($member.SID.Value)
}

foreach ($member in $targetgroupmembers){
	$null=$usersidstargetgroupmembers.add($member.SID.Value)
}



[System.Collections.ArrayList]$userstoprocess = @()

if ($null -ne $userlist){
    # Userlist is specified
    Write-Host ("Userlist `"" + $userlist + "`"is specified.")
    try {
        $userstoprocess.AddRange( (Get-Content $userlist))
        Write-Host ("Successfully read users from `"" + $userlist + "`"")
    }
    catch {
        Write-Error ("Unable to read content of `"" + $userlist + "`" - Make sure the file exists and you have sufficient permissions.")
        exit 3
    }
}
else {
    Write-Host "Userlist is not specified. Assuming all users of the sourcegroup."
    foreach ($member in $sourcegroupmembers){
        $null=$userstoprocess.add($member.samaccountname)
    }

}

Write-Host "`r`nUsers in scope:"

foreach ($user in $userstoprocess){Write-Host ($user+", ") -NoNewline}
Write-Host ""
Write-Warning ("About to move " + $userstoprocess.Count.ToString() + " users (see above) from `"" + $sourcegroup + "`" to `"" + $targetgroup + "`"...") -WarningAction Inquire

foreach ($samaccountname in $userstoprocess){
    $sid = (Get-ADUser -Filter  {samaccountname -eq $samaccountname} -Properties SID | Select-Object -Property SID).SID.Value
    
    if ($usersidssourcegroupmembers.Contains($sid)){
        # Current user is member of the sourcegroup
        Write-Host ("User `""+$samaccountname+"`" is a member of sourcegroup `""+$sourcegroup+"`".")
        try {
            Write-Host ("Adding `"" + $samaccountname + "`" to target-group `"" + $targetgroup + "`".")
            Add-ADGroupMember -Identity $targetgroup -Members $samaccountname
            Write-Host ("Success...")

            Write-Host ("Removing `"" + $samaccountname + "`" from source-group `"" + $sourcegroup + "`".")
            Remove-ADGroupMember -Identity $sourcegroup -Members $samaccountname
            Write-Host ("Success...")
        }
        catch {            
           Write-Error ("Unable to move user `"" + $samaccountname + "`" from `"" + $sourcegroup + "`" to `"" + $targetgroup + "`" => " + $_.Exception.Message) 
        }

    }
    else {
        # Current user is NOT member of the sourcegroup
        Write-Warning ("User `""+$samaccountname+"`" is not a member of sourcegroup `""+$sourcegroup+"`". Won't move User!")
    }
}

exit 0


