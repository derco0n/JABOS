
<#
Will retrieve a list of computers and users currently logged in on them.
Requieres WinRM and Permissions to query them.
D. Maienhöfer, 2022/02
#>
param ($outfile="C:\temp\computer_user.csv")

$Computers =  Get-ADComputer -Properties Name,OperatingSystem,Enabled -Filter {(enabled -eq "true") -and (operatingSystem -Like "*Windows*") -and (operatingSystem -Notlike "*Server*")} #| Select-Object -ExpandProperty Name
$output=@()
$counter=0
ForEach($PSItem in $Computers) {
    $counter+=1
    if ($Computers.Count -gt 1) {
        [int]$percs=100/$Computers.Count * $counter
        Write-Progress -Activity ("Querying `"" + $PSItem.Name + "`" ("+$PSItem.OperatingSystem+") "+$counter+"/"+$Computers.Count+"") -Status "$percs% Progrss:" -PercentComplete $percs
    }    
    $User = Get-CimInstance Win32_ComputerSystem -ComputerName $PSItem.Name -OperationTimeoutSec 2 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty UserName
    write-host ("User for `""+$PSItem.Name+"`" is `""+$User+"`".")
    $Obj = New-Object -TypeName PSObject -Property @{
            "Computer" = $PSItem.Name
            "User" = $User
        }
    $output+=$Obj    
    }

$output | Out-File $outfile
$output | Out-GridView

