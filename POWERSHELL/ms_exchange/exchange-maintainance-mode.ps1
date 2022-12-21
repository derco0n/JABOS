<#
Exchange Maintainance Mode
#>
param(
$ServerName = "exchsrv1",
$SecondServer = "exchsrv2.eine.firma.local"
) 
 
Set-ExecutionPolicy Unrestricted
Read-Host "Press enter to continue..."

Set-ServerComponentState $ServerName –Component HubTransport –State Draining –Requester Maintenance
Redirect-Message -Server $ServerName -Target $SecondServer
Read-Host "Press enter to continue..."
 
 
Suspend-ClusterNode –Name $ServerName
Set-MailboxServer $ServerName –DatabaseCopyActivationDisabledAndMoveNow $true
Set-MailboxServer $ServerName –DatabaseCopyAutoActivationPolicy Blocked
Read-Host "Press enter to continue..."
 
 
Get-MailboxDatabaseCopyStatus -Server $ServerName | Where {$_.Status -eq "Mounted"}
Read-Host "Press enter to continue..."
 
 
Set-ServerComponentState $ServerName –Component ServerWideOffline –State InActive –Requester Maintenance
Read-Host "Press enter to continue..."