$usr = $Env:USERNAME
Write-Host "Aktueller Benutzer:" $usr
Write-Host "-------------------"
$zahl = 0
    if ((Get-ADPrincipalGroupMembership "$usr" | ?{$_.Name -eq "Domänen-Admins"})){     "Domänen-Admins       = ok"}else{"Domänen-Admins       = muss noch vergeben werden";$zahl = 1}
    if ((Get-ADPrincipalGroupMembership "$usr" | ?{$_.Name -eq "Schema-Admins"})){     "Schema-Admins        = ok"}else{"Schema-Admins        = muss noch vergeben werden";$zahl = 1}
    if ((Get-ADPrincipalGroupMembership "$usr" | ?{$_.Name -eq "Organisations-Admins"})){     "Organisations-Admins = ok"}else{"Organisations-Admins = muss noch vergeben werden";$zahl = 1}