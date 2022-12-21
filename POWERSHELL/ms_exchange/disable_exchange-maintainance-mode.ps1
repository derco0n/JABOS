<#
Disable Exchange Maintainance Mode
#>
param(
$ServerName = "exchsrv1",
$SecondServer = "exchsrv2.eine.firma.local"
) 
  
Set-ServerComponentState $ServerName –Component ServerWideOffline –State Active –Requester Maintenance
Resume-ClusterNode –Name $ServerName
Set-MailboxServer $ServerName –DatabaseCopyAutoActivationPolicy Unrestricted
Set-MailboxServer $ServerName –DatabaseCopyActivationDisabledAndMoveNow $false
Set-ServerComponentState $ServerName –Component HubTransport –State Active –Requester Maintenance