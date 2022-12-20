<#
Adds Computerobjects to the feature-upgrades-test group
D. Maienhöfer, 2022/06
#>
param (
    [string]$version="19044",
    [string]$group="site-Computer_Windows-Featureupdates_per_WSUS_aktiviert",
    [switch]$WhatIf=$false,
    [uint64]$objcount=200
)

[uint64]$objhalf1= [math]::Floor($objcount/2)
[uint64]$objhalf2=$objcount-$objhalf1

Write-Host("Searching Computerobjects. Select First " + $objhalf1.ToString() + " and Last "+$objhalf2.ToString())
if ($WhatIf){
    Write-Host("Dry run: won't actually add computer to group")
}

$items=(Get-ADComputer -filter * -Properties name,operatingsystem,operatingsystemversion,lastlogontimestamp | Where-Object {$_.enabled -eq $true -and $_.operatingsystem -like "Windows 10*" -and $_.operatingsystemversion -notlike ("*"+$version+"*")} | Select-Object -Property samaccountname -last $objhalf1 -first $objhalf2)
#$items | format-table

$members=(Get-ADGroupMember -Identity $group | Select-Object -Property samaccountname)
#$members | format-table

[uint64]$newadded=0
foreach ($c in $items){    
    $skip=$false
    foreach ($m in $members){
        if ($m.samaccountname -eq $c.samaccountname){
            Write-Host ("`""+$c.samaccountname + "`" is already member of `"" + $group+ "`"")
            $skip=$true
            break
        }    
    }
    if($skip){
        continue
    }
    $newadded+=1
    Write-Host ("Adding `"" + $c.samaccountname + "`" to `"" + $group+"`"")
    if (!$WhatIf){
        Add-ADGroupMember -Identity $group -Members $c
    }
}
write-host ("Added " + $newadded.ToString() + " items to `"" + $group+"`"")
exit(0)