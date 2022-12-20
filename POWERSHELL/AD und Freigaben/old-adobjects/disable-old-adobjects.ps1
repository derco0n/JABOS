<#
Searches AD-object that had long been inactive (LastLogonTimeStamp) and those where the account is expired.
All objects will be disabled if they are still enabled and then moved to another OU.
A comment will be added to each object noting why it had been deactivated and from which OU it originated.

D. Maienhöfer, 2022/06
#>

param(
    [int]$maxdays=180, # maximum age (lastlogontimestamp)
    [int]$maxcreateddays=60, # (whencreated) minimum account age needed, to disable accounts with no logon. prevent disabling new accounts
    [switch]$nousers=$false,  # don't look for user-objects
    [switch]$nocomputers=$false, # don't look for computer-objects
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

# SIG # Begin signature block
# MIIMSAYJKoZIhvcNAQcCoIIMOTCCDDUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwUgQ8YFOW+IWnhoV5Yq+FnZH
# ZKGgggnoMIID4DCCA2agAwIBAgICEAEwCgYIKoZIzj0EAwMwgZwxCzAJBgNVBAYT
# AkRFMQwwCgYDVQQIDANOUlcxEDAOBgNVBAcMB0RldG1vbGQxHDAaBgNVBAoME0ts
# aW5pa3VtIExpcHBlIEdtYkgxCzAJBgNVBAsMAklUMRIwEAYDVQQDDAlLTEdST09U
# Q0ExLjAsBgkqhkiG9w0BCQEWH2l0LXNpY2hlcmhlaXRAa2xpbmlrdW0tbGlwcGUu
# ZGUwHhcNMjIwNjIxMDkxNDQxWhcNMzIwNDI5MDkxNDQxWjASMRAwDgYDVQQDEwdT
# VUJDQTAxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyNK313/s36Nq
# xX8Q6WQhHlrMiS0j1M/ZCjqTcKkS6fh1tVrL29qiGbSC86oCh1hvn185sWf386N8
# Jc4RTlvYDjtvMyoIS+mjBUJaKTcD+k93h3Gue+IS3nOswM4nH1CLyIzDbBXGlkv3
# bDeYKh0UZUD8rO3vXSu/2vik7NaUD75wC+msH92XnmkyzgAe3d3T4T9jxfJrDjXa
# ILSMBqA+qgstR4w2jnVyL95ABurgxuP2OHN8GOq6oaXXTt8OKIsEclqsBmEQilh+
# pLkY7ucDz24d/K2rTK0yLv0r1nWDZcoEOp127A7e7Y2GjOdNchbhAIrNsu7NjhI0
# iAtZ0etJ2QIDAQABo4IBVDCCAVAwHQYDVR0OBBYEFE324n38zJ7eb4FTuqbdGLAZ
# gINgMB8GA1UdIwQYMBaAFAa5rvju/tkF/RkhBtJLnHPUZjGPMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6
# Ly9rbGdyb290Y3JsLmtsaW5pa3VtLmxpcHBlLmludHJhL0tMRy9LTEdST09UQ0Eu
# Q1JMMIGeBggrBgEFBQcBAQSBkTCBjjBTBggrBgEFBQcwAoZHaHR0cDovL2tsZ3Jv
# b3Rjcmwua2xpbmlrdW0ubGlwcGUuaW50cmEvS0xHL2tsaW5pa3VtLmxpcHBlLmlu
# dHJhLmNydC5wZW0wNwYIKwYBBQUHMAGGK2h0dHA6Ly9rbGdyb290Y3JsLmtsaW5p
# a3VtLmxpcHBlLmludHJhL0tMRy8wCgYIKoZIzj0EAwMDaAAwZQIxANTjc6Pduoyg
# R/12JF18i5wLqJQSVa4A3tsG7IUDfCm3aW2uY1OxDnCEbNDoSHCnvwIwY691E+ti
# BKwJIATHDZ4d6odgZFblv2nM73o4uaW/pAz13M4JcEIf6hbp6Cd6CNGiMIIGADCC
# BOigAwIBAgITEQAAAEWpIjI+Z6DowwAAAAAARTANBgkqhkiG9w0BAQwFADASMRAw
# DgYDVQQDEwdTVUJDQTAxMB4XDTIyMDYyNDA5MDc1MVoXDTIzMDYyNDA5MDc1MVow
# gZAxFTATBgoJkiaJk/IsZAEZFgVpbnRyYTEVMBMGCgmSJomT8ixkARkWBWxpcHBl
# MRgwFgYKCZImiZPyLGQBGRYIa2xpbmlrdW0xEjAQBgNVBAsTCVN5c0FkbWluczEN
# MAsGA1UECxMEVXNlcjEjMCEGA1UEAwwaTWFpZW5ow7ZmZXIsIERlbm5pcyAobWQw
# MCkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDcIVeiRgTIS+2jxGvD
# D1svvLSzazJ/piXKbHx8mioUQacWuAhlaitznKCBz5hUKT0upx8jDpvB4Woc423o
# 0GowB2YsrCzZhZFt9R2Sk6uHNwk0hYYNCnoQXIF1XN92dpnMOLqFE4b81t5Ba8ul
# bgeT1PlODLhfuChA/NNsGGlQfAmYSvXUW91ppsrvguVepkJS38A1AaXSuGZPqOtR
# oAlzM4XATQxq/DEtY/O5DIu7k+XBjJNJk9Fmzbn8YwCXj+HVHF4DhFDaLdTgo/q9
# nUkwUbhU6XnGGoIm5XU5tUtgSSWEG+NwL/djxHLSkaFQ7wQ3Lanh0isxzl+jFsGw
# peoZAgMBAAGjggLOMIICyjA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiF6sVX
# gYCmJYXZkyCH7fBwkpg1gQqG3I9lgaTebwIBZAIBBzATBgNVHSUEDDAKBggrBgEF
# BQcDAzAOBgNVHQ8BAf8EBAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcD
# AzAdBgNVHQ4EFgQU6cHREMNgiX6WWGOiGiDlq/tzuW4wHwYDVR0jBBgwFoAUTfbi
# ffzMnt5vgVO6pt0YsBmAg2AwgcUGA1UdHwSBvTCBujCBt6CBtKCBsYaBrmxkYXA6
# Ly8vQ049U1VCQ0EwMSxDTj1zdWJjYTAxLENOPUNEUCxDTj1QdWJsaWMlMjBLZXkl
# MjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWxpcHBl
# LERDPWludHJhP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RD
# bGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDCBuQYIKwYBBQUHAQEEgawwgakwgaYG
# CCsGAQUFBzAChoGZbGRhcDovLy9DTj1TVUJDQTAxLENOPUFJQSxDTj1QdWJsaWMl
# MjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERD
# PWxpcHBlLERDPWludHJhP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1j
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5MDQGA1UdEQQtMCugKQYKKwYBBAGCNxQCA6Ab
# DBltZDAwQGtsaW5pa3VtLmxpcHBlLmludHJhME0GCSsGAQQBgjcZAgRAMD6gPAYK
# KwYBBAGCNxkCAaAuBCxTLTEtNS0yMS0xMzg5NTE5ODA1LTYxNDI3MDU4LTMxMjU1
# MjExOC0yMjUwMzANBgkqhkiG9w0BAQwFAAOCAQEASfbh/obOIaDLWEtacOE2c+VC
# szWlAqptGbHkZRqnvn4SUCN7U3Gv2c7jjjVcTWpphBeND5msNRfZvVfxe+NzmB3g
# lxlAeWcYzECEHGuCjE0inQybzWNqT60FWXGE9LgAHsEKy9sdr0WP+Ufw4TSzjcEG
# Wf5vUIGwp2zmEpznWdDcbPoAOngi3kXC/U0i+TG5xV1DQj9PKw4WbfM05RngHoKI
# yWTT4s4QSX/r5XRBwHM/JdGvguKD+vtpcr4ZRr4OFPwv/PX0Csfj6A77G0gzIre9
# mOe/F6xik5NUp/9pmj+HCcAgMMIfu4CV65Bv1zURJ/ntmXY0E4DQCl3OyQN0iDGC
# AcowggHGAgEBMCkwEjEQMA4GA1UEAxMHU1VCQ0EwMQITEQAAAEWpIjI+Z6DowwAA
# AAAARTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUMgdFJuUk0U0DBmMRiUO+qZtbsTEwDQYJKoZI
# hvcNAQEBBQAEggEAGzIy5uqHyKznbqmxU7nUO97cL0BMj9R5o2TFnmJ/Sha07VPY
# 5et+ZOJmMd823DszD5njZZgiAwgDvL2E75epMBAGUtVBc9yR5PxFbVVF/3OHc6Nd
# n/Lfo/XDzpZNV4MmmEGWtZ62+Fw+S4CIRayvuUW8nG11lKy7kYiTjuxLxJaSVppo
# tUgXH23RXy+LgILmmbABCw9K/Zca1mnwncsNH/Vsn2NlA7T5Rf3Wu1+6y87gJ8gi
# 0vrbHb6kqbgy/y0jVLpJhIUsp+2B8GbC0rCUOyJIac7gHeeIvZA8Rq4Ool0pGKG3
# 1F0FAubrBAXTGUhc2l+F1VtP59jXjKFBL7OVZg==
# SIG # End signature block
