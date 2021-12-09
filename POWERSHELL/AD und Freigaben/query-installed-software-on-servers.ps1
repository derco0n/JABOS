# Requires Active Directory PowerShell-module

Import-Module ActiveDirectory

Get-ADComputer -SearchBase "OU=Domain Controllers,DC=contoso,DC=de" -Filter * | ForEach-Object {Get-WmiObject -ComputerName $_.Name -Query "SELECT * FROM Win32_product" | Sort-Object Name | Select -Property PSComputerName, Name, Version | Export-CSV C:\TEMP\Software_DCs.csv -Append}

Get-ADComputer -SearchBase "OU=OU Server,DC=contoso,DC=de" -Filter * | ForEach-Object {Get-WmiObject -ComputerName $_.Name -Query "SELECT * FROM Win32_product" | Sort-Object Name | Select -Property PSComputerName, Name, Version | Export-CSV C:\TEMP\Software_Server.csv -Append}



