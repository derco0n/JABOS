#Dieses Skript signiert ein anderes Powershellskript
#Ein gültiges Codesigningzertifikat ist erforderlich.
#März 2016, D. Marx

param([String]$Filename)

if ($Filename -eq $null){
write-host "Aufruf: .\signscript -Filename Laufwerk:\Pfad\zum\Script.ps1"
 exit 1
}
else
{
try {
	$cert = Get-ChildItem cert:\CurrentUser\My -CodeSigningCert
	Set-AuthenticodeSignature -Certificate $cert -FilePath $Filename
	Write-Host "$Filename wurde signiert."
	exit 0
	}
catch {
	Write-Host "Es ist ein Fehler aufgetreten."
	exit 2
	}
}

