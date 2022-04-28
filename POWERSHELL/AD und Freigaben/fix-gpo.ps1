<#
Will try to fix gpo-permissions (ACL-SysVol)
based on: https://www.raytechnote.com/how-to-fix-gpo-sysvol-permissions-error/
It will ask if it should rewrite the permissions for Domain-Admins.
D. Maienhöfer, 04/2022
#>

param (
[String]$localsysvoldir="C:\Windows\SYSVOL_DFSR\sysvol\contoso.local\Policies", # local sysvol-policy-folder
[String]$admingroupname="contoso.local\Domänen-Admins", # the name of the domain-admin's group ("Domänen-Admins" in german)
[String]$policy="" # if you just want to modify a single GPO you may specify its GUID here
)

function rewrite_permissions{
    param (
    [String]$folder,
    [String]$admingroupname=""
    )
    Write-Warning ("Rewriting Folder-Permissions for `"" + $folder+ "`" `r`n")
    Write-Host "Removing group-permission"
    [String[]]$argus= $folder, "/remove:g", $admingroupname
    Start-Process -FilePath "C:\Windows\System32\icacls.exe" -ArgumentList $argus -Wait -PassThru
    
    write-host "Renewing group-permission"
    [String[]]$argus= $folder, "/grant", ($admingroupname+":(OI)(CI)(F)")    
    Start-Process -FilePath "C:\Windows\System32\icacls.exe" -ArgumentList $argus -Wait -PassThru
}

Write-Host "Checking for GPO-Directories"
$filter="{*"
if ($policy -ne ""){ # Policy has been specified, just look for this one    
    $filter="{"+$policy.TrimStart('{').TrimEnd('}')+"}"
    Write-Host ("Policy `""+$policy+"` has been specified. Will just look for `""+$filter+"`"...")
}
$policies=Get-ChildItem -Filter $filter -Directory -Path $localsysvoldir 

Write-Host ("Found " + $policies.Length + " Folders...")

$abort=$false
# iterate through all policies found
foreach($gpo in $policies){
    if ($abort) {
        break
    }
    write-host ("Do you wan't to rewrite the permissions for `"" + $gpo + "`" ?")
    $answer=read-host "(Y/N/A)"
    Switch ($answer){
        Y {rewrite_permissions $gpo.FullName $admingroupname }
        A { $abort=$true; Write-Host "Aborting..." }
        default {Write-Host ("Won't touch `""+$gpo+"`"`r`n")}
        
    }


}

# Replication
write-host ("Do you wan't to start replication?")
$answer=read-host "(Y/N)"
Switch ($answer){
        Y {
        Write-Host ("Starting replication`r`n")
        &repadmin /syncall
        &repadmin /syncall /AdePq
        }

        default {Write-Host ("Won't trigger replication.`r`n")}        
    }



exit 0
