$usernames=@("ae13", "ae00")

$accounts=@()

foreach ($u in $usernames){
    $accounts+=get-aduser $u -Properties samaccountname,distinguishedname,name,SID,enabled,whencreated,accountexpires,lastlogon,lastlogontimestamp
}

foreach ($a in $accounts){
    $a | Add-Member -Force -MemberType NoteProperty -Name "LastLogonTimestampDate" -Value $(
        if ($null -eq $a.LastlogonTimestamp -or $a.LastlogonTimestamp -le 0 ){
            "Never" # never logged in
        }
        else {
            [datetime]::FromFileTime($a.LastlogonTimestamp).tostring('dd.MM.yyyy')
        }
        )

    $a | Add-Member -Force -MemberType NoteProperty -Name "LastLogonDate" -Value $(
        if ($null -eq $a.Lastlogon -or $a.Lastlogon -le 0 ){
            "Never" # never logged in
        }
        else {
            [datetime]::FromFileTime($a.LastlogonTimestamp).tostring('dd.MM.yyyy')
        }
        )

    $a | Add-Member -Force -MemberType NoteProperty -Name "LastLogonDate" -Value $(
        if ($null -eq $a.Lastlogon -or $a.Lastlogon -le 0 ){
            "Never" # never logged in
        }
        else {
            [datetime]::FromFileTime($a.LastlogonTimestamp).tostring('dd.MM.yyyy')
        }
        )

    $a | Add-Member -Force -MemberType NoteProperty -Name "AccountExpiresDate" -Value $(
        if ($null -eq $a.accountexpires -or $a.accountexpires -le 0 ){
            "Never" # never expiring
        }
        else {
            [datetime]::FromFileTime($a.accountexpires).tostring('dd.MM.yyyy')
        }
        )
}

$accounts | Select-Object -Property samaccountname,distinguishedname,name,SID,enabled,whencreated,AccountExpiresDate,LastLogonDate,LastLogonTimestampDate | out-gridview
