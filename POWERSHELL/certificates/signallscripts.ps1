#Dieses Skript signiert alle Powershellskripte und .exe-Dateien innerhalb einer Ordnerstruktur
#Mai 2017, D. Marx  (IT)
param([String]$Folder)

if ($Folder -eq $null){
write-host "Aufruf: .\signallscripts -Folder Laufwerk:\Pfad\"
 exit 1
}
else {

	try {
		$content=gci -recurse -path $Folder -Filter *.ps1 #Powershellskripte
		$content+=gci -recurse -path $Folder -Filter *.exe #Ausführbare Dateien
		$content+=gci -recurse -path $Folder -Filter *.inf #Treiberdateien
		$cert = Get-ChildItem cert:\CurrentUser\My -CodeSigningCert
		foreach ($script in $content){
			write-host Signiere $script.Fullname
			Set-AuthenticodeSignature -Certificate $cert -FilePath $script.Fullname
			write-host OK
			}
		exit 0
		}
	catch {
		Write-Host "Es ist ein Fehler aufgetreten."
		exit 2
		}
}

