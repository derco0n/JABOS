<#
Will sign a script, exe or dll
#>
param (
    $file=$null
    )
if ($null -eq $file){
    Write-Warning "Please specifiy a file to sign"
    exit 1
}

#Get-certificate
$cert=Get-ChildItem cert:\CurrentUser\my -codesigning
try {
    Set-AuthenticodeSignature $file $cert
}
catch {
    Write-Warning ("Error while signing `""+$file+"`"")
    exit 2
}

Write-Host ("Successfully signed `""+$file+"`"")
exit 0

