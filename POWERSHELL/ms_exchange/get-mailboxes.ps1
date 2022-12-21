<#
This will enumerate the number of active (user/shared) mailboxes.
D. Maienhöfer, 2022/09
#>
param (
    $outfile="C:\temp\mailboxes.csv"
)
Add-PSSnapin *Exchange*


Write-Host "Looking up mailboxes"
$mailboxes=Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox,SharedMailbox
$count=0

foreach($box in $mailboxes){
    $count+=1
    $percentage=100/$mailboxes.Count*$count
    Write-Progress -Activity ("Processing "+$box.samaccountname + "("+$box.name+") - "+$percentage+"%") -PercentComplete $percentage -Status ($count.ToString() + "/" + $mailboxes.Count.ToString())
    $username=$box.samaccountname
    try {
        $aduser=get-aduser -identity $username -Properties name,enabled,mail,pwdLastSet

        $box | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $aduser.enabled
        $box | Add-Member -MemberType NoteProperty -Name "Mailaddress" -Value $aduser.mail

        $box| Add-Member -Force -MemberType NoteProperty -Name "LastPasswordChange" -Value $(
            if ($null -eq $aduser.pwdLastSet -or $aduser.pwdLastSet -le 0 ){
                "Never" # never changed PW
            }
            else {
                ([datetime]::FromFileTimeUtc($aduser.pwdLastSet)).tostring('dd.MM.yyyy')                
            }
        )
        
        }
    catch {
        Write-Warning $_
    }    
    try {
        $stats=($box | get-mailboxstatistics)
        $box | Add-Member -MemberType NoteProperty -Name "Lastlogon" -Value $stats.lastlogontime
    }
    catch {
    }    
}

$mailboxes.count

$mailboxes | Select-Object -Property name,Mailaddress,Enabled,Lastlogon,LastPasswordChange | export-csv -Path $outfile -Encoding UTF8 -NoTypeInformation -Delimiter ";"