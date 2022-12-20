<#
PS-Multithread-Test. Demonstriert beispielhaft den Aufruf von Powershelljobs
D.Marx, 2021708
#>
param(
    $maxconcurrent=3
)
write-host "Starting..."

for ($c=0;$c -lt 16;$c++) {
    $activejobs=$(Get-Job -State Running).Count    
    while ($activejobs -ge $maxconcurrent){
        Start-Sleep 0.5
        $activejobs=$(Get-Job -State Running).Count
        #Write-Host $("Active jobs: " + $activejobs)
    }

    Write-Host "Starting Job: " $c    
    start-job -scriptblock {
        [System.Collections.ArrayList]$resultset = @()

        $count = $(get-process).count
        Start-Sleep 2
        return $count
        #$resultset.Add($count)
        #return $resultset
        } -Name $("Test_"+$c) | Out-Null

}

write-host "Waiting/Retrieving..."
$jobsresults=Get-Job | Wait-Job | Receive-Job
$total=0
foreach ($res in $jobsresults){
    $total=$total + $res
}

Write-Host "Total: " $total
