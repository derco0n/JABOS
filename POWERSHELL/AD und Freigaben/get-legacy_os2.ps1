<#
Detects the state of legacy Windows-Edition in an Active-Directory
D. Maienhöfer, 2021/11
#>

$allcomputers = get-adcomputer -SearchBase "DC=eine,DC=firma,DC=local" -filter * -properties samaccountname,operatingsystem,operatingsystemversion,enabled | Where-Object {$_.enabled -eq $true} | select-object -Property samaccountname,operatingsystem,operatingsystemversion,enabled

[hashtable]$versioncounters = @{} # will contain the versions and their counters

$supported_win10builds=@(
    "19044", #21H2 - 13.06.2023
    "19043" #21H1 - 13.12.2022    
)

$supported_win11builds=@(
    "22000" #21H2 - 10.10.2023   
)

$supported_winsrvbuilds=@(
    "20348", #Windows Server 2022 - 13.10.2026       
    "17763", #Windows Server 2019 (Version 1809) - 09.01.2024
    "14393", #Windows Server 2016 (Version 1607)- 12.01.2027
    "9600" #Windows Server 2012(R2) - 10.10.2023
    "9200" #Windows Server 2012 - 10.10.2023
)

foreach ($computer in $allcomputers){
    if ($computer.enabled -eq $false){
        continue  # computerobject is not enabled: skip.
    }
    #$detail=(Get-ADComputer $c -Properties name,operatingsystem,operatingsystemversion,lastlogontimestamp | Where-Object {$_.enabled -eq $true -and $_.operatingsystem -like $os} | Select-Object -Property name,operatingsystem,operatingsystemversion,@{Name='LastLogon';Expression={[DateTime]::FromFileTime($_.LastLogonTimestamp)}})
    
    $islegacy=$false
    if ($computer.operatingsystem -like '*Windows*'){
        if ($computer.operatingsystem -like '*Server*'){            
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
            if ($computer.operatingsystem -notlike '*Windows 8.1*' -and $computer.operatingsystem -notlike '*Windows 10*' -and $computer.operatingsystem -notlike '*Windows 11*'){
                # Legacy-OS
                $islegacy=$true                             
            }                       
            elseif($computer.operatingsystem -like '*Windows 10*'){                
                [bool]$validversionfound=$false
                if ($computer.operatingsystem -like "*Enterprise*LTS*"){
                    # LTSB / LTSC Release might still be on support
                    $validversionfound=$true
                }
                else {        
                    foreach ($supported in $supported_win10builds){
                        $searchfor=("*"+$supported+"*")
                        if ($computer.operatingsystemversion -like $searchfor ){
                            $validversionfound=$true  # The client runs an OS that is still supported
                            break
                        }
                    }
                }
                if (!$validversionfound){
                    # Legacy-OS
                    $islegacy=$true
                    $winlegacyclientcount+=1
                }
            }
            elseif($computer.operatingsystem -like '*Windows 11*'){                
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
        $computer.operatingsystemversion+=$computer.operatingsystemversion + " (Non Windows - EOL unknown)"
        }

    if ($null -ne $computer){
        [string]$v=""            
        $v+=$computer.operatingsystem + " " + $computer.operatingsystemversion
        if ($islegacy){
            $v += " (END OF LIFE!)"
        }
        if ($versioncounters.ContainsKey($v)){
            $versioncounters[$v]=$versioncounters[$v]+1
        }
        else {
            $versioncounters+=@{$v=1}
        }
    }        
}

Write-Host "`r`nVersions by Count"
$versioncounters | Sort-Object -Verbose -Descending | Format-Table -AutoSize
$versioncounters.GetEnumerator() | Select-Object Name, @{N='Computers';E={$_.Value -join ", "}} | export-csv -Path "C:\temp\osversions.csv" -Encoding UTF8 -NoTypeInformation

