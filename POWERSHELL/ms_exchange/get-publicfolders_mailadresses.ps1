$pfolders=Get-MailPublicFolder | select-object displayname,EmailAddresses 
$res=[System.Collections.Arraylist]::new()

foreach ($pf in $pfolders){

    $addr=""
    foreach ($m in $pf.EmailAddresses){
        $addr+=$m.SmtpAddress+", "
    }
    $pf | add-member -MemberType NoteProperty -name Addresses -Value $addr

    $null=$res.add($pf)

}

$res | select-object -property DisplayName,Addresses | export-csv -Encoding utf8 -NoTypeInformation -Delimiter ";" -Path C:\temp\publicfolder-mailboxes.csv