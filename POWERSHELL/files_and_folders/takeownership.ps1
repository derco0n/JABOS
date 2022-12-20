<#
Takes ownership of a directory structure with long path names
D. Maienhöfer, 2021/11
#>

param (
    [String]$path="\\?\UNC\sitefas1\user\zzz_mb03",
    [String]$newowner="site\md00",
    [Switch]$recurse=$true
)

$acl=get-acl $path
Write-Host "Current ACL"
$acl | format-table
$owner=New-Object System.Security.Principal.NTAccount($newowner)
#$owner=New-Object System.Security.Principal.NTAccount("site", $newowner)
#$acl.SetOwner($owner)
$acl.SetAccessRuleProtection($false, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
$ace = New-Object Security.AccessControl.FileSystemAccessRule($newowner, "FullControl", "ContainerInherit,ObjectInherit", "InheritOnly", "Allow")
$acl.AddAccessRule($ace)
Write-Host "Writing new ACL"
try{
    Set-Acl -LiteralPath $path -AclObject $acl
    if ($recurse){       
        
        
    }
    
}
catch {
    Write-Warning "Can't set and check ACL!"
    exit 1
}


exit 0