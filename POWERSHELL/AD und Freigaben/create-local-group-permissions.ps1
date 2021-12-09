#requires -modules ActiveDirectory
#Requires -RunAsAdministrator

# This will generate local-groups and NTFS-R/W-Permissions based on the folder structure
# D. Marx, 2020/05

param (
[String]$Basefolder,
[String]$Groupprefix="LG-SG-DB-DO_Files_",
[String]$GroupLDAPTarget="OU=OU Dateiberechtigungen,DC=contoso,DC=de",
[String]$ACLDomain="CONTOSO"
)

#functions
function Groupnames ([String] $Prefix, [String] $Basedir, [String] $Subdir="", [Bool]$checkgroups=$false){
    # Generates group names (R/RW/L) from given directory

    $maxdirlen=18  # Maximum length of dirnames
     
    [String]$dirn=Split-Path $Basedir -Leaf

    [String]$dname= $Groupprefix
    if ($dirn.Length -gt $maxdirlen){
        # Cut dir-name if it is too long
        $dirn=$dirn.substring(0, $maxdirlen)
        }
        
    $dname= $Prefix + $dirn

    if ($Subdir -ne ""){
        if ($subdir.Length -gt $maxdirlen) {
            # Cut base-dir-name if it is too long
            $subdir = $subdir.Substring(0,$maxdirlen)
        }
        
        #$dname+="_" + $Subdir.Substring(0, $maxdirlen)
        $dname+="_" + $subdir
    }


    # The names of security principal objects can contain all Unicode characters except the special LDAP characters defined in RFC 2253.
    # This list of special characters includes: a leading space; a trailing space; and any of the following characters: # , + " \ < > ;
    $dname = $dname.Trim()
    $dname=$dname.Replace(" ", "")
    $dname=$dname.Replace("#", "")
    $dname=$dname.Replace(",", "")
    $dname=$dname.Replace("+", "")
    $dname=$dname.Replace("`"", "")
    $dname=$dname.Replace("\", "")    
    $dname=$dname.Replace("<", "")
    $dname=$dname.Replace(">", "")
    $dname=$dname.Replace(";", "")

    # Remove some other unwanted chars as well
    $dname=$dname.Replace("/", "")
    $dname=$dname.Replace("@", "")
    $dname=$dname.Replace("ü", "ue")
    $dname=$dname.Replace("ä", "ae")
    $dname=$dname.Replace("ö", "oe")
    $dname=$dname.Replace("\", "ss")
    $dname=$dname.Replace(".", "")
    $dname=$dname.Replace("@", "")
    $dname=$dname.Replace("`"", "")
    $dname=$dname.Replace("§", "")
    $dname=$dname.Replace("$", "")
    $dname=$dname.Replace("%", "")
    $dname=$dname.Replace("&", "")
    $dname=$dname.Replace("(", "")
    $dname=$dname.Replace(")", "")
    $dname=$dname.Replace("=", "")
    $dname=$dname.Replace("?", "")
    $dname=$dname.Replace("~", "")
    $dname=$dname.Replace("``", "")
    $dname=$dname.Replace("´", "")
    $dname=$dname.Replace("'", "")
    $dname=$dname.Replace("*", "")
    $dname=$dname.Replace("µ", "u")
    $dname=$dname.Replace("|", "")
    $dname=$dname.Replace(":", "")
    
    # A group account cannot consist solely of numbers, periods (.), or spaces. Any leading periods or spaces are cropped.
    if ($dname -NotMatch '[A-Za-z]'){
        # String does not contain any alpha-char
        $dname = "LG_" + $dname
        }

    # 63 characters, or 63 bytes depending upon the character set; individual characters may require more than one byte.
    # As we need to add 6 chars, we need to cut it if its too long
    if ($dname.Length -gt 56) {
        $dname=$dname.Substring(0, 56)
    }  

# Append suffix to groupname
    $namerw=$dname + "__RW"
    $namer=$dname + "__R"
    #$namel=$dname + "__List" 
    
    if ($checkgroups) { #We need to check if the groups already exist. Usually done at first function-call
        # Make sure not to not use existing groups
        # Check if Groupname exists in AD and if yes, alter it...
        if ((groupExists $namerw)){
            # Group already exists in AD        
            $newname=(get-random -Minimum 100000 -Maximum 999999).ToString() + "_" + $namerw
            $msg = "generated Groupname `"" + $namerw + "`" already exists in AD. Renaming to: `"" + $newname + "`". Please double check this!!!!!1111elf"
            write-warning $msg
            $namerw=$newname
            # 63 characters, or 63 bytes depending upon the character set; individual characters may require more than one byte.        
            if ($dname.Length -gt 63) {
                $dname=$dname.Substring(0, 63)
                }  
            }

        if ((groupExists $namer)){
            # Group already exists in AD
            $newname=(get-random -Minimum 100000 -Maximum 999999).ToString() + "_" + $namer
            $msg = "generated Groupname `"" + $namer + "`" already exists in AD. Renaming to: `"" + $newname + "`". Please double check this!!!!!1111elf"
            write-warning $msg
            $namer=$newname
            # 63 characters, or 63 bytes depending upon the character set; individual characters may require more than one byte.        
            if ($dname.Length -gt 63) {
                $dname=$dname.Substring(0, 63)
                }  
            }
        }
    


    # Build Hashtable
    [hashtable]$myreturn = @{}    
    $myreturn.Add('Name_RW',  $namerw)
    $myreturn.Add('Name_R',  $namer)
    #$myreturn.Add('Name_List',  $namel)


    return $myreturn
    }

function makeNTFSPermission([String]$folder, [String]$object, [int]$permlvl){
    # Sets a permission on a Folder. ACL's will be inherited by child-objects

    $Perm=''
    if ($permlvl -eq 1){
        #Modify
        $Perm='ReadAndExecute'
        }
    elseif ($permlvl -eq 2){
        $Perm='Modify'
        }
    else {
        return
        }

    $msg = "Setting `"" + $Perm + "`" permissions for `"" + $folder + "`""
    Write-Host $msg
    $acl=get-acl $folder    
    $obj = $ACLDomain + "\" + $object
    $permission = $obj, $Perm, 'ContainerInherit, ObjectInherit', 'None', 'Allow' 
    $Accessrule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission
    $acl.setaccessrule($Accessrule)
    #$acl.removeaccessrule($Accessrule)
    $acl | set-acl $folder
    }

function groupExists([String]$Groupname){
    # Checks if a group with that name exists in AD
    $exists=$null
    try {
        $exists = Get-ADGroup -Identity $Groupname  -ErrorAction SilentlyContinue
        }
    catch {
        $exists = $null
        }
    if ($exists -eq $null) {
        return $false
        }
    else {
        return $true
        }
    }

function CreateGroups ($Groups, [String]$basedir, [String]$subdir) {
    $path = $basedir+"\"+$subdir
    #$Groups | fl # DEBUG    
    
    #Read: 
    if (-not (groupExists $Groups.Name_R)) {
        $description = "Ordner `"" + $path + "`" NTFS-Berechtigung lesend"  #Add Path to Description!!
        Write-Host "Creating Group: " $Groups.Name_R
        New-ADGroup -Name $Groups.Name_R -SamAccountName $Groups.Name_R -GroupCategory Security -GroupScope DomainLocal -DisplayName $Groups.Name_R -Path $GroupLDAPTarget -Description $description
    }
    else {
        $msg = "Group `"" + $Groups.Name_R + "`" already exists! Skipping." 
        Write-Warning $msg        
        return $false
    }

    #Write:
    if (-not (groupExists $Groups.Name_RW)) {
        $description = "Ordner `"" + $path + "`" NTFS-Berechtigung lesend/schreibend"  #Add Path to Description!!
        Write-Host "Creating Group: " $Groups.Name_RW
        New-ADGroup -Name $Groups.Name_RW -SamAccountName $Groups.Name_RW -GroupCategory Security -GroupScope DomainLocal -DisplayName $Groups.Name_RW -Path $GroupLDAPTarget -Description $description
    }
    else {
        $msg = "Group `"" + $Groups.Name_RW + "`" already exists! Skipping" 
        Write-Warning $msg
        return $false
    }
 
    Write-Host "Please Wait for the groups to become available in AD"
    
    # R
    $exists = $false
    while ($exists -eq $false) {
        Start-Sleep -s 1  # Wait for the Group to become available on the AD    
            $exists = groupExists $Groups.Name_R                        
        Write-Host "Still waiting..."
        }
    $msg = "Group `"" +  $Groups.Name_R + "`" found."
    Write-Host $msg

    # RW    
    $exists = $false
    while ($exists -eq $false) {
        Start-Sleep -s 1  # Wait for the Group to become available on the AD    
            $exists = groupExists $Groups.Name_R W                       
        Write-Host "Still waiting..."
        }
    $msg = "Group `"" +  $Groups.Name_RW + "`" found."
    Write-Host $msg    
    
    return $true
    }

function SetPermissions  ($Groups, [String]$basedir, [String]$subdir) {
    $path = $basedir+"\"+$subdir
    #$Groups | fl # DEBUG  

    #Read:
    $msg="Setting Read-Permission on `"" + $path + "`" for `"" + $Groups.Name_R + "`""
    Write-Host $msg
    makeNTFSPermission $path $Groups.Name_R 1

    #Write
    $msg="Setting Write-Permission on `"" + $path + "`" for `"" + $Groups.Name_RW + "`""
    Write-Host $msg
    makeNTFSPermission $path $Groups.Name_RW 2
    }

# Main
Import-Module ActiveDirectory

if (-not($Basefolder)) {
    Throw "Please specify a `"-Basefolder`" ."
    # Will exit here....
    }

if (-not($Groupprefix)) {
    Throw "Please specify a `"-Groupprefix`" ."
    # Will exit here....
    }

if (-not($GroupLDAPTarget)) {
    Throw "Please specify a `"-GroupLDAPTarget`" ."
    # Will exit here....
    }

if ((Test-Path $Basefolder) -eq $false){
    Throw "specified `"-Basefolder`" ($Basefolder) is inaccessible or does not exist."
    #Will exit here
    }

# Groups: 

# Basefolder
$gnames = Groupnames $Groupprefix $Basefolder "" $true
CreateGroups $gnames $Basefolder ""

# Subfolders (1 level - non recursive)
$folders = gci $Basefolder

foreach ($subfolder in $folders){
    # Create groups
    $gnames = Groupnames $Groupprefix $Basefolder $subfolder $true
    CreateGroups $gnames $Basefolder $subfolder        
}

# Wait
Write-Host "Waiting 60 seconds for Groups to become useable in ACLs"
Write-Warning "Groups created but ACL's not changed yet: Abort now (CTRL+C) if you don't want the ACL's to be altered !!!!!1111elf"
start-sleep 60


# Permissions:

# Basefolder
$gnames = Groupnames $Groupprefix $Basefolder "" $false
SetPermissions $gnames $Basefolder ""

# Subfolders
foreach ($subfolder in $folders){
    # Set permissions
    $gnames = Groupnames $Groupprefix $Basefolder $subfolder $false
    SetPermissions $gnames $Basefolder $subfolder
}
# SIG # Begin signature block
# MIIJmQYJKoZIhvcNAQcCoIIJijCCCYYCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUedueBdqTKVp+fTvQDWKtbewb
# kLygggcJMIIHBTCCBO2gAwIBAgITXQAAAM2Im2zsOcilpQABAAAAzTANBgkqhkiG
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
# CQQxFgQUd469i7M68wCZkedzR8jsVmRWrLgwDQYJKoZIhvcNAQEBBQAEggEAdHrW
# nqzHJkogYSs8xNWc+vnN72OnB0aGz9j0+LHF3tILlLQkvfv2p1iQhGy2mh6dN6Mp
# LVlHJq9Pgz4xZiTXkzRKBI2TbXccKAq1TmKD+I5B03Kh8dl7GPBWKtzHK8zEbL8C
# U+yvKQoEFckbPKWRDvt6KYnIiI/ZyL7FguHeGVIGLRPlanBIPh3f2uZVL/JjVQSg
# gxbg+p1wui4fptXyO41RAqV4q0ZA0a/udXqHp3xY/4J+4fR1RFLzj/mGIgPOeR0a
# IDkIfO3xG34wokWa1JhUbtRfg0KqvYdXFPTyCIVB/zLttozD9jCCQZ5Lq8DTXV3t
# FAtQWGX93/6YA/zbFQ==
# SIG # End signature block
