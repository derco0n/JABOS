<#
This script will find all still existing AD-Useraccounts of people who left the company as specified in in a given .csv-File with the following fields:

Haus;HausNummer;Abteilung;PSN;Titel;Vorsatzwort;Nachname;Vorname;Vertragsbeginn;Vertragsende

Note that this script will try to find accounts, that match given and last name which is not an absolute identifier.
However the script will check if there is more than one account with the same given and lastname to prevent disabling any wrong account.
Those duplets will be exported to .csv-file in the same directory as the source file.

There is also a check that prevents to find any account in the target OU, to avoid retouching any account that has already been moved.

Results, therefore user-accounts that should be disabled or (if -disable is set) had been disabled, will be exported to a .csv-file in the same directory as the source file.

This will aid in finding old obsolete accounts of people who are not longer employed.
D. Maienhöfer, 2022/12
https://github.com/derco0n
#>

param(
    $csvfile="Y:\ad-konten_ausgeschiedene_ma\AA___Mitarbeiterliste_alle_IT.CSV", # Input .csv-file
    [string]$usermoveto="OU=Benutzer,OU=Alt_Inaktiv,DC=eine,DC=firma,DC=local", # the target OU in LDAP notation, to where accounts should be moved
    [Switch]$disable=$false # if set to true, the accounts will be disabled
)

if (!(Test-Path $csvfile)){
    Write-Warning ("Input file `"" + $csvfile + "`" could not be found. Aborting.")
    exit 1
}

$today=[DateTime]::Now

function disableuserobject($user, $moveto){    # This function will move and disable a given user account
    if ($null -ne $user.YoungestVertragsende){
        $user.description="Disabled administratively on "+$today.ToString()+" as the User had its last working day in the company on "+$user.YoungestVertragsende +". Originating LDAP-Path: `""+$user.distinguishedname+"`" Original description: `"" + $user.description + "`""       
    }
    else {
        $user.description="Disabled administratively on "+$today.ToString()+" as the User had left the company. Originating LDAP-Path: `""+$user.distinguishedname+"`" Original description: `"" + $user.description + "`""       
    }    
    Set-ADUser -Identity $user.distinguishedname -Description $user.description # Update description
    Disable-ADAccount -Identity $user.distinguishedname # Disable Account
    Move-ADObject -Identity $user.distinguishedname -TargetPath $moveto # Move Account to different OU    
}



# clear the header of the .csv
$inputfilepath=(Split-Path $csvfile -Parent)
$tempfile=$inputfilepath.TrimEnd('\')+"\temp_"+[guid]::NewGuid()+".csv"
Copy-Item $csvfile $tempfile

$A = Get-Content -Path $tempfile -Encoding UTF8
$A = $A[1..($A.Count - 1)]
$A | Out-File -FilePath $tempfile -Encoding UTF8


# Arraylist with employe-objects 
$employees = [System.Collections.ArrayList]::new()

# Import the contents of the .csv-file usig a custom header
$cont=Import-csv -Path $tempfile -encoding UTF8 -Delimiter ';' -header 'Haus', 'HausNummer', 'Abteilung', 'PSN', 'Titel', 'Vorsatzwort', 'Nachname', 'Vorname', 'Vertragsbeginn', 'Vertragsende'
Remove-Item $tempfile -Force

$count=0
foreach ($elem in $cont){
    $count+=1
    $perc=100/$cont.Count*$count
    write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$elem.PSN+" ("+$elem.Nachname+", "+$elem.Vorname+")") -Status "Initialization" -PercentComplete $perc
    #write-host ($elem.Hausnummer + " " + $elem.PSN + " " + $elem.Nachname + " "+ $elem.Vorname + " "+ $elem.Vertragsende)
    
    $alreadythere=$false
    write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$elem.PSN+" ("+$elem.Nachname+", "+$elem.Vorname+")") -Status "Checking if already found" -PercentComplete $perc
    foreach ($e in $employees){ # check if there's already an employee with the same name
        if (<#$e.PSN -eq $elem.PSN -and #>$e.Vorname -eq $elem.Vorname -and $e.Nachname -eq $elem.Nachname){            
            # employe is already in the list, 
            $alreadythere=$true
            if ($null -ne $elem.PSN -and $elem.PSN -ne ""){ #check if PSN is given
                $e.PSNs+=@($elem.PSN)
            }
            if ($null -ne $elem.Vertragsende -and $elem.Vertragsende -ne ""){ # check if vertragsende is given
                #we have to add another Vertragsende's value
                $e.Vertragsenden+=@([DateTime]::ParseExact($elem.Vertragsende, 'dd.MM.yyyy', $null))                
                }
            if ($null -ne $elem.Vertragsbeginn -and $elem.Vertragsbeginn -ne ""){ # check if vertragsbeginn is given
                #we have to add another Vertragbeginn's value
                $e.Vertragsbeginne+=@([DateTime]::ParseExact($elem.Vertragsbeginn, 'dd.MM.yyyy', $null))                
                }  
            break
        }
        # yeah, i know that this is slowing things down...even more, the larger the dataset is....
    }
    
    write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$elem.PSN+" ("+$elem.Nachname+", "+$elem.Vorname+")") -Status "Crafting new entry" -PercentComplete $perc
    if (!$alreadythere){
        # The current employee isn't in the list yet, so we'#ve to craft a new dataset
        $employe=New-Object PSObject
        $employe | add-member -MemberType NoteProperty -Name "StillEmployed" -Value $true
        $employe | add-member -MemberType NoteProperty -Name "PSNs" -Value $elem.PSN
        if ($null -ne $elem.PSN -and $elem.PSN -ne ""){ # If the user has at least one Vertragsende, add it's value
            $employe.PSNs = @($elem.PSN) 
        }
        $employe | add-member -MemberType NoteProperty -Name "Vorname" -Value $elem.Vorname
        $employe | add-member -MemberType NoteProperty -Name "Nachname" -Value $elem.Nachname
        $employe | add-member -MemberType NoteProperty -Name "Vertragsenden" -Value $null
        if ($null -ne $elem.Vertragsende -and $elem.Vertragsende -ne ""){ # If the user has at least one Vertragsende, add it's value
            $employe.Vertragsenden = @([DateTime]::ParseExact($elem.Vertragsende, 'dd.MM.yyyy', $null)) # parse string to datetime
        }
        $employe | add-member -MemberType NoteProperty -Name "Vertragsbeginne" -Value $null
        if ($null -ne $elem.Vertragsbeginn -and $elem.Vertragsbeginn -ne ""){ # If the user has at least one Vertragsende, add it's value
            $employe.Vertragsbeginne = @([DateTime]::ParseExact($elem.Vertragsbeginn, 'dd.MM.yyyy', $null)) # parse string to datetime
        } 
        $null=$employees.Add($employe)
    }
}

# Check if this one is still employed
# The youngest Vertragende must be in the past and there mustn't be any Vertragsbeginn that is newer than the youngest Vertragsende
$count=0
foreach ($employe in $employees){
    $count+=1
    $perc=100/$employees.Count*$count
    write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$employe.PSN+" ("+$employe.Nachname+", "+$employe.Vorname+")") -Status "Searching youngest Vertragsbeginn" -PercentComplete $perc
    $youngestVertragsbeginn=$null
    foreach ($vb in $employe.Vertragsbeginne)
    {
        if ($null -eq $vb){
            continue # vertragsbeginn is not given. skip this one
        }
        
        if ($null -eq $youngestVertragsbeginn){
            $youngestVertragsbeginn = $vb # if vertragsbeginn hasn't set before, set this one
            continue
        }

        if ($vb.ticks -gt $youngestVertragsbeginn.ticks){
            # This vertragsbeginn is newer than the one previously stored
            $youngestVertragsbeginn=$vb
        }
    }
    if ($null -ne $youngestVertragsbeginn){
        $employe | add-member -MemberType NoteProperty -Name "YoungestVertragsbeginn" -Value $youngestVertragsbeginn.toString()    
    }
    else {
        $employe | add-member -MemberType NoteProperty -Name "YoungestVertragsbeginn" -Value $youngestVertragsbeginn #$null  
    }

    write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$employe.PSN+" ("+$employe.Nachname+", "+$employe.Vorname+")") -Status "Searching youngest Vertragsende" -PercentComplete $perc
    $youngestVertragsende=$null
    foreach ($ve in $employe.Vertragsenden)
    {
        if ($null -eq $ve){
            continue # vertragsende is not given. skip this one
        }
        
        if ($null -eq $youngestVertragsende){
            $youngestVertragsende = $ve # if vertragsende hasn't set before, set this one
            continue
        }

        if ($ve.ticks -gt $youngestVertragsende.ticks){
            # This vertragsende is newer than the one previously stored
            $youngestVertragsende=$ve
        }
    }
    if ($null -ne $youngestVertragsende){
        $employe | add-member -MemberType NoteProperty -Name "YoungestVertragsende" -Value $youngestVertragsende.toString()    
    }
    else {
        $employe | add-member -MemberType NoteProperty -Name "YoungestVertragsende" -Value $youngestVertragsende #$null  
    }

    # Determining if employe is still here or vanished long before
    if (
        $null -ne $youngestVertragsende -and # at least 1 Vertragsende must be given, otherwise it is an existing permanent contract
        $youngestVertragsende.Ticks -lt $today.Ticks -and # the youngest Vertragsende must be in the past
        $youngestVertragsende.Ticks -gt $youngestVertragsbeginn.Ticks # the youngest Vertragsende must be after the youngest Vertragsbeginn
        )
        {
        # employe must be vanished
        $employe.StillEmployed = $false
    }
}

write-progress -Activity ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$elem.PSN+" ("+$elem.Nachname+", "+$elem.Vorname+")") -Status "Finished" -Completed

## Iterate through all employees that should have been removed, as they are no longer employed, to process those with Vertragsenden not empty
$count=0
$thosewhoshallnotremain=[System.Collections.ArrayList]::new()
$toprocess=($employees | ?{!$_.StillEmployed})

foreach ($e in $toprocess){  
    $count+=1
    $perc=100/$cont.Count*$count
    write-progress -Activity "Looking up AD-Accounts" -Status ("Processing "+$count+"/"+$cont.Count+" ("+$perc+"%): "+$e.PSN+" ("+$e.Nachname+", "+$e.Vorname+")") -PercentComplete $perc
    
    <# 
    get the userobject of the current employe and make sure not to hit an already moved/deactivated account
    note: As I recall, you can't use DistinguishedName in a filter or LDAP filter, because it's a constructed attribute (or something along those lines).  To filter on distinguishedName, you have to use Where-Object.
    https://social.technet.microsoft.com/Forums/ie/en-US/1af6a749-2628-494c-afde-b67a5b9b77f2/getaduser-filter-distinguishedname-notlike-does-not-work
    #>
    $filter="sn -eq `""+$e.Nachname+"`" -and givenName -eq `"" + $e.Vorname+"`""
    
    $a=get-aduser -filter $filter -Properties DistinguishedName,description,sn,givenName,samaccountname,SID,Enabled,LastLogonTimestamp,whencreated,pwdlastset,"msDS-UserPasswordExpiryTimeComputed" | Where-Object {$_.DistinguishedName -notlike "*"+$usermoveto}   
    if ($null -ne $a){
        if ($a -is [array]){ # If the AD-Query returned more than one result!
            $lf=($inputfilepath.TrimEnd('\')+"\double_accounts_"+$e.Vorname+"_"+$e.Nachname+".csv")
            Write-Warning ("Skipping this one as i found more than 1 account for: "+ $e.Vorname+", "+$e.Nachname+ " - Please check this manually! This information will be dumped to: `""+$lf+"`"")
            $a | Format-Table -AutoSize
            $a | select-object -Property * | export-csv -NoTypeInformation -Path $lf -Encoding UTF8 -Delimiter ";"
            continue # skip this one
        }

        # We just found an account of a user, that is no longer part of this company.
        $e | Add-Member -Force -MemberType NoteProperty -Name "LastLogonTimestampDate" -Value $(
            if ($null -eq $a.LastlogonTimestamp -or $a.LastlogonTimestamp -le 0 ){
                "Never" # never logged in
            }
            else {
                [datetime]::FromFileTime($a.LastlogonTimestamp).tostring('dd.MM.yyyy')
            }
            )

        $e | Add-Member -Force -MemberType NoteProperty -Name "AccountExpiresDate" -Value $(
            if ($null -eq $a."msDS-UserPasswordExpiryTimeComputed" -or $a."msDS-UserPasswordExpiryTimeComputed" -le 0 -or $a."msDS-UserPasswordExpiryTimeComputed" -eq 0x7FFFFFFFFFFFFFFF){ #https://learn.microsoft.com/en-us/windows/win32/adschema/a-accountexpires
                "Never" # never expiring
            }
            else {                
                [datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed").toString('dd.MM.yyyy')
            }
            )
        
        $e | Add-Member -Force -MemberType NoteProperty -Name "PwdLastSetDate" -Value $(
            if ($null -eq $a.pwdlastset -or $a.pwdlastset -le 0 ){
                "Never" # never expiring
            }
            else {
                [datetime]::FromFileTime($a.pwdlastset).tostring('dd.MM.yyyy')
            }
            )

        $e | Add-Member -force -MemberType NoteProperty -name SamAccountName -value $a.SamAccountName
        $e | Add-Member -force -MemberType NoteProperty -name SID -value $a.SID
        $e | Add-Member -force -MemberType NoteProperty -name distinguishedname -value $a.distinguishedname
        $e | Add-Member -force -MemberType NoteProperty -name Description -value $a.Description  
        
        if (!$disable){
            Write-Warning ("Would disable: " + $e)
        }
        else {
            Write-Host ("Disabling: "+ $e)
            disableuserobject -user $e -moveto $usermoveto
        }
        $null=$thosewhoshallnotremain.add($e)
    }    
}
write-progress -Activity "Looking up AD-Accounts" -Status "Finished" -Completed

if ($thosewhoshallnotremain.count -ge 1){
    $ef=($inputfilepath.TrimEnd('\')+"\users_that_should_longer_exist.csv")
    Write-Host ("Results will be exported to: `""+$ef+"`"")
    $thosewhoshallnotremain | select-object -Property * | export-csv -NoTypeInformation -Path $ef -Encoding UTF8 -Delimiter ";"
}
else {
    Write-Host("Looks like there is nothing to remove.")
}

exit 0