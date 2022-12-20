<#
Enumerates Clients with Windows-Featureupgrades enabled.
D. Maienhöfer, 2022/06
#>

param (
    $group="site-Computer_Windows-Featureupdates_per_WSUS_aktiviert",
    #$os="Windows 10*",
    $os="*",
    $latestversion="19044"
)

[uint64]$total=0
[hashtable]$versioncounters = @{} # will contain the versions and their counters
$computers=Get-ADGroupMember $group

foreach($c in $computers){
    $detail=(Get-ADComputer $c -Properties name,operatingsystem,operatingsystemversion,lastlogontimestamp | Where-Object {$_.enabled -eq $true -and $_.operatingsystem -like $os} | Select-Object -Property name,operatingsystem,operatingsystemversion,@{Name='LastLogon';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}})
    if ($null -ne $detail){    
        [string]$v=$detail.operatingsystemversion
        if ($versioncounters.ContainsKey($v)){
            $versioncounters[$v]=$versioncounters[$v]+1
        }
        else {
            $versioncounters+=@{$v=1}
        }
        $total+=1
    if ($v.Contains($latestversion)){
        # this is the newest version
        Write-Host -ForegroundColor Green ($detail.name + " ("+$detail.operatingsystem + " "+$detail.operatingsystemversion+") - "+$detail.LastLogon)        
    }
    else {
        $TimeSpan = New-TimeSpan -start $detail.LastLogon -End (Get-Date)
        if ($Timespan.TotalDays -le 60){
            Write-Host -ForegroundColor Yellow ($detail.name + " ("+$detail.operatingsystem + " "+$detail.operatingsystemversion+") - "+$detail.LastLogon)        
        }
        else {
            Write-Host -ForegroundColor Red ($detail.name + " ("+$detail.operatingsystem + " "+$detail.operatingsystemversion+") - "+$detail.LastLogon)        
        }
    }
    
    }
}

Write-Host "`r`nVersions by Count"
$versioncounters | Format-Table

Write-Host ("Total: " + $total)
# SIG # Begin signature block
# MIIMSAYJKoZIhvcNAQcCoIIMOTCCDDUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwmCU8W6BwwefNWXiS1OnnhEB
# WP+gggnoMIID4DCCA2agAwIBAgICEAEwCgYIKoZIzj0EAwMwgZwxCzAJBgNVBAYT
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQU30l7IixZxLkEuUhdMfJILe1TY2YwDQYJKoZI
# hvcNAQEBBQAEggEAk2+af5sSc9AKE88X909lYiuBSlJlWwBzfWVkxlolQuOwE2np
# tQjgUSCrjm4saOzXVEZG+XUeyFEy+zGnqZTuYMKcwkASFVmNTEr/Dff0osd8kxhG
# IcxdbeSabwJJ4oKWQhkST7CKG/EuDeVKo7jivAx1/QNKgcQRn4V9DST03xa25cyj
# Rv++7oisyn4fmvfVOKyaBGFeVD75+0F8bBWwYjYSCseabjNRDy9VoWUYsb0AgRfe
# r2yZMgP/54IizHazWOR+etonMFEdqRFllcL4b9LFzqOl+xyo/wULI/AB4niBib+6
# temqs0Xj3nQE+ZV9+f0nCBK4ztkRWaPfwN9Vwg==
# SIG # End signature block
