# Displays the permission of a folder-structure
# D. Marx, 2020/09
param (
[String]$basedir=""
)

if ($basedir -eq ""){
    Write-Warning "Can not do anything! Please specify a directory with the `"-basedir`" parameter..." 
    exit 1
}

$FolderPath = Get-ChildItem -Directory -Path $basedir -Recurse -Force

$Output = @()
ForEach ($Folder in $FolderPath) {
    $Acl = Get-Acl -Path $Folder.FullName
    $Owner = $Acl.Owner
    ForEach ($Access in $Acl.Access) {
        $Properties = [ordered]@{'Folder Name'=$Folder.FullName;'Group/User'=$Access.IdentityReference;'Permissions'=$Access.FileSystemRights;'Inherited'=$Access.IsInherited;'Owner'=$Owner}
        $Output += New-Object -TypeName PSObject -Property $Properties            
    }
}
$Output | Out-GridView

exit 0
# SIG # Begin signature block
# MIIJmQYJKoZIhvcNAQcCoIIJijCCCYYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUTcUdq8KfAVVNEotL3K0y3Mkl
# v5igggcJMIIHBTCCBO2gAwIBAgITXQAAAM2Im2zsOcilpQABAAAAzTANBgkqhkiG
# 9w0BAQsFADBCMRIwEAYKCZImiZPyLGQBGRYCZGUxGTAXBgoJkiaJk/IsZAEZFglv
# bHBsYXN0aWsxETAPBgNVBAMTCE9MUERPLUNBMB4XDTIwMDEyMzA3NDMwMVoXDTI1
# MDEyMTA3NDMwMVowdTESMBAGCgmSJomT8ixkARkWAmRlMRkwFwYKCZImiZPyLGQB
# GRYJb2xwbGFzdGlrMRQwEgYDVQQLEwtPVSBCZW51dHplcjEYMBYGA1UECxMPT1Ug
# VGVzdGJlbnV0emVyMRQwEgYDVQQDEwtEZW5uaXMgTWFyeDCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALMmk6lMMUyO1FT942gjYrv0qz+7aPEeW+hHZvWH
# h+Wg0dOupzkXvIopzAF3X0bxMApeBj5Py+PWrRz/71mNNyKYDl40EL/CT3dQWnPS
# NmgW8gSacRgM54TL6O4Lx5nf00NRmPz2M45SH1wW89sEGuGWGT5ZD9nBMxd02bmr
# k3mACNZ/63IKV1FCEDeOt+l8sbD2agSDCXxA8/LzGSuign1j4oq+J6mW5ZrPcaN3
# /lFlAVQoNNB08+jQgJkYLFIMnVHoUp+2TxEC9hFfVMOgNX4X1y27h6COkvsB4clb
# KvTU4acwzNX5UBW7NQprElxstgka5jlgOVAEPWnOLKdCWJkCAwEAAaOCAr8wggK7
# MD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIWnhCiDm7ADh7GLIISz10qC94tO
# CobM20WGqr8xAgFkAgEIMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQE
# AwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQuPYAJ
# zVRtWXt9FHF2R+bNvM4x7DAfBgNVHSMEGDAWgBQ+ouZeOm+4stpuqS9QfcXSgbnh
# JTCCAQkGA1UdHwSCAQAwgf0wgfqggfeggfSGgbZsZGFwOi8vL0NOPU9MUERPLUNB
# KDEpLENOPW9scGRvZXBwMDEsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
# Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9b2xwbGFzdGlrLERD
# PWRlP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1j
# UkxEaXN0cmlidXRpb25Qb2ludIY5aHR0cDovL29scGRvZXBwMDEub2xwbGFzdGlr
# LmRlL0NlcnRFbnJvbGwvT0xQRE8tQ0EoMSkuY3JsMIG7BggrBgEFBQcBAQSBrjCB
# qzCBqAYIKwYBBQUHMAKGgZtsZGFwOi8vL0NOPU9MUERPLUNBLENOPUFJQSxDTj1Q
# dWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0
# aW9uLERDPW9scGxhc3RpayxEQz1kZT9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0
# Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAtBgNVHREEJjAkoCIGCisGAQQB
# gjcUAgOgFAwSZG0zNThAb2xwbGFzdGlrLmRlMA0GCSqGSIb3DQEBCwUAA4ICAQCO
# 9sWMrdSpYxz33JDDBPR7iH/zS5QGHfp5by/A2LOnsNDIMkH8cNIB/IrcyYVQ+Vb3
# ZSJbvvVcOesffLL2nPzr71tZeY7jYn1q9j7ICpQPFN/dLYkr7Rdjtj/D8fsZD1T6
# +f6MDmSn7C9wdp1eJp1u6i7e9I1Lxq9rdOvAGvynfIPu2D6bdyboMglJ7zARGPAt
# AekERohN7I2erinfy+gQdWmE7zdhF7OooT8A4xE131PsSugDzGcdR7BxSk0J7+qe
# lj/BNo5C2NyxQrQY0zQDNh+2XOAy1/gLRjNCs6Hk+J6YmirQ51Y2A70Fp7//cy47
# BDCWcaKYY+83CVFREzlD6vnqP6Ynv1O0Jl/CdpWdS0BplloeUtmg94juP+U4f9v9
# 5f7RU4ev+6euwwtps0gVXEQ7YkTdhKrkJJT6SbZIoqrwvXHdTPgmpCnHKAmVWSda
# kw79EGkgXUCEmevvJN5I7vJgLLbgjc5sKQycNL2BtCh/PTYN6XADGEy1H988ijKL
# P5nPhE2HSr3TidxAg2zuKI9scqz1RYbyP94pJru1xtgvaRaHH++dlgW28qGYfFkY
# vmgBb+wH3PwACbnyhiF/mur8kgQfFEoy9a0zGaDrFXEKFUXmcv6mtyZ3TuMLLNKd
# +NwNdusytrD5MKc9zvs5fSsZsvnu7aHwAJ6shO5BQTGCAfowggH2AgEBMFkwQjES
# MBAGCgmSJomT8ixkARkWAmRlMRkwFwYKCZImiZPyLGQBGRYJb2xwbGFzdGlrMREw
# DwYDVQQDEwhPTFBETy1DQQITXQAAAM2Im2zsOcilpQABAAAAzTAJBgUrDgMCGgUA
# oHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0B
# CQQxFgQU14EkU2X7Qvf0Lrafshr6l6CdNWcwDQYJKoZIhvcNAQEBBQAEggEAL3A2
# co6wiWZtVSNVmdW/GIvACTRQTva8jhhF1c9xrHuLaj+NqTsQ5QxjqeByw6olIP0K
# n4cVUdI9dIQH2fLzX+xZtdZFmb9s05sQRJ/BPui2Ok/lf2GMZFoeWnI4kEOE6LiF
# RI8S2VtEKR6CyqQrZJKbGVYWdqbgTkfeHHjttDw+pDZfl194Dt9fvmBo6GL7Ag7+
# W4+kg/fLLfR1l81LbCsWE0sO9k8VF8Y8izLy/+O9b8vlXnlBliWASAIb37D62ZvB
# n45D9oHUOGvi3p3fTEX2bLCyqSci3mJ6WuD1RItdlPNnw0FLtZIY/66M7wQR4XUX
# vrB6Kc0+c9/7G3CiAA==
# SIG # End signature block
