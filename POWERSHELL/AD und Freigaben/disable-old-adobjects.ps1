<#
Searches AD-object that had long been inactive (LastLogonTimeStamp) and those where the account is expired.
All object will be disabled if they are still enabled and then moved to another OU.
A comment will be added to each object noting why it had been deactivated and from which OU it originated.

D. Maienhöfer, 2022/06
#>

param(
    [int]$maxdays=180, # maximum age (lastlogontimestamp)
    [int]$maxcreateddays=60, # (whencreated) minimum account age needed, to disable accounts with no logon. prevent disabling new accounts
    [switch]$nousers=$false,  # don't look for user-objects
    [switch]$nocomputers=$false, # don't look for user-objects
    [switch]$includeservers=$false, # also process server-objects
    [switch]$dryrun=$false, # don't change objects, just simulate
    [string]$usermoveto="OU=Benutzer,OU=Alt_Inaktiv,DC=eine,DC=firma,DC=local", # to where should the user objects been moved to
    [string]$computermoveto="OU=Computer,OU=Alt_Inaktiv,DC=eine,DC=firma,DC=local" # to where should the computer objects been moved to
)

function disableuserobject($user, $moveto, $dryrun){
    $lastlogontext="Created/Lastlogon: `"" + $user.whencreated.ToString("dd.MM.yyyy HH:mm:ss")+"`" / "
    if ($user.LastlogonTimestamp.Year -eq 1601){
        $lastlogontext+="`"Never.`""
    }
    else {
        $lastlogontext+="`""+$user.LastLogonTimeStamp.ToString("dd.MM.yyyy HH:mm:ss")+"`""
    }
    $user.description="Disabled administratively on "+$Today.ToString()+" due to long inactivity ("+$lastlogontext+"). Originating LDAP-Path: `""+$user.distinguishedname+"`" Original description: `"" + $user.description + "`""       
    if (!$dryrun){
        Write-Warning("Disabling " + $user.distinguishedname + " - "+$user.name+" (Created: "+$user.whencreated+", "+$lastlogontext)
        Set-ADUser -Identity $user.distinguishedname -Description $user.description # Update description
        Disable-ADAccount -Identity $user.distinguishedname # Disable Account
        Move-ADObject -Identity $user.distinguishedname -TargetPath $moveto # Move Account to different OU
    }
    else {
        Write-Host("Would disable " + $user.distinguishedname + " - "+$user.name+" ("+$lastlogontext+")")
    }
}

function disablecompobject($computer, $moveto, $dryrun){
    $lastlogontext="Created/Lastlogon: `"" + $computer.whencreated.ToString("dd.MM.yyyy HH:mm:ss")+"`" / "
    if ($computer.LastlogonTimestamp.Year -eq 1601){
        $lastlogontext+="`"Never.`""
    }
    else {
        $lastlogontext+="`""+$computer.LastLogonTimeStamp.ToString("dd.MM.yyyy HH:mm:ss")+"`""
    }
    $computer.description="Disabled administratively on "+$Today.ToString()+" due to long inactivity ("+$lastlogontext+"). Originating LDAP-Path: `""+$computer.distinguishedname+"`" Original description: `"" + $computer.description + "`""    
    
    if (!$dryrun){
        Write-Warning("Disabling " + $computer.distinguishedname + " - "+$computer.name+" (Created: "+$computer.whencreated+", "+$lastlogontext)
        Set-ADComputer -Identity $computer.distinguishedname -Description $computer.description # Update description
        Disable-ADAccount -Identity $computer.distinguishedname # Disable Account
        Move-ADObject -Identity $computer.distinguishedname -TargetPath $moveto # Move Account to different OU        
    }
    else {
        Write-Host("Would disable " + $computer.distinguishedname + " - "+$computer.name+" ("+$lastlogontext+")")
    }
}

if ($maxcreateddays -le 20){
    Write-Warning("-maxcreateddays has been set to " + $maxcreateddays.ToString() + ". Note that it takes at least 19 (14+5) days to replicate after domain functional level raise.`r`nWill set Value to 20...")
    $maxcreateddays=20
}

$Today=(GET-DATE)

$ctoremove=[System.Collections.ArrayList]::new();
$utoremove=[System.Collections.ArrayList]::new();

if (!$nousers){
    # Need to lookup users
    $users=(Get-ADUser -Filter * -Properties name,enabled,samaccountname,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $true -and $_.samaccountname -notlike '*$'} | Select-Object -Property name,enabled,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)    
    foreach($u in $users){          
        $createdbefore=[math]::round((new-timespan -Start $u.whencreated -End $Today).TotalDays,0)
        $lastlogonbefore=-1        
        if ($null -ne $u.LastlogonTimestamp -and $u.LastlogonTimestamp.Year -ne 1601 ){            
            $lastlogonbefore=[math]::round((new-timespan -Start $u.LastlogonTimestamp -End $Today).TotalDays,0)
        }

        <# 
        LastLogonTimestamp will be replicated to the DC's in AD. However The initial update after the raise of the domain functional level is calculated as 14 days minus random percentage of 5 days.
        https://docs.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp
        #>

        if ($createdbefore -gt 20){                        
            if ($lastlogonbefore -eq -1){                
                if ($createdbefore -gt $maxcreateddays){
                    # Make sure to not disable any new account, which LastLogonTimestamp had not been replicated yet.
                    #Write-host -ForegroundColor Red ($u.name + " has been setup before " + $createdbefore + " days - No logon has been recorded.")
                    $null=$utoremove.Add($u)
                }
                else {                    
                    #Write-host -ForegroundColor Yellow ($u.name + " has been setup before " + $createdbefore + " days - No logon has been recorded yet, but the object is not that old.")
                }
            }
            <#else {
                Write-host ($c.name + " has been setup before " + $installedbefore + " days - it's LastLogon was before "+$lastlogonbefore+" days.")                
            }
            #>
            if ($lastlogonbefore -gt $maxdays){
                #Write-host -ForegroundColor Red ($u.name + " has been setup before " + $createdbefore + " days - It's LastLogon was before "+$lastlogonbefore+" days.")
                $null=$utoremove.Add($u)  
            }            
        }
    }
    Write-Host("From a total of "+$users.Count.ToString()+" users "+$utoremove.Count.ToString()+" should be disabled.")
    $utoremove | Export-Csv -NoTypeInformation -Path "c:\temp\oldusers.csv" -Encoding UTF8 -Delimiter ';'
}
else {
    Write-Host ("-nousers is set: skipping userobjects")
}

if (!$nocomputers){
    # Need to lookup computers
    if ($includeservers){
        $computers=(Get-ADComputer -Filter * -Properties name,enabled,operatingsystem,operatingsystemversion,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $true -and $_.operatingsystem -like "*Windows*"} | Select-Object -Property name,enabled,operatingsystem,operatingsystemversion,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    }
    else {
        $computers=(Get-ADComputer -Filter * -Properties name,enabled,operatingsystem,operatingsystemversion,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $true -and $_.operatingsystem -like "*Windows*" -and $_.operatingsystem -notlike "*Server*"} | Select-Object -Property name,enabled,operatingsystem,operatingsystemversion,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    }   
    
    
    foreach($c in $computers){    
        
        $installedbefore=[math]::round((new-timespan -Start $c.whencreated -End $Today).TotalDays,0)

        $lastlogonbefore=-1
        
        if ($null -ne $c.LastlogonTimestamp -and $c.LastlogonTimestamp.Year -ne 1601 ){            
            $lastlogonbefore=[math]::round((new-timespan -Start $c.LastlogonTimestamp -End $Today).TotalDays,0)
        }

        <# 
        LastLogonTimestamp will be replicated to the DC's in AD. However The initial update after the raise of the domain functional level is calculated as 14 days minus random percentage of 5 days.
        https://docs.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp
        #>

        if ($installedbefore -gt 20){                       
            if ($lastlogonbefore -eq -1){                
                if ($installedbefore -gt $maxcreateddays){
                    # Make sure to not disable any new account, which LastLogonTimestamp had not been replicated yet.
                    #Write-host -ForegroundColor Red ($c.name + " has been setup before " + $createdbefore + " days - No logon has been recorded.")
                    $null=$ctoremove.Add($c)
                }
                else {                    
                    #Write-host -ForegroundColor Yellow ($c.name + " has been setup before " + $createdbefore + " days - No logon has been recorded yet, but the object is not that old.")
                }                
            }
            <#
            else {
                Write-host ($c.name + " has been setup before " + $installedbefore + " days - it's LastLogon was before "+$lastlogonbefore+" days.")                
            }
            #>
            if ($lastlogonbefore -gt $maxdays){
                #Write-host -ForegroundColor Red ($c.name + " has been setup before " + $installedbefore + " days - It's LastLogon was before "+$lastlogonbefore+" days.")
                $null=$ctoremove.Add($c)  
            }            
        }
    }
    Write-Host("From a total of "+$computers.Count.ToString()+" computers "+$ctoremove.Count.ToString()+" should be disabled.")
    $ctoremove | Export-Csv -NoTypeInformation -Path "c:\temp\oldcomputers.csv" -Encoding UTF8 -Delimiter ';'
}
else {
    Write-Host ("-nocomputers is set: skipping computerobjects")
}

 # Process all user objects that should be disabled
 foreach ($u in $utoremove){
    disableuserobject -user $u -moveto $usermoveto $dryrun
}

# Process all computer objects that should be disabled
foreach ($c in $ctoremove){
    disablecompobject -computer $c -moveto $computermoveto $dryrun
}


exit(0)
