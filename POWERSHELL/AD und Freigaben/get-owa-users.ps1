<#
Determines all OWA-Users and aggregates their AD-Userobject's properties
D. Maienhöfer, 2022/01
#>
param(
    [String]$outfile="C:\users\md00\Desktop\owa-users.csv"
)

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

function GetLastLogonDate ($timestamp){
    $myreturn = ""
    if ($null -eq $timestamp -or $timestamp -le 0 ){
        $myreturn = "Niemals" # War noch nie angemeldet
    }
    else {
        $myreturn = ([datetime]::FromFileTime($timestamp).tostring('dd.MM.yyyy'))
    }
    return $myreturn
}

function isGroupAccount ([String]$samaccountname){
    if ($samaccountname.Length -eq 4){
        # Username is not 4 chars long (eg. neo01) which indicates, this is a groupaccount
        return $false
    }
    else {
        return $true
    }
}

Write-Host "Enumerating Mailbox-users"
$owausers=Get-CASMailbox -ResultSize Unlimited | Where-Object { $_.OwaEnabled -eq $true} | Select-Object -Property samaccountname
Write-host ("Found " + $owausers.Count.ToString() + " mailboxes.")
[int]$iteration=0
foreach ($u in $owausers){
    $iteration+=1
    [int]$percs=100/$owausers.Count * $iteration
    $stat=$percs.tostring()+"% ("+$iteration.tostring()+"/"+$owausers.Count.tostring()+") completed."
    Write-Progress -Activity "Processing data..." -Status $stat -PercentComplete $percs

    $aduser=get-aduser -Identity $u.SamAccountname -Properties GivenName,SurName,Enabled,LastlogonTimestamp | select-object -Property GivenName,SurName,Enabled,LastlogonTimestamp
    
    #$u | Add-Member -MemberType NoteProperty -Name ObjectGUID -Value $aduser.ObjectGUID
    $u | Add-Member -MemberType NoteProperty -Name "Vorname" -Value $aduser.GivenName
    $u | Add-Member -MemberType NoteProperty -Name "Nachname" -Value $aduser.SurName
    $u | Add-Member -MemberType NoteProperty -Name "Account aktiviert" -Value $aduser.Enabled
    $u | Add-Member -MemberType NoteProperty -Name "Letzte Anmeldung am" -Value (GetLastLogonDate $aduser.LastlogonTimestamp)
    $u | Add-Member -MemberType NoteProperty -Name "Wahrscheinlich Sammelaccount" -Value (isGroupAccount $u.SamAccountname)
    
}
write-host ("Exporting to " + $outfile)
$owausers | Export-csv -encoding utf8 -notypeinfo -path $outfile -Delimiter ";"
Write-Host "All Done."

