param(
[String]$url=$null,
[String]$targetdir="C:\temp"
)
if ($null -eq $url -or $url -eq ""){
	Write-Host "Please specifiy URL"
	exit 1
}

$parts=$url.split('/')
$filename=$parts[$parts.count-1]
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($url,$targetdir.trimend('\')+"\"+$filename)
