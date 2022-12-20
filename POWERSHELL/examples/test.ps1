 $filter = "*"
if ($username -ne ""){
    $filter=$filter + $username + "*"  # Filter for a specific username
}
        
# Da die Felder je nach Sprachversion des Betriebssystems unterschiedlich benannt sind, frag wir deutch und englisch ab...    
$tasks = $(schtasks.exe /query /s "localhost"  /V /FO CSV | ConvertFrom-Csv | Where-Object { $_.Hostname -ne "Hostname" }) #| Select-Object hostname,Aufgabenname,{Als Benutzer ausf�hren} #,"Anmeldemodus","Letzte Laufzeit","Autor","Auszuf�hrende Aufgabe","Kommentar"
#$tasks += $(schtasks.exe /query /s $computername  /V /FO CSV | ConvertFrom-Csv | Where { $_.Hostname -ne "Hostname" -and $_."Run As User" -like $filter }) select hostname,Aufgabenname,"Run As User","Anmeldemodus","Letzte Laufzeit","Autor","Auszuf�hrende Aufgabe","Kommentar"
        
foreach ($t in $tasks){
    $t | get-member
    $t | Add-Member -Force -MemberType NoteProperty -Name "Computername" -Value $t.hostname
    $t | Add-Member -Force -MemberType NoteProperty -Name "Name" -Value $t.Aufgabenname
    $t | Add-Member -Force -MemberType NoteProperty -Name "User-Context" -Value $t.{Als Benutzer ausführen}
    $t | Add-Member -Force -MemberType NoteProperty -Name "Type" -Value "Scheduled-Task"
}

$tasks | select-object -Property Name,Computername,User-Context,Type | ft