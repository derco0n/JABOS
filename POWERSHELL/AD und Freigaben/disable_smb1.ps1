<#
This will disable (or reenable) SMBv1, as it a very old and very very unsecure protocol, which isn't needed anymore since Windows Vista.
This should be run on shutdown.
D. Maienhöfer, 2022/10
#>
param(
    [Switch]$reeanblesmb1=$false,
    [String]$logfile="C:\temp\Smb-settings.log"
)

function log([String]$message, [String]$file, [int]$type=0){    
    <#Types:
    0=Info
    1=Warning
    >1=Error
    #>
    $path=Split-Path -Path $file
    if (!(Test-Path -Path $path)){
        New-Item -ItemType Directory -Path $path -Force
    }     
    $typemsg="(INFO) "
    if ($type -eq 1){
        $typemsg="(WARNING) "
    }
    elseif ($type -gt 1){
        $typemsg="(ERROR) "
    }
    $scriptName = $MyInvocation.ScriptName.Replace((Split-Path $MyInvocation.ScriptName),'').TrimStart('').TrimStart('\')
    $message=(Get-Date -Format G)+" ("+$scriptname+"): "+$typemsg+$message
    try {
        if ($type -lt 1){
            Write-Host $message
        }
        elseif ($type -eq 1) {
            Write-Warning $message
        }
        elseif ($type -gt 1) {
            Write-Error $message
        }        
        $message | Out-File -Encoding utf8 -FilePath $file -Append
    }
    catch {
        Write-Error "Unable to make a log entry."
    }
}

# Assure that the logfile isn't greater that 5 MBs
try {
    $lf=Get-Item -Path $logfile
    if ($logfile.EndsWith(".txt") -or $logfile.EndsWith(".log")){
        $logsize= $lf.Length/1MB
        if($logsize -gt 5){
            remove-item $logfile
        }
    }
    
}
catch {

}

$exitcode=0

$services=@("LanmanWorkstation", "LanmanServer")

log "Starting SMB-Config" $logfile 0

# Stop Services
foreach ($service in $services){
    log ("Stopping service: " + $service) $logfile 0
    Stop-Service $service -Force
}

if ($reeanblesmb1){
    try {
    log "Setting Registry-Values to enable SMBv1" $logfile 0

     # Enable SMB1-Server
     log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 1 -PropertyType DWORD -Force) $logfile 0
     log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB2" -Value 0 -PropertyType DWORD -Force) $logfile 0
 
     # Enable Start of SMB1-Clientservice
     log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10" -Name "Start" -Value 1 -PropertyType DWORD -Force) $logfile 0
 
     # Fix dependencies of SMB-Clientservice
     log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation" -Name "DependOnService" -Value "Bowser","MRxSmb20","mrxsmb10","NSI" -PropertyType Multistring -Force) $logfile 0
 }
 catch {
     log $_ $logfile 1
     $exitcode=2
 }    

}
else {
    try {
        log "Setting Registry-Values to disable SMBv1"  $logfile 0

        # Disable SMB1-Server        
        log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -PropertyType DWORD -Force) $logfile 0
        log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB2" -Value 1 -PropertyType DWORD -Force) $logfile 0
    
        # Disable Start of SMB1-Clientservice
        log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10" -Name "Start" -Value 4 -PropertyType DWORD -Force) $logfile 0
    
        # Fix dependencies of SMB-Clientservice
        log (New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation" -Name "DependOnService" -Value "Bowser","MRxSmb20","NSI" -PropertyType Multistring -Force) $logfile 0

    }
    catch {
        log $_  $logfile 1
        $exitcode=1
    }    
}

# Start Services
foreach ($service in $services){
    log ("Starting service: " + $service)  $logfile 0
    try {
        Start-Service $service
    }
    catch {
        log $_  $logfile 1
    }
}

try {
    # Enable or Disable SMB1Protocol according to setting (True or False)
    log ("Trying to set the enablement-status for SMBv1 to: "+ $reeanblesmb1) $logfile 0
    Set-SmbServerConfiguration -EnableSMB1Protocol $reeanblesmb1 -force
}
catch {
    log ($_.ToString() + "`r`nNote: if trying to enable SMBv1 on Systems that doesn't have SMBv1 installed, a 'service unavailable'-error ist normal." ) $logfile 1
}

# Assure that SMB2-Protcol is enabled at any time
Set-SmbServerConfiguration -EnableSMB2Protocol $true -force

log ("Done. Exitcode is: " + $exitcode) $logfile 0
exit $exitcode
# SIG # Begin signature block
# MIIMSAYJKoZIhvcNAQcCoIIMOTCCDDUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjAujzIHIAksopZZHWBRcLvFM
# 582gggnoMIID4DCCA2agAwIBAgICEAEwCgYIKoZIzj0EAwMwgZwxCzAJBgNVBAYT
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUVaUbYIwcU5wbZQX68xtTGMzRSzQwDQYJKoZI
# hvcNAQEBBQAEggEAO2vT25evl6bj+YWnmzOs4yQFNyXqTS68Bju+OnnxZuvp7FKZ
# fs/m5BAR+iDlkoiDnipjWTnai4P1MiYV/QBLk9pAZAsRHj6823AUnpueDZOBG6RY
# K86SlpF6EGuRCIktO/EXnKTYb7SnAIoX5mAEfzz3AU06TyZ3Xt69wagx/Df6C2Fx
# RLIdw+v1uMx8erL7dL1KFL4l2k+OkwSJpllHTZ8ZRk3CxUQuDeWnc68OoUWC8jav
# 7mf7SJnuPQJpiLDo0iNKiqNtVcUyOP8rU7zJrHf33gbuCtiyhshq2NgQSq/X9gZt
# iZ7klHhzhNR8rqAhn4CLQkiftdKijUnF/gK4PQ==
# SIG # End signature block
