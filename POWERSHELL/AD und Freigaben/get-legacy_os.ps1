<#
Detects the state of legacy Windows-Edition in an Active-Directory
D. Maienhöfer, 2021/11
#>

$allcomputers = get-adcomputer -filter * -properties samaccountname,operatingsystem,operatingsystemversion,enabled | Where-Object {$_.enabled -eq $true} | select-object -Property samaccountname,operatingsystem,operatingsystemversion,enabled

$winservercount=0
$winclientcount=0
$winlegacyclientcount=0
$winlegacyservercount=0
$olderthanwin7=0
$win7=0
$winclientsite=0
$winclientsite=0
$winclientsite=0
$win7sitelegacy=0
$win7sitelegacy=0
$win7sitelegacy=0
$win10=0
$otheros=0

$supported_win10builds=@(
    "19044", #21H2 - 13.06.2023
    "19043" #21H1 - 13.12.2022    
)

$supported_win11builds=@(
    "22000" #21H2 - 10.10.2023   
)

$supported_winsrvbuilds=@(
    "20348", #Windows Server 2022 - 13.10.2026
    "19042", #Windows Server, Version 20H2 - 10.05.2022    
    "17763", #Windows Server 2019 (Version 1809) - 09.01.2024
    "14393", #Windows Server 2016 (Version 1607)- 12.01.2027
    "9600" #Windows Server 2012(R2) - 10.10.2023
    "9200" #Windows Server 2012 - 10.10.2023
)

$win11_buildnames=New-Object System.Collections.Generic.Dictionary"[Int,String]"
$win11_buildnames.Add(22000, "21H2");

$win10_buildnames=New-Object System.Collections.Generic.Dictionary"[Int,String]"
$win10_buildnames.Add(10240, "1507");
$win10_buildnames.Add(10586, "1511");
$win10_buildnames.Add(14393, "1607");
$win10_buildnames.Add(15063, "1703");
$win10_buildnames.Add(16299, "1709");
$win10_buildnames.Add(17134, "1803");
$win10_buildnames.Add(17763, "1809");
$win10_buildnames.Add(18362, "1903");
$win10_buildnames.Add(18363, "1909");
$win10_buildnames.Add(19041, "2004");
$win10_buildnames.Add(19042, "20H2");
$win10_buildnames.Add(19043, "21H1");
$win10_buildnames.Add(19044, "21H2");

$legacyosses=New-Object System.Collections.Generic.Dictionary"[String,Int]"
$legacyossesgrouped=New-Object System.Collections.Generic.Dictionary"[String,Int]"
$allosses=New-Object System.Collections.Generic.Dictionary"[String,Int]"
$win10older1809=0

foreach ($computer in $allcomputers){
    if ($computer.enabled -eq $false){
        continue  # computerobject is not enabled: skip.
    }
    $islegacy=$false
    if ($computer.operatingsystem -like '*Windows*'){
        if ($computer.operatingsystem -like '*Server*'){

            $winservercount+=1
            [bool]$validversionfound=$false                
                foreach ($supported in $supported_winsrvbuilds){
                    $searchfor=("*"+$supported+"*")
                    if ($computer.operatingsystemversion -like $searchfor ){
                        $validversionfound=$true  # The server runs an OS that is still supported
                        break
                    }
                }
                if (!$validversionfound){
                    # Legacy-OS
                    $islegacy=$true
                    $winlegacyservercount+=1
                }
        }
        else {
            if ($computer.samaccountname.toupper().StartsWith("site")){
                $winclientsite+=1
            }
            elseif ($computer.samaccountname.toupper().StartsWith("site")){
                $winclientsite+=1
            }
            elseif ($computer.samaccountname.toupper().StartsWith("site")){
                $winclientsite+=1
            }

            $winclientcount+=1
            if ($computer.operatingsystem -notlike '*Windows 8.1*' -and $computer.operatingsystem -notlike '*Windows 10*' -and $computer.operatingsystem -notlike '*Windows 11*'){
                # Legacy-OS
                $islegacy=$true
                $winlegacyclientcount+=1
                if($computer.operatingsystem -notlike '*Windows 7*'){
                    $olderthanwin7+=1
                }
            }
            if ($computer.operatingsystem -like '*Windows 7*'){
                $win7+=1
                if ($computer.samaccountname.toupper().StartsWith("site")){
                    $win7sitelegacy+=1
                }
                elseif ($computer.samaccountname.toupper().StartsWith("site")){
                    $win7sitelegacy+=1
                }
                elseif ($computer.samaccountname.toupper().StartsWith("site")){
                    $win7sitelegacy+=1
                }
            }            
            elseif($computer.operatingsystem -like '*Windows 10*'){
                $win10+=1
                [bool]$validversionfound=$false                
                foreach ($supported in $supported_win10builds){
                    $searchfor=("*"+$supported+"*")
                    if ($computer.operatingsystemversion -like $searchfor ){
                        $validversionfound=$true  # The client runs an OS that is still supported
                        break
                    }
                }
                if (!$validversionfound){
                    # Legacy-OS
                    $islegacy=$true
                    $winlegacyclientcount+=1
                }
            }
            elseif($computer.operatingsystem -like '*Windows 11*'){
                $win11+=1
                [bool]$validversionfound=$false                
                foreach ($supported in $supported_win11builds){
                    $searchfor=("*"+$supported+"*")
                    if ($computer.operatingsystemversion -like $searchfor ){
                        $validversionfound=$true  # The client runs an OS that is still supported
                        break
                    }
                }
                if (!$validversionfound){
                    # Legacy-OS
                    $islegacy=$true
                    $winlegacyclientcount+=1
                }
            }
        }
    }
    else {
        $otheros+=1
    }

    
    [string]$osbuild=$computer.operatingsystem + " " + $computer.operatingsystemversion
    if ($allosses.ContainsKey($osbuild)){ # list already contains entry. increment count
        $allosses[$osbuild]=$allosses[$osbuild]+1
    }
    else { # Add new entry to the list
        $allosses.Add($osbuild, 1);
    }
    

    if ($islegacy){
        [string]$osbuild=$computer.operatingsystem + " " + $computer.operatingsystemversion
        $bnstart=$computer.operatingsystemversion.IndexOf("(")+1;
        $bnend=$computer.operatingsystemversion.IndexOf(")");
        $blen=$bnend-$bnstart
        if ($blen -gt 0){
            $bn=($computer.operatingsystemversion).Substring($bnstart,$blen)
            [Int]$buildnumber=[int]::Parse($bn)

            if ($computer.operatingsystem -like "*Windows 10*"){
                $osbuild = $osbuild + " ("+$win10_buildnames[$buildnumber]+")"
                if ($buildnumber -lt 17763){ #older than 1809
                    $win10older1809+=1
                }
            }
            elseif ($computer.operatingsystem -like "*Windows 11*"){
                $osbuild = $osbuild + " ("+$win11_buildnames[$buildnumber]+")"
            }
        }

        if ($legacyosses.ContainsKey($osbuild)){ # list already contains entry. increment count
            $legacyosses[$osbuild]=$legacyosses[$osbuild]+1
        }
        else { # Add new entry to the list
            $legacyosses.Add($osbuild, 1);
        }


        if ($legacyossesgrouped.ContainsKey($computer.operatingsystem)){ # list already contains entry. increment count
            $legacyossesgrouped[$computer.operatingsystem]=$legacyossesgrouped[$computer.operatingsystem]+1
        }
        else { # Add new entry to the list
            $legacyossesgrouped.Add($computer.operatingsystem, 1);
        }

        
    }

    $computer | Add-Member -Force -MemberType NoteProperty -Name "Is_Unsupported" -Value $islegacy
}

#$allcomputers | Format-Table
$allcomputers | export-csv -NoTypeInformation -Encoding utf8 -Path "C:\temp\ad_os_enumeration.csv"

Write-Host ("Non-Windows: " + $otheros)
Write-Host ("Windows-Servers Total: " + $winservercount)
if ($winlegacyservercount -gt 0){
    $percentage=1/$winservercount*$winlegacyservercount*100
    Write-Warning ("Windows-Servers on unspported OS-Release: " + $winlegacyservercount + " ( "+[math]::Round($percentage, 2)+"% )")
}
Write-Host ("Windows-Clients Total: " + $winclientcount)
if ($winlegacyclientcount -gt 0){
    $percentage=1/$winclientcount*$winlegacyclientcount*100
    Write-Warning ("Windows-Clients on unspported OS-Release: " + $winlegacyclientcount + " ( "+ [math]::Round($percentage, 2)+"% )")
}
if ($olderthanwin7 -gt 0){
    $percentage=1/$winclientcount*$olderthanwin7*100
    Write-Warning ("Windows-Clients older than Windows 7: " + $olderthanwin7 + " ( "+ [math]::Round($percentage, 2)+"% )")
}
if ($win7 -gt 0){
    $percentage=1/$winclientcount*$win7*100
    Write-Warning ("Windows-Clients with Windows 7: " + $win7 + " ( "+ [math]::Round($percentage, 2)+"% )")
}
if ($win10 -gt 0){
    $percentage=1/$winclientcount*$win10*100
    Write-Host ("Windows-Clients with Windows 10: " + $win10 + " ( "+ [math]::Round($percentage, 2)+"% )")
}
if ($win11 -gt 0){
    $percentage=1/$winclientcount*$win11*100
    Write-Host ("Windows-Clients with Windows 11: " + $win11 + " ( "+ [math]::Round($percentage, 2)+"% )")
}

Write-Host "all OS'es in numbers..."
$allosses | format-table

Write-Host "legacy OS'es in numbers..."
$legacyosses | format-table
Write-host ("Windows 10 older than 1809: " + $win10older1809)

Write-Host "legacy OS'es in numbers grouped..."
$legacyossesgrouped | format-table

if ($win7 -gt 0){
    Write-Host "Windows 7 Details (Windows 7 / Alle Computer die mit KLx beginnen):"
    Write-Host ("site: " + $win7sitelegacy + " / " + $winclientsite + " ( "+[math]::Round((100/$winclientsite*$win7sitelegacy),2)+"% )")
    Write-Host ("site: " + $win7sitelegacy + " / " + $winclientsite + " ( "+[math]::Round((100/$winclientsite*$win7sitelegacy),2)+"% )")
    Write-Host ("site: " + $win7sitelegacy + " / " + $winclientsite + " ( "+[math]::Round((100/$winclientsite*$win7sitelegacy),2)+"% )")
    Write-host ""
}

write-host ("Total enabled legacy: " + $winlegacyclientcount + " ("+([Math]::Round(100/$allcomputers.count*$winlegacyclientcount,2))+"% ) of " + $allcomputers.count)


