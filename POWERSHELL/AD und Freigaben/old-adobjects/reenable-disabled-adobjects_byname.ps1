<#
Searches disabled AD-objects, that are member of a specific group and reverts the changes done by "disable-old-adobjects.ps1".

D. Maienhöfer, 2022/06
#>

param(
    [string[]]$names= @(), # names of objects
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
        Write-Host("Would restore " + $computer.distinguishedname + " - "+$computer.name+" => " + $orgdescription + " => moving to: " + $movetoou)
    }
}

# Main

if ($null -eq $names -or $names.Count -eq 0){
    Write-Warning "Please specify at least one samaccountname with -names. Aborting."
    exit(1)
}

$filter="samaccountname -eq "
foreach ($name in $names){
    $filter=$filter + "'"+ $name + "' -or samaccountname -eq "
}
$filter=$filter.Substring(0, $filter.LastIndexOf("'")+1) # remove trailing "-or samaccountname -eq"

if (!$nousers){
    Write-Host "Searching objects..."
    $users = (Get-ADUser -Filter $filter -Searchbase $searchbase -Properties name,samaccountname,enabled,samaccountname,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $false -and $_.samaccountname -notlike '*$'} | Select-Object -Property name,samaccountname,enabled,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    $count=0    
    foreach ($u in $users){
        $count+=1
        $percentage = 100 / $users.count * $count
        Write-Progress -PercentComplete $percentage -Activity ("Checking user " + $count + " of " + $users.Count)
        restoreuser -user $u      
    }
}
else {
    Write-Host ("-nousers is set: skipping userobjects")
}


if (!$nocomputers){
    $computers = (Get-ADComputer -SearchBase $searchbase -Filter $filter -Properties name,enabled,operatingsystem,operatingsystemversion,whencreated,lastlogontimestamp,distinguishedname,description | Where-Object {$_.enabled -eq $false -and $_.operatingsystem -like "*Windows*" -and $_.operatingsystem -notlike "*Server*"} | Select-Object -Property name,enabled,operatingsystem,operatingsystemversion,whencreated,@{Name='LastLogonTimeStamp';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}},distinguishedname,description)
    $count=0   
    foreach ($c in $computers){
        $count+=1
        $percentage = 100 / $computers.count * $count
        Write-Progress -PercentComplete $percentage -Activity ("Checking user " + $count + " of " + $computers.Count)        
        restorecomputer -computer $c        
    }
}
else {
    Write-Host ("-nocomputers is set: skipping computerobjects")
}
exit(0)
# SIG # Begin signature block
# MIIMSAYJKoZIhvcNAQcCoIIMOTCCDDUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULYkRuopE4YiZHveyRD6CIaAQ
# jUmgggnoMIID4DCCA2agAwIBAgICEAEwCgYIKoZIzj0EAwMwgZwxCzAJBgNVBAYT
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQU9HiFsBVpLc+5V98UBBjuzezqpyIwDQYJKoZI
# hvcNAQEBBQAEggEAqdQwwHnt97qcCZ7R1uqk563qgDE7/tB910rnR52686Cgmwk2
# YhIn/qer61xc2OjafFuM67k5tZeMcfnIYm0+c6vqOf1B0Mo4CuwFbcKhfil96a+N
# q5b3V7D1EXnZSyEL2ph4cq4AvXSsWWxfYVvQz/qlsEEHm8Hr0TGewvaNzxcoiqPX
# AJQ0jjwnN6AbTsMFhfTh+LXosYb1I+deOhMRVyUT4W5ddwZBye/te1QsFjADNfbu
# v2+WvK/6koorkc90XWvh7ieypPNyYbTzCjL1Q9DRPtZ3yQkPG0NkrOJk6toepVMg
# 2NBOeTVVv0PNc1WocAgQlOBFm2FXHXJ150GfOA==
# SIG # End signature block
