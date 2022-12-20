<#
Ermittelt alle WSUS-Clients die seit mindestens 8 Wochen keinen Bericht mehr erstellt haben.

D. Marx, 2021/08
#>
param(
    $WsusServerFqdn='wsus01',
    $outfile="C:\temp\wsus-clients.csv"
)

[void][reflection.assembly]::LoadWithPartialName( "Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()

#$wsus = Get-WsusServer -Name $WsusServerFqdn -PortNumber 8530

Write-host $("Server is: " + $wsus.Name)
$servergroups=$wsus.GetComputerTargetGroups()

$lastreportdate = (Get-Date).AddDays((8*7*-1))

$clients = get-wsuscomputer
[System.Collections.ArrayList]$cl_detailed = @() 

[Int]$counter=0

foreach ($cl in $clients){    
   
    ($cl.FullDomainName + ";"+ $cl.IPAddress + ";" + $cl.LastReportedStatusTime) | out-file -FilePath c:\temp\wsus-clients.csv -append -Encoding utf8
}

$client | ft