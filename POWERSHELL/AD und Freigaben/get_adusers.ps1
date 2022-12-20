 $users=Get-ADUser -Filter * -Properties samaccountname,name,manager,enabled,whencreated,lastlogontimestamp,department,description,comment | Where-Object {$_.enabled -eq $true} | select-object -property samaccountname,name,manager,department,description,comment
 foreach ($u in $users){
    if ($null -ne $u.manager) {
        $mgr=Get-ADUser $u.manager
        $manager=$mgr.name + " ("+$mgr.samaccountname+")"
    }
    else {
        $manager=""
    }
    $u | Add-Member -MemberType NoteProperty -name Managername -value $manager
 }

 $users | select-object -property samaccountname,name,Managername,department,description,comment | export-csv "c:\temp\ad-users.csv" -NoTypeInformation -Encoding utf8 -Delimiter ";"