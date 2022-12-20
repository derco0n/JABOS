<#
Retrieves a list of all clients that weren't active in the recent time
D. Maienhöfer, 2022/02
#>
param(
    $olddays=180  #Days after which the last-logon should be considered old
)
$allenabledcomputers = get-adcomputer -filter * -properties lastlogontimestamp,samaccountname,operatingsystem,operatingsystemversion,enabled |  Where-Object {$_.enabled -eq $true} | select-object -Property samaccountname,operatingsystem,operatingsystemversion,enabled,lastlogontimestamp
$oldcomputers=[System.Collections.ArrayList]::new();
$Today=(GET-DATE)

foreach($c in $allenabledcomputers){
    $c | Add-Member -Force -MemberType NoteProperty -Name "LastLogonDate" -Value $(
        if ($null -eq $c.LastlogonTimestamp -or $c.LastlogonTimestamp -le 0 ){
            "Never" # never logged in
        }
        else {
            [datetime]::FromFileTime($c.LastlogonTimestamp).tostring('dd.MM.yyyy')
        }
    )
    
    if ($null -ne $c.operatingsystem -and $c.operatingsystem -like "*Windows*"){
        # if the operatingsystem is not filled, this indicates a thin-client    
        $EndDate=[datetime]::FromFileTime($c.lastlogontimestamp).ToString('g')
        $ts = new-timespan -Start $EndDate -End $Today

        if ($ts.TotalDays -gt $olddays){
            $null = $oldcomputers.add($c)
        }
    }
}

$oldcomputers | format-table
write-host ("All active computer-accounts in AD " + $allenabledcomputers.Count);
write-host ("Devices that had not been logged on since " + $olddays + " days: " + $oldcomputers.Count);
$oldcomputers | Out-GridView



