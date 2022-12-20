<#
Searches disabled AD-objects, that are member of a specific group and reverts the changes done by "disable-old-adobjects.ps1".

D. Maienhöfer, 2022/06
#>

param(
    [string[]]$neededgroupmemberships= @("CTX-site-Arzt", "CTX-site-Pflege"), # groups which the object must be member of
    [switch]$dryrun=$false,
    [switch]$nousers=$false,  # don't look for user-objects
    [switch]$nocomputers=$false, # don't look for user-objects
    [string]$searchbase="OU=Alt_Inaktiv,DC=eine,DC=firma,DC=local" # searchbase of object to lookup 
)

function extractdescriptioninfo($description, $searchfor){    
    $startpos=$description.indexOf($searchfor) + $searchfor.Length +1 
    $result=$description.substring($startpos)
    $endpos=$result.indexof('"')
    
    $result=$result.substring(0, $endpos)
    return $result
}

function findoriginalou($description){
    # Finds the originating OU by parsing the description
    $result = extractdescriptioninfo -description $description -searchfor "Originating LDAP-Path: "

    $searchfor="OU="
    $startpos=$result.indexOf($searchfor)
    $result=$result.substring($startpos)
    return $result
}

function findoriginaldescription($description){
    $result = extractdescriptioninfo -description $description -searchfor "Original description: "
    return $result
}

function restoreuser($user){
    $movetoou=findoriginalou($user.description)
    $orgdescription=findoriginaldescription($user.description)
    
    if (!$dryrun){
        Write-Warning("Restoring " + $user.distinguishedname + " - "+$user.name+" => " + $orgdescription + " => moving to: " + $movetoou)
        Set-ADUser -Identity $user.distinguishedname -Description $orgdescription # Restore description
        Enable-ADAccount -Identity $user.distinguishedname # Reenable Account
        Move-ADObject -Identity $user.distinguishedname -TargetPath $movetoou # Move Account to original OU        
    }
    else {
        Write-Host("Would restore " + $user.distinguishedname + " - "+$user.name+" => " + $orgdescription + " => moving to: " + $movetoou)
    }
}

function restorecomputer($computer){
    $movetoou=findoriginalou($computer.description)
    $orgdescription=findoriginaldescription($computer.description)
    
    if (!$dryrun){
        Write-Warning("Restoring " + $computer.distinguishedname + " - "+$computer.name+" => " + $orgdescription + " => moving to: " + $movetoou)
        Set-ADComputer -Identity $computer.distinguishedname -Description $orgdescription # Restore description
        Enable-ADAccount -Identity $computer.distinguishedname # Reenable Account
        Move-ADObject -Identity $computer.distinguishedname -TargetPath $movetoou # Move Account to original OU        
    }
    else {
        Write-Host("Would restore " + $user.distinguishedname + " - "+$user.name+" => " + $orgdescription + " => moving to: " + $movetoou)
    }
}

# Main

if ($null -eq $neededgroupmemberships){
    Write-Warning "Please specify at least one group with -neededgroupmemberships. Aborting."
    exit(1)
}

Write-Host "Will reenable disabled objects that are member of at least one of the following groups:"
foreach ($group in $neededgroupmemberships){
    Write-Host $group
}

if (!$nousers){
    Write-Host "Searching objects..."
    $users = (Get-ADUser -Filter * -Searchbase $searchbase -Properties name,samaccountname,enabled,samaccountname,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $false -and $_.samaccountname -notlike '*$'} | Select-Object -Property name,samaccountname,enabled,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    Write-Host "Checking group-memberships..."
    $count=0    
    foreach ($u in $users){
        $count+=1
        $percentage = 100 / $users.count * $count
        Write-Progress -PercentComplete $percentage -Activity ("Checking user " + $count + " of " + $users.Count)
        $groupmemberships = (Get-ADPrincipalGroupMembership $u.samaccountname | Select-Object name) # get all groups, the object is member of
        $abort=$false
        foreach ($group1 in $neededgroupmemberships){ # Iterate through all groups to lookup
            if ($abort){
                break;
            }
            foreach ($group2 in $groupmemberships) {
                if ($group2.name -eq $group1){  # if the object is member of on the of the groups, reenable it and continue with the next user
                    restoreuser -user $u
                    $abort=$true
                    break;
                }
            }
        }
    }
}
else {
    Write-Host ("-nousers is set: skipping userobjects")
}


if (!$nocomputers){
    $computers = (Get-ADComputer -SearchBase $searchbase -Filter * -Properties name,enabled,operatingsystem,operatingsystemversion,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $false -and $_.operatingsystem -like "*Windows*" -and $_.operatingsystem -notlike "*Server*"} | Select-Object -Property name,enabled,operatingsystem,operatingsystemversion,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    Write-Host "Checking group-memberships..."
    $count=0   
    foreach ($c in $computers){
        $count+=1
        $percentage = 100 / $computers.count * $count
        Write-Progress -PercentComplete $percentage -Activity ("Checking user " + $count + " of " + $computers.Count)
        $groupmemberships = (Get-ADPrincipalGroupMembership $c.samaccountname | Select-Object name) # get all groups, the object is member of
        $abort=$false
        foreach ($group1 in $neededgroupmemberships){ # Iterate through all groups to lookup
            if ($abort){
                break;
            }
            foreach ($group2 in $groupmemberships) {
                if ($group2.name -eq $group1){  # if the object is member of on the of the groups, reenable it and continue with the next user
                    restorecomputer -computer $c
                    $abort=$true
                    break;
                }
            }
        }
    }
}
else {
    Write-Host ("-nocomputers is set: skipping computerobjects")
}
exit(0)