<#
This will use psexec to register a new source for the windows-eventlog on a bunch of systems, which are defined in a text-file.
Run this with administrative permissions.

D. Marx, 2021/09
#>

param (
    $hostsfile="C:\InfoSec\targets-list.txt",    
    $srcname="site_Tools_ReConnect-v2"
)

$hosts= get-content  $hostsfile
write-host ("Found " + $hosts.count().tostring() + " targets...")

$Jobs = @()
$sb = {
    Param (               
        $sourcename
    )    
    New-Eventlog -LogName 'Application' -Source $sourcename    
}

foreach($pshost in $hosts)
{
    #$Jobs += start-job -ScriptBlock $sb -ArgumentList $pshost,$psexecbin,$srcname
    Invoke-Command -ComputerName $pshost -ScriptBlock $sb -ArgumentList srcname
}

$Jobs | Wait-Job

$Output = @()
ForEach ($Job in $Jobs)
{   $Output += $Job | Receive-Job
    $Job | Remove-Job
}

#$Output | Out-File "$($env:userprofile)\Desktop\output.txt"
$Output | Out-File "C:\temp\add-new_eventlog.log"

exit 0