# Requires Active Directory PowerShell-module
# This will query the software that is installed on computers on specific AD-OU's via WMI and will output the results to .csv-file

param (
[String]$outfile="C:\TEMP\Software_Server.csv",
[String]$errorfile="C:\TEMP\Software_Server_errors.csv",
[Switch]$append=$false
)

# Adjust the LDAP-Searchbase to your neeeds
$ldapsbases=@("OU=Domain Controllers,DC=contoso,DC=de", "OU=OU Server,DC=contose,DC=de")


# Main:
#######

Import-Module ActiveDirectory

if ($(Test-Path $errorfile)) {
    #Remove Errorfile if it exists
    rm $errorfile
}

# Clear the computer-objects-array (in case it had been used on a previous run)
$compobjects=@()

foreach ($base in $ldapsbases){
	Write-Host "Getting computer-objects from $base ..."
	$compobjects += Get-ADComputer -SearchBase $base -Filter *
	}

if ($compobjects.Count -gt 0) {
	#At least one object had been found
    $msg = "Found " + $compobjects.count + " computers in " + $ldapsbases.Count + " LDAP-Searchpaths."
	Write-Host $msg
	
	if (!$append){
		#information shouldn'be appended...
		if ($(Test-Path $outfile)){
            # Remove outfile if it exists
            rm $outfile
        }
	}

	foreach ($comp in $compobjects){
			Write-Host "Querying $comp for installed software"
			try {
				# Try to query the computer via WMI
				Get-WmiObject -ComputerName $comp.Name -Query "SELECT * FROM Win32_product" | Sort-Object Name | Select -Property PSComputerName, Name, Version | Export-CSV $outfile -Append	
			}
			catch {
				# Log error if WMI-query didn't work
				$msg = "Fehler beim Abfragen von " + $comp.Name + " => " + $_.Exception.Message | Out-File $errorfile -Append
			}
		}

}
else {
	Write-Host "No computer-object could be found..."
}

exit 0

