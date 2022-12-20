param (
	$wslip=172.18.165.194,
	$port=5355
)
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  Break
}

$remoteport = bash.exe -c "ifconfig eth0 | grep 'inet '"
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';


Invoke-Expression "netsh interface portproxy reset";

Invoke-Expression "netsh interface portproxy add v4tov4 listenport=$port connectport=$port connectaddress=$wslip";
Invoke-Expression "netsh advfirewall firewall add rule name=$port dir=in action=allow protocol=TCP localport=$port";
Invoke-Expression "netsh advfirewall firewall add rule name=$port dir=in action=allow protocol=UDP localport=$port";

Invoke-Expression "netsh interface portproxy show v4tov4";