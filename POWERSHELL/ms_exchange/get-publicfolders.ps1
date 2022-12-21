<#
This will enumerate all public folders and their user-permissions.
D. Maienhöfer, 2022/11
#>
param (
    $outfile="C:\temp\PublicFolders_and_Permissions.csv"
)
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn
$Result=@()
$allFolders = Get-PublicFolder -Recurse -ResultSize Unlimited
$totalfolders = $allFolders.Count
$i = 1 
$allFolders | ForEach-Object {
    $folder = $_
    Write-Progress -activity "Processing $folder" -status "$i out of $totalfolders completed"
    $folderPerms = Get-PublicFolderClientPermission -Identity $folder.Identity    
    $folderPerms | ForEach-Object {        
        [String]$permissions=""
        $_.AccessRights | ForEach-Object {        
                $permissions=$permissions+$_+", "
                }
        $permission=$permissions.Trim()
        $permission=$permissions.TrimEnd(',')

        $Result += New-Object PSObject -property @{ 
            Folder = $folder.Identity
            User = $_.User        
            Permissions = $permissions
            }
    }
    $i++
}
$Result | Select Folder, User, Permissions | Export-CSV $outfile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
