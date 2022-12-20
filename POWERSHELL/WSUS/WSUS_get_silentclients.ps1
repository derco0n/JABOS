<#
Ermittelt alle WSUS-Clients die seit mindestens 8 Wochen keinen Bericht mehr erstellt haben.

D. Marx, 2021/08
#>
param(
    $WsusServerFqdn='localhost',
    $outfile="C:\temp\silent-wsus-clients.csv"
)

[void][reflection.assembly]::LoadWithPartialName( "Microsoft.UpdateServices.Administration")
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer()

#$wsus = Get-WsusServer -Name $WsusServerFqdn -PortNumber 8530

Write-host $("Server is: " + $wsus.Name)
$servergroups=$wsus.GetComputerTargetGroups()

$lastreportdate = (Get-Date).AddDays((8*7*-1))

$silentclients = get-wsuscomputer -ToLastReportedStatusTime $lastreportdate
[System.Collections.ArrayList]$cl_detailed = @() 

[Int]$counter=0

foreach ($cl in $silentclients){    
    $counter+=1
    [int]$percs=100/$silentclients.Count * $counter
    Write-Progress -Activity "Ermittle Informationen über bekannte WSUS-Clients..." -Status "$percs% Fortschritt:" -PercentComplete $percs

    Write-Host $($counter.tostring() + "/" + $silentclients.Count.tostring() + ": " + $cl.FullDomainName)

    $clientip_reachable = $(Test-Connection -ComputerName $cl.IPAddress -Quiet -Count 1)

    [String]$nsip=""
    try {
        # DNS-lookup versuchen        
        Resolve-DnsName $cl.Computer
        $nsip=$((Resolve-DnsName $cl.Computer).IPAddress).toString()
        $resolvedip_reachable = $(Test-Connection -ComputerName $nsip -Quiet -Count 1)
    }
    catch {
        $nsip="LOOKUP FAILED!"
        $resolvedip_reachable = $false
    }   

    $mcl = New-Object PSObject
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_HOSTNAME" -Value $cl.FullDomainName    
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_IP" -Value $cl.IPAddress
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_IP_REACHABLE" -Value $clientip_reachable -Force    
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_LAST-REPORT" -Value $cl.LastReportedStatusTime
    $groups = ""
    foreach ($g in $cl.ComputerTargetGroupIds){
        foreach ($sg in $servergroups){
            if ($g -eq $sg.ID){
                $groups = $groups + " " + $sg.Name
                break
                }
            }
        }
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_GROUPS" -Value $groups
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_OS" -Value $($cl.OSDescription + " (" + $cl.OSArchitecture + ")")    
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_OS-VERSION" -Value $cl.ClientVersion
    #$mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_BIOS-INFO" -Value $cl.BiosInfo    
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_CLIENT_MODEL" -Value $cl.Model
    $mcl | Add-Member -MemberType NoteProperty -Name "WSUS_SERVER" -Value $cl.UpdateServer.Name
    $mcl | Add-Member -MemberType NoteProperty -Name "Resolved_IP" -Value $nsip -Force
    $mcl | Add-Member -MemberType NoteProperty -Name "Resolved_IP_REACHABLE" -Value $resolvedip_reachable -Force
    
    $identity=$($cl.FullDomainName.split("."))[0]
    try {
        $adobj = Get-ADComputer -Identity $identity -Properties samaccountname,Enabled,lastLogonTimestamp
    }
    catch {
        $adobj = $null
    }

    if ($null -ne $adobj){
        $mcl | Add-Member -MemberType NoteProperty -Name "AD_Enabled" -Value $adobj.Enabled -Force
        $lastlogondate = [datetime]::FromFileTime($adobj.lastLogonTimestamp).tostring('dd.MM.yyyy')
        $mcl | Add-Member -MemberType NoteProperty -Name "AD_LastLogon" -Value $lastlogondate -Force
    }
    else {
        # AD-object not found
        $mcl | Add-Member -MemberType NoteProperty -Name "AD_Enabled" -Value "NOT FOUND IN AD" -Force        
        $mcl | Add-Member -MemberType NoteProperty -Name "AD_LastLogon" -Value "NOT FOUND IN AD" -Force
    }
    

    #$mcl | ft

    $null = $cl_detailed.Add($mcl)
   
}

$cl_detailed | Export-Csv -Encoding utf8 -NoTypeInformation -Path $outfile -Delimiter ";"

$cl_detailed | ft