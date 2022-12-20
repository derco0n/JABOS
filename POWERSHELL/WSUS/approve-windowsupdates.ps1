<#
This will approve updates which are already approved in one source-group to a bunch of other target-groups
As there's at least one group whcih gets updates automatically, this can be utilized to fetch all of those updates and approve them for the rest of the groups.


D.Marx, 08/2021

Last Edit: 31.08.2021
#>

param(
    #[Switch]$dryrun = $true,  # simulate, dont approve any update
    [Switch]$dryrun = $false,  #approve updates
    $WsusServerFqdn='localhost',
    $logfile="C:\temp\wsus-approval.log",
    $WsusSourceGroup = 'VorabTestGruppe PCs_komplett_automatisch',
    $WsusTargetGroups = @('Unassigned Computers', 'PCs_IT_Win10', 'PCs_komplett_automatisch', 'PCs_manuell_installieren', 'PCs_mit_Windows_10_20H2-Update', 'Server_komplett_manuell')
)

if ($dryrun) {
    Write-Host ("This will check for updates, which are approved for install in `"" + $WsusSourceGroup + "`" and will simulate an approval for the following groups:")
}
else {
    Write-Warning ("This will check for updates, which are approved for install in `"" + $WsusSourceGroup + "`" and will approve them for the following groups:")
}
foreach ($gr in $WsusTargetGroups){
    Write-host $gr
}

date | out-file -Encoding utf8 $logfile -append

#[void][reflection.assembly]::LoadWithPartialName( "Microsoft.UpdateServices.Administration")
#$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer( $WsusServerFqdn, $False, ‘8530’)
$wsus = Get-WsusServer -Name $WsusServerFqdn -PortNumber 8530
$Groups = $wsus.GetComputerTargetGroups()
$WsusSourceGroupObj = $Groups | Where {$_.Name -eq $WsusSourceGroup}
if ($null -eq $WsusSourceGroupObj){
    Write-Warning ("Sourcegroup `"" + $WsusSourceGroup + "`" not found! Aborting.")
    exit 1
    }


$WsusTargetGroupObjs=@()
foreach ($WsusTargetGroup in $WsusTargetGroups){
    $GroupObj = $Groups | Where {$_.Name -eq $WsusTargetGroup}
    if ($null -eq $GroupObj){
        Write-Warning ("Targetgroup `"" + $WsusTargetGroup + "`" not found! Aborting.")
        exit 2
        }
    $WsusTargetGroupObjs += $GroupObj
    }


$updatecounter = @()  # holds counters for approved updates

ForEach ($WsusTargetGroupObj in $WsusTargetGroupObjs) {  # create an counter-object for each target-group
        $updatecounter +=  New-Object -TypeName PSObject -Property @{
            TargetGroup = $WsusTargetGroupObj.Name
            ApprovedUpdates=0
            }
    }

Write-Host "Gathering source-group approvals. This might take a while. Please wait ..."
$UpdateScope=New-Object Microsoft.UpdateServices.Administration.UpdateScope
$UpdateScope.ApprovedStates="Any"
$null=$updateScope.ApprovedComputerTargetGroups.Add($WsusSourceGroupObj)
$Approvals = $wsus.GetUpdateApprovals($UpdateScope)    
$WsusSourceGroupObj | Add-Member -Name Approvals -MemberType NoteProperty -Value $Approvals -Force
Write-Host ("Found " + $WsusSourceGroupObj.Approvals.Count + " approvals for source-group `"" + $WsusSourceGroupObj.Name+"`"")

Write-Host "Gathering target-group approvals. This might take a while. Please wait ..."
ForEach ($WsusTargetGroupObj in $WsusTargetGroupObjs) {  # iterate through all target group
    $UpdateScope=New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $UpdateScope.ApprovedStates="Any"
    $null=$updateScope.ApprovedComputerTargetGroups.Add($WsusTargetGroupObj)
    $Approvals = $wsus.GetUpdateApprovals($UpdateScope)    
    $WsusTargetGroupObj | Add-Member -Name Approvals -MemberType NoteProperty -Value $Approvals -Force
    Write-Host ("Found " + $WsusTargetGroupObj.Approvals.Count + " approvals for target-group `"" + $WsusTargetGroupObj.Name+"`"")
    }



Write-Host "Gathering Updates. This might take a few minutes. Please wait..."
#$Updates = $wsus.GetUpdates() | Where-Object {$_.IsApproved-eq $true -and $_.PublicationState -eq "Published"-and $_.IsSuperseded -eq $false}  # get all wsus-updates, which are not superseded, not revoked (by the publisher) and approved in at least one group
$Updates = Get-WsusUpdate -UpdateServer $WSUS -Approval Approved -Status Needed | ? UpdatesSupersedingThisUpdate -eq "None" # get all wsus-updates, which are needed, not superseded and approved in at least one group
write-host ("Found " + $Updates.Count.ToString() + " Updates that might be needed.`r`n")
$counter=0

ForEach ($Update in $Updates) {  # iterate through all updates found 
    # show some stats
    $counter+=1
    [int]$percs=100/$Updates.Count * $counter
    Write-Progress -Activity "Processing possible Updates..." -Status "$percs%" -PercentComplete $percs -CurrentOperation $Update.Update.Title

    # check if update is approved in source-group
    $approvedinsource=$false
        foreach ($appr in $WsusSourceGroupObj.Approvals){
            if ($appr.UpdateId.UpdateId -eq $Update.UpdateId){
                # Update is approved in source-group
                Write-Verbose ("`"" + $Update.Update.Title + "`" is approved in `"" + $WsusSourceGroupObj.Name + "`".")
                ("`"" + $Update.Update.Title + "`" is approved in `"" + $WsusSourceGroupObj.Name + "`".") | out-file -Encoding utf8 $logfile -append
                $approvedinsource=$true
                break
            }
        }  

    ForEach ($WsusTargetGroupObj in $WsusTargetGroupObjs) {  # iterate through all target group
        $isneeded = $approvedinsource
        #Check if the update is needed in this group 
        foreach ($appr in $WsusTargetGroupObj.Approvals){
            if ($appr.UpdateId.UpdateId -eq $Update.UpdateId){
                # Update is already approved in target-group. no need to approve it again
                Write-Verbose ("`"" + $Update.Update.Title + "`" is already approved in `"" + $WsusTargetGroupObj.Name + "`". No need to approve again.")
                $isneeded=$false
                break
                }
            }
        
        if ($isneeded) { # if update is needed.               
            Write-Verbose ("`"" + $WsusTargetGroupObj.Name + "`" needs `"" + $Update.Update.Title + "`"")
            foreach ($uc in $updatecounter){ # increment the counter for the current targetgroup....
                if ($uc.TargetGroup -eq $WsusTargetGroupObj.Name){
                    $uc.ApprovedUpdates+=1
                    break
                    }
                }            
            
            ("Will approve `"" + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ") for `"" + $WsusTargetGroupObj.Name + "`"") | out-file -Encoding utf8 $logfile -append

            if ($dryrun -eq $false){
                # not a dry-run. really approve updates!
                Write-Host ("Approving `"" + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ") for `"" + $WsusTargetGroupObj.Name + "`"")                
                #Approve-WsusUpdate -Update $Update.Update -Action Install -TargetGroupName $WsusSourceGroupObj
                $Update.Update.Approve(‘Install’,$WsusTargetGroupObj) | Out-Null  # approve the current update, for the current target-group
                }
            else {
                Write-Host ("DRYRUN: Would approve `"" + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ") for `"" + $WsusTargetGroupObj.Name + "`"")
                }
            }
        else {
            Write-Verbose ($WsusTargetGroupObj.Name + " doesn't need " + $Update.Update.Title)
            }
        }
}

Write-Host "`r`nApprovals:"
foreach ($uc in $updatecounter){
    Write-Output (“{0} updates for target group `"{1}`".” -f $uc.ApprovedUpdates, $uc.TargetGroup)
}

# Decline all superseded updates
Write-Host "`r`nGathering all superseded updates. This might take a while. Please wait."
$toremove=Get-WsusUpdate -UpdateServer $WSUS -Approval AnyExceptDeclined -Status InstalledOrNotApplicable | ? UpdatesSupersedingThisUpdate -ne "None"




Write-host ("`r`nWill decline " + $toremove.count + " superseded updates.")
foreach($rem in $toremove){
    ("Will decline `"" + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ")") | out-file -Encoding utf8 $logfile -Append

    if ($dryrun -eq $false){
        Write-Warning ("Declining " + + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ")")
        Deny-WsusUpdate -Update $rem
        }
    else {
        Write-Host ("DRYRUN: Would Decline " + $Update.Update.Title + "`" (ID: " + $Update.UpdateId + ", Release: " + $Update.Update.ArrivalDate + ", Superseded: " + $Update.Update.IsSuperseded + ")")
        }
    }

if ($dryrun -eq $false){
    # WSUS-Cleanup
    Write-Host "`r`nPerforming WSUS-Cleanup"
    $wsus | Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupObsoleteUpdates
}


Write-Host "`r`nDone."

exit 0