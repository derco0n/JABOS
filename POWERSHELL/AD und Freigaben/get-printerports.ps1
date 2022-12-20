<#
This will enumerate all Printerports on all printerservers and resolve the IP's corresponding to the PrinterHostAddresses
D. Maienhöfer, 2022/01
#>

param (
    $outfile="C:\temp\printerports.csv",
    $outnetportfile="C:\temp\printernetports.csv",
    $outipfile="C:\temp\printerportips.txt"
)

$printerservers=@(
    "spool19.eine.firma.local",
    "sitespool011.eine.firma.local"
)


#$printerservers=(Get-ADObject -LDAPFilter "(&(uncName=*)(objectCategory=printQueue))" -properties *|Sort-Object -Unique -Property servername).servername
remove-item $outnetportfile
$allports=[System.Collections.ArrayList]::new();
$allips=[System.Collections.ArrayList]::new();

foreach ($printsrv in $printerservers){
    write-host ("querying " + $printsrv + " ...")
    $ports = Get-PrinterPort -Computername $printsrv | select-object -Property Computername,Name,Protocol,Description,PrinterHostAddress,PortNumber
    write-host ("found "+$ports.count + " on " + $printserver)
    [int]$iteration=0
    foreach ($port in $ports){
        $iteration+=1
        [int]$percs=100/$ports.Count * $iteration
        Write-Progress -Activity "Enumerating..." -Status "$percs% completed" -PercentComplete $percs        
        $ip="Unbekannt"
        try {
            write-host ("Trying to find IP for " + $port.PrinterHostAddress.toString() + "@" + $printsrv)
            $ip=([System.Net.Dns]::GetHostByName($port.PrinterHostAddress)).AddressList[0].IPAddressToString
            Write-Host ("IP-Address is " + $ip)
        }
        catch {
            Write-Warning ("IP-Address not found for "+ $port.Name +"@"+$printsrv+"...")

        }
        $port | Add-Member -Force -MemberType NoteProperty -Name "IP_Address" -Value $ip
        $null=$allports.add($port)

        if ($ip -ne "Unbekannt"){
            ($port.PrinterHostAddress+";"+$port.Name+";"+$ip.ToString()) | Out-File $outnetportfile -Append

            if (!$allips.Contains($ip)){
                $null=$allips.Add($ip)
            }
        }
    }
}

# Remove Server-IP's from the IP-List
foreach ($printsrv in $printerservers){
    $ip="Unbekannt"
    try {
        $ip=([System.Net.Dns]::GetHostByName($printsrv)).AddressList[0].IPAddressToString       
    }
    catch {
    }

    if ($ip -ne "Unbekannt" -and  $allips.Contains($ip)){
        $allips.Remove($ip)
    }

}

$allips | sort-object -Unique | Out-File -Encoding utf8 -FilePath $outipfile
$allips | Out-GridView

$allports | export-csv -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Path $outfile
$allports | Out-GridView

