
function getname ($ip){
    #write-host "Testing" $ip
    $props = @{
        IP = $ip
        IsUp = 'No'
        Hostname = '>>unknown<<'
    }
    $cl=new-object psobject -Property $props
    # Try Ping
    try {
        $ping = Test-NetConnection -Computername $ip -ErrorAction SilentlyContinue
        if ($ping.PingSucceeded -eq $True){
            $cl.Isup='Yes'
            }
        }
    catch {
    }
    # Get Hostname
    try {
        $dnsres = Resolve-DnsName -name $ip -ErrorAction SilentlyContinue | select NameHost
        if ($dnsres.NameHost -ne ''){
            $cl.Hostname =$dnsres.NameHost
            }
        }
    catch {
        
        }
    $cl | ft
    
    $cl | select IP,IsUp,Hostname | Export-Csv -Path 'C:\temp\hosts.csv' -Append
}

$o1=10
$o2s=[int]1#,50,100
$o3=192
$o4=132

foreach ($o2 in $o2s){
    while ($o3 -le 254){
        while ($o4 -le 254){
            $ip = $o1.ToString()+"."+$o2.ToString()+"."+$o3.ToString()+"."+$o4.ToString()
            getname $ip           
            $o4++
            Start-Sleep 0.5
        }
        $o3++
        $o4=1
    }
}