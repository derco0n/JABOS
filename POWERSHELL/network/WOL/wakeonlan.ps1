<#
WakeOnLan
This script sends a magic-packet to a list of computers
Before and after sending, the target-system will be probed via ping

The format of a Wake-on-LAN (WOL) magic packet is defined as a byte array with 6 bytes of value 255 (0xFF) and 
16 repetitions of the target machine’s 48-bit (6-byte) MAC address.

If the MAC address was: 1A:2B:3C:4D:5E:6F

  [Byte[]] $ByteArray =
   0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F,
   0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F

© D. Maienhöfer, 2016-2022

#>

#Options:
##########
param (
    [string]$targetlist=$($PSScriptRoot+"\targetlist.csv"),
    [int]$timestosend=4, # how often should the magic-packet be sent to each target. This is UDP! Send multiple time to increase the chance it reaches the target.
    [switch]$notonweekend=$false, # if set to $true, no packet is sent on saturdays and sundays
    [int]$waitafterwaketime=180, # Time (in seconds) which should be waited for the target-systems to be pinged    
    [string]$global:eventlogName="site_WOL_Script",
    [switch]$dontwaitfortargets=$false
)

# Logging
[string]$global:logmessages=""

function goodbye([int]$returncode){ # This will write the loginfomessages to the eventlog and exits
    $Runtimenow=$global:StopWatch.Elapsed.TotalSeconds
    log ("Runtime was "+$Runtimenow+" seconds.") $eventlogName 10000 0

    $StopWatch.Stop()
    log ("All done. Exitcode=" + $returncode.tostring()) $eventlogName 10000 0
    write-eventlog -logname Application -source $global:eventlogName -eventID 10000 -message $global:logmessages -EntryType Information
    exit $returncode
}

function log([String]$message, [String]$eventlogName, [int]$msgid, [int]$type=0){    
    <#Types:
    0=Info
    1=Warning
    3=Error
    #>    
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
            $global:logmessages+=$message + "`r`n"            
        }
        elseif ($type -ge 1) {
            Write-Warning $message        
            if ($type -gt 1){
                write-eventlog -logname Application -source $eventlogName -eventID $msgid -message $message -EntryType Error
            }
            else {
                write-eventlog -logname Application -source $eventlogName -eventID $msgid -message $message -EntryType Warning
            }
        }
    }
    catch {
        Write-Error ("Unable to make a log entry. => " + $_)
    }
}


#Main:
######
$global:StopWatch=[System.Diagnostics.stopwatch]::startNew()
$global:StopWatch.Start()

try {
    new-eventlog -computername $env:computername.ToUpper() -source $eventlogName -logname Application -ErrorAction SilentlyContinue # Register new eventlog source, if it doesn't exist
}
catch {
    Write-Error ("Unable to register new eventlog-source! => " + $_)
    goodbye 1
}

log ("WOL-script (by D. Maienhöfer) started...") $eventlogName 10000 0

if (!(Test-Path $targetlist)){
    
    goodbye 2
}

try {
    $targetcomputers=Import-Csv $targetlist -Delimiter ';'
}
catch {
    log ("Unable to read inputfile `"" + $targetlist+ "`". => " + $_ + "  Aborting.") $eventlogName 20001 2
    goodbye 3
}

$DaOfWe=[Int] (Get-Date).DayOfWeek

log ("Weekday: " + $DaOfWe) $eventlogName 10000 0
log ("Don't run at weekend: " + $notonweekend) $eventlogName 10000 0

if ($DaOfWe -ge 1 -and $DaOfWe -le 5){
    $isWeekend=$false    
    log ("it's not a weekend right now") $eventlogName 10000 0	
    }
else {
    $isWeekend=$true
    log ("it's the weekend right now") $eventlogName 10000 0	
    }

if (($notonweekend -eq $false) -or ($notonweekend -eq $true -and  $isWeekend -eq $false)){    
    log ("conditions met") $eventlogName 10000 0	
    log ("detecting current target-status") $eventlogName 10000 0

    [System.Collections.ArrayList]$targetstostart=@()  # targets that need to be waked

    foreach($target in $targetcomputers){   
        if ((Test-Connection -ComputerName $target.Hostname -Quiet -Count 1)){
            log ($target.Hostname+" is online.") $eventlogName 10000 0	
        }
        else {
            log ($target.Hostname+" is offline and needs to be startet.") $eventlogName 10000 0	
            $targetstostart.Add($target)
        }
    }

    log ("Need to wake " + $targetstostart.Count.tostring()+ " target(s).") $eventlogName 10000 0	
    
    if ($targetstostart.Count -gt 0){ # at least one computer needs to be started
        # Send WOL
        log ("opening UDP socket") $eventlogName 10000 0	
        $UdpClient = New-Object System.Net.Sockets.UdpClient
        $UdpClient.Connect(([System.Net.IPAddress]::Broadcast),4000)
        
        foreach($target in $targetstostart){   
            $MacByteArray = $target.MAC -split "[:-]" | ForEach-Object { [Byte] "0x$_"} #Split the MAC-Address by colon or dash

            [Byte[]] $MagicPacket = (,0xFF * 6) + ($MacByteArray  * 16) # craft magicpacket
            #Verschicken
            [int] $i=1          
    
            log ("sending WOL to " + $target.Hostname) $eventlogName 10000 0	
            while($i -le $timestosend){
                $bytesSent=$UdpClient.Send($MagicPacket,$MagicPacket.Length) # send data
                log ("`tIteration " + $i.ToString() + " of " + $timestosend.ToString() + " sent ("+$bytesSent.ToString()+" Bytes).") $eventlogName 10000 0	            
                $i++}        
            }

        log ("closing UDP socket") $eventlogName 10000 0
        $UdpClient.Close()
        
        if ($dontwaitfortargets){
            log ("-dontwaitfortargets is set. Won't check if the come up.") $eventlogName 10000 0
            goodbye 0
        }
    
        #-dontwaitfortargets is not set. continue    
        log ("-dontwaitfortargets is not set. Waiting " + $waitafterwaketime + " seconds before rechecking the targets.") $eventlogName 10000 0
        Start-Sleep -s $waitafterwaketime # Wait for the targets to be pinged, giving them time to boot

        # Recheck computerstatus
        $failcounter=0
        foreach($target in $targetstostart){   
                if ((Test-Connection -ComputerName $target.Hostname -Quiet -Count 1)){
                    log ($target.Hostname + " is now online.") $eventlogName 10000 0	
                }
                else {
                    log ($target.Hostname + " is still offline after " + $waitafterwaketime + " seconds and couldn't be started.") $eventlogName 10000 0	
                    $failcounter+=1
                }
            }
            if ($failcounter -gt 0){
                log ($failcounter.ToString() + " of " + $targetstostart.Count + " couldn't be started.") $eventlogName 10000 0
            }
            else {
                
                log ("all targets started successfully.") $eventlogName 10000 0
            }
        }
        else {
            log ("all targets are already online.") $eventlogName 10000 0
        }
    }
else {
    log ("conditions not met") $eventlogName 10000 1
	}
goodbye 0

# SIG # Begin signature block
# MIITYwYJKoZIhvcNAQcCoIITVDCCE1ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPSVwuJThlavlrQVDUslZFgdd
# Rv2ggg/XMIIHeTCCBWGgAwIBAgIKGCSiEAAAAAAAAjANBgkqhkiG9w0BAQsFADAU
# MRIwEAYDVQQDEwlQT1JUQUwtQ0EwHhcNMTUxMTAzMDcxNDQxWhcNMjUxMDMwMDgy
# MjU4WjBHMRMwEQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9y
# dGFsMRgwFgYDVQQDEw9QT1JUQUxQS0ktU3ViQ0EwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCgICeRIo2o073jRxKD2z7YKixgeTQ2UCyI7BJUWdlcDqUF
# R1xWyEIEMdU49/VykdV0kZ3axtTsPEBGS+Ce6QVtHRt7QKoz6vn9UHsBLJmSG9XE
# VHLo2X7dGZSs71KYiPVP3LP+4/Zok2xR69N3IXsrGzsXIbBAtWE4Rk22kwyGzSVt
# 7s0ozfh26bvkX8SpjD4pyjEmoY24PNYg05US4gNDpwDjCZiqy/9OFgztmIzn6lng
# sK8ZYCbnPt6w8bCO7cuF+ffaPSCH7wijZRbCG2+FrkwyVwQIElpx4fpizkys+qG4
# rWGsyOf+8LlfJYzWGVIySKqYd1aEf+fCtS5jXy9MXb49eiXFtuSmtPbYGcMEIq9I
# SdrvbecUQxJjMngN8Y0EN1hmYngPBJh5RiK5RK+DN0gPUPfXYAviGbht91AEhk+O
# aacLkCtiX/oARBjiIH0d8MW5OC7TsOt3aJT48HXwJ9qkzoa37SFeX8tz0O3gjP3/
# AAntxvieWEeAL35NeUaKOgdEFwMS33LLefICxpyjd5KwV+PJc1TFNFwglLhiY4IX
# s12Sd9xlaDYMIkyaWaWmYDVluFk/i8lJ0I90aFTU0EzDFw2graqa1B8JoXnn31XE
# 1D+exvXKa7y1MWPYy3xUixoF1MYyV8qGEu0DGzWOLOaQbW7pGL5mfq09xq2kYwID
# AQABo4ICmDCCApQwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFHWW1PEdWYel
# TIyUQfasdpPFfrxPMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFO6zQpTRmjvL3g0mN9kQ
# G903+ql+MIH9BgNVHR8EgfUwgfIwge+ggeyggemGgbBsZGFwOi8vL0NOPVBPUlRB
# TC1DQSxDTj1wb3J0YWxjYSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1wb3J0YWwsREM9a2xn
# P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxE
# aXN0cmlidXRpb25Qb2ludIY0aHR0cDovL3BvcnRhbGNhLmtsaW5pa3VtLWxpcHBl
# LmRlL2NlcnQvUE9SVEFMLUNBLmNybDCCAQUGCCsGAQUFBwEBBIH4MIH1MIGnBggr
# BgEFBQcwAoaBmmxkYXA6Ly8vQ049UE9SVEFMLUNBLENOPUFJQSxDTj1QdWJsaWMl
# MjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERD
# PXBvcnRhbCxEQz1rbGc/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNl
# cnRpZmljYXRpb25BdXRob3JpdHkwSQYIKwYBBQUHMAKGPWh0dHA6Ly9wb3J0YWxj
# YS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L3BvcnRhbGNhX1BPUlRBTC1DQS5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAGG0fbbWhQxJwIXevUVL0DZZGXRIpPlwXQ6iy+yk
# CmyfOGJL2/HO45r7fRJBc2hOdEHDeZUPcLcPlCryburUb/wwV0ww66/EcHG06B3L
# seG5dUw3BB81edzJV9jEoOEYhPuHDUep2lWPmWF2yo40O8l600EeUKymg4gh2aKT
# F6DrpOahHeDaiZ50mjfFqJmmY3ed0nYSZcMF69dAQd24VVUmLnFeLhd2kwgL3Fei
# AImiSGNVoBJipuZy6LOWmu1mhPy31Yxbss8XYWcoRGf8WCB+2Uk1FJh16fw12vZk
# 70Nuj25AVBb9DoASsg3rvvsw0v4znPFRqFpQT6uBgo6kkAW0FlwVW/95I+2QkjkX
# nvwG+4Zl+qNyLicM4ydwLYZbnDka5xQp4HFqjUkCFde8gWogS4rGQpJFYlQ5Tj63
# 1G83vZFNyOrH1m9aJGudSGSBNzs6Djcr/h8sDe1TCJcXDRlhmDZxAogUB66oAgmL
# SP9/joRDo9EOMIbIbRra5Su3rn+72T3p6N2riedP+yiCfcSVg8fJLlsuO9zSsWHI
# 3qS/8W725GqN+TgFdSDtJRTQDnqwK9i9okRsRvyUvf8ZUlpYu4N7euytn1jecNfx
# Lbqn+/0MkXzrUksh04QKaD5voIbhVplucw6jPZi9BOtLtWIatGnbifshjg7qnBhq
# jb6XMIIIVjCCBj6gAwIBAgIKdox2awAAAAABAjANBgkqhkiG9w0BAQsFADBHMRMw
# EQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9ydGFsMRgwFgYD
# VQQDEw9QT1JUQUxQS0ktU3ViQ0EwHhcNMjEwNzI4MTE0MTU4WhcNMjMwNzI4MTE0
# MTU4WjBfMRMwEQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9y
# dGFsMRowGAYDVQQLExFDZXJ0aWZpY2F0ZU93bmVyczEUMBIGA1UEAxMLRGVubmlz
# IE1hcngwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCh5XFP9+zJtf+l
# GHEgT22YIWTH1+g3Go/Yel5gP7Hfvs0CsunHUilVBR+Ksdzn8/3/rhcBao0itKVb
# qoDptUzoWVGIqYnZsK1kEcdwbbo9BfDnwvYlXI39AaSfYMIh33dLyTg5lhHNRXN+
# xOJs5CnnuWKw4SkFcC8Bzn7LSClxZ8d9Xq8vVFaiAr/VXyhaqTdhj6Klutm+Idcq
# 3BDWxJ3eD8KiqyuHjDfmIZvQFcQvbgMyZ0PwXzwtnKsAdzxIcHVBSQ1fu+T91KhL
# MBxxHEmrkbmJCnhdAcAypzy6kEgep1pu+OmVMVnOGnkdFqyu62jhz7LJ5narfBAY
# AIkjRKO1ue+GbzkOy+SUpSkHWPxm/zJnRmmlwMN/GBJawVw+fZ2IRKraMgFWHFw2
# fPizduo3QvJGYBqooeJpG8OswqIqJJVKuo8ax1O1bC6swx7G9o/HFx3lCCLHTM9R
# XbVSK/nSv8K8OK5ZRkL8L8JwWicpxk32DdaQ4VdJXMSm/eKPjE3DJPYxhwkFRSDK
# /bEvH/IzyUOIJVBUO3TkaEgOcMLCi8l5+75oayoftpmIUMHov3RnmW3sittS7Ukq
# 9BGhjbAU7khOAc9lr/pOTNabEc+45tPFyLw0GvCO0rwWwsi9vNJOFLmr4CAdMMJ+
# ebeSnTp4HQ+koJ1nr1sCMk8yH7lJcQIDAQABo4IDKjCCAyYwDgYDVR0PAQH/BAQD
# AgeAMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIPX9naGsug5hfGDJIOW/xWx
# pzyBFoKdyCqDp5JsAgFkAgECMB0GA1UdDgQWBBSLAVwySO9uZJxstCzJMKL8jPpp
# 0DAfBgNVHSMEGDAWgBR1ltTxHVmHpUyMlEH2rHaTxX68TzCCAQsGA1UdHwSCAQIw
# gf8wgfyggfmggfaGgbdsZGFwOi8vL0NOPVBPUlRBTFBLSS1TdWJDQSxDTj1QT1JU
# QUxQS0ksQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
# Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9cG9ydGFsLERDPWtsZz9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnSGOmh0dHA6Ly9wb3J0YWxjYS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L1BP
# UlRBTFBLSS1TdWJDQS5jcmwwggEfBggrBgEFBQcBAQSCAREwggENMIGtBggrBgEF
# BQcwAoaBoGxkYXA6Ly8vQ049UE9SVEFMUEtJLVN1YkNBLENOPUFJQSxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPXBvcnRhbCxEQz1rbGc/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNz
# PWNlcnRpZmljYXRpb25BdXRob3JpdHkwWwYIKwYBBQUHMAKGT2h0dHA6Ly9wb3J0
# YWxjYS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L1BPUlRBTFBLSS5wb3J0YWwua2xn
# X1BPUlRBTFBLSS1TdWJDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYJKwYB
# BAGCNxUKBA4wDDAKBggrBgEFBQcDAzAxBgNVHREEKjAooCYGCisGAQQBgjcUAgOg
# GAwWZGVubmlzLm1hcnhAcG9ydGFsLmtsZzANBgkqhkiG9w0BAQsFAAOCAgEAiSVu
# 6t4iy5fEJLpXB+uU6SttnBS3+OyMdkHbnOXivlXqyPGSyWFf03wxCPxfBSrHRyiO
# RuklEB2f7SiYIJ21IEZqbfTRIyvJHBZWkx3DP6NOgDuu0YfZKOtiplELxn1435DS
# bn2mr4sHjaX4gjBofHcUTp1NmRoGl8diWUTJsoGwQRgUnoyvTfrJj6i9LDQgEonj
# uq0zNCsDYTsgVC7XsFbIIxF0/R6W7ol2xFtVmGP0Wx34DRNTuACk5HHeGy2kCYYq
# 0SDYHwhHna2IZ9PWyjlzBwY7o9TBpaHsfJeB7k/sWJ8SZ2dReG6oTH36NMkYmIwN
# 6R45q7fU4g5uVeB0T7EKdbb3YmkwRhd0TKPtPYgXgR2EQmmQsflFgc76fkxey014
# R47BycJoY50XL/1rad+TwlTcJv6sTzQwyqwaiyWfgGBlFUdxqPbjqTWQnJoNtJhE
# rm442DSgfeBoUl6ZEVLp9w+E66kADBP4qZ2LCcbvmhAt+xzyUpTxdcCVYhVBY7wf
# KK2h6WWff8iBOrOxw1/V0p9JmBpaqnzaAE4/3bMIlurm9SUT3A6BZoSQdRPr/pnf
# XqfwfhO9uYvrgSJGC5ec/Nw9TPfQtBrpejy11Nuh//ZK/Y6NeT51WQG0wINPqV6u
# MJrIsqGlvj3K1Vae9CNgy8vI42bnnwn2dwrSCFkxggL2MIIC8gIBATBVMEcxEzAR
# BgoJkiaJk/IsZAEZFgNrbGcxFjAUBgoJkiaJk/IsZAEZFgZwb3J0YWwxGDAWBgNV
# BAMTD1BPUlRBTFBLSS1TdWJDQQIKdox2awAAAAABAjAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# JR13PGmwh8E4yfMvs1qq3BAhZHswDQYJKoZIhvcNAQEBBQAEggIAHlX12ffklAB+
# FjpPR/fS7Q14a1sBkr2Tm5gBP0afl2CWl1sVWK9JRCZnF8dZZ3ngpnLxn8Wb0CyO
# l48iMR/dj5o9AI+xMdX/x4i3SL2hsSI/7nFt2HsTW98eYbkMaluvxqNsl+ZAJ53k
# cBJu1jv+/zPVP83cukg08cpJ8TaNulXTSDuvg6+rCfF8DyoStKGNLltI19wx8VcM
# VYybQ9IBocSmtJx/CewbDymkZietGoLTOP1ZcY/Wp6JjglRRvXxX9EnxJAWAMX1q
# R7Fp/mHoMQIgBBPjCUYitsHzoVW6gBpg2Qv64WEUDVND4PZXnZCHLa6uL3sEqbOl
# 9rffx4c1V+cPBfO7WJDhYeRxfy6alYNS/YHLXgiZriWcQ8lLQ1OK7c+ylfC7+5VJ
# S2uIbWa/te7nQiv/m8zno1aGXFh4G22o4Ti5V7GoGjOlgc2sNYYkCkwnMTwkGwOX
# gA3NeShlqJ8Nu7suIxs2X+ktC+2JTgC6KwMa87AB48l4pJRoCZQLqeWrHuPccdU2
# MHi+LBMbyYPGADWdOIayhBSy62Mrgdzs4z0oy3asRpRktlyPNIgoWAMr9CMo4pXB
# 2WrMrPLVjtXmOHLsSurdxSLSDLyC45Xap6RSB1T0nZV1stGgeFr0vC1CyeQSEC4u
# dhEqCnoDYxzJwVj8cSNyRREoJOfmjcM=
# SIG # End signature block
