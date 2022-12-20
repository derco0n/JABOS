<#
Dieses Skript ermittelt von einem oder allen Systeme der Domäne, die in den Windows-Diensten und geeplanten Aufgaben hinterlegten Benutzerkonten.
Dies ermöglicht eine Analyse hinsichtlich des Benutzerkontext bestimmter Dienste.

Das abfragende Benutzerkonto muss auf den Zielsystemen entsprechend berechtigt (RPC/Admin) sein.

D.Maienhöfer, 2022/04
#>
param(
    [Switch]$help=$false,
    [String]$computername="", # Der abzufragende Computername. Wenn nichts angegeben wird, dann wird versucht alle AD-Computer-Objekte abzufragen.
    [String]$accountname="",  # Der zu suchende Benutzername. Wenn nichts angegeben wird, dann werden Dienste mit beliebigem Benutzernamen gesucht. Wird etwas angegeben wird nach %WERT% gesucht
    [String]$exportdir="C:\temp", # Ausgabepfad (.csv). Standard "C:\temp"
    [Int]$waittimeout=90,  # Maximale Laufzeit (in Sekunden) eines Backgroundjobs
    [Int]$maxconcurrent=25 # Maximal gleichzeitge Background-Jobs
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function printHelp($name){
    # Gibt ein Hilfe aus
    $title = $("Verwendung `"" + $name + "`":")
    Write-Host $("`r`n" + $title)
    Write-Host $("#" * $title.Length)
    Write-Host "Sucht nach Diensten und geplanten Aufgaben, ermittelt deren Benutzerkonten auf einem oder allen AD-Computern und gibt das Ergebnis textuell und als .csv-Datei aus.`r`n"    
    Write-Host "Die Suche erfolgt mittels parallel ausgeführter Background-Jobs, was schneller ein Ergebnis liefert als eine sequenzielle Abarbeitung."
    Write-Host "Zur Abfrage der Dienste und Aufgaben werden entsprechende Berechtigungen auf den Zielsystemen benötigt. Empfehlung: Konto mit lokal administrativen Rechten."
    Write-Host $($name + " [-help] [-computername <COMPUTERNAME>] [-accountname <BENUTZERNAME>] [-exportdir <PFAD>] [-waittimeout <TIMEOUT>] [-maxconcurrent <CONCURRENT>]")
    Write-Host "`r`n`r`nOptionen:`r`n#########`r`n"
    Write-Host "-help: Zeigt diese Hilfe an."
    Write-Host "-computername: Wird ein Wert angegeben wird nur der benannte Host abgefragt. Wird kein Wert angegeben werden alle AD-Computer abgefragt."
    Write-Host "-accountname: Wird ein Wert angegeben werden nur Dienste ermittelt, deren Benutzerkontext dem angegebenen Wert entspreicht."
    Write-Host "-exportdir: Definiert den .csv-Datei-Ausgabeordner. Standard ist: `"C:\temp`"."
    Write-Host "-waittimeout: Definiert die maxmimale Wartezeit für einen Backgroundjob in Sekunden. Standard ist: `"90`"."
    Write-Host "-maxconcurrent: Definiert die maxmimale Anzahl paralleler Backgroundjobs. Standard ist: `"20`"."
    Write-Host "`r`n`r`nD.Maienhöfer, 2021/08`r`n"
}


# Main
[System.Collections.ArrayList]$resultset = @()  # Speichert den Gesamtergebnissatz

if ($help -eq $true){
    printHelp $MyInvocation.MyCommand.Name
    exit 1
}

if ($computername -eq ""){
    $allcomputers = Get-ADComputer -Filter "operatingsystem -like '*Windows*'" # get all Windows-Computers #"*"
}
else {
    $allcomputers = Get-ADComputer -Filter $("name -eq '" + $computername + "'")    # get a specific computer
    Write-Host ("Frage nur " + $computername + " ab.")
}

if ($allcomputers.Count -lt 1){
    Write-Warning "Abgebrochen: Es konnten keine Computerobjekte aus dem AD ermittelt werden. Geben Sie einen validen Wert mittels `"-computername`" an und versuchen Sie es erneut."
    exit 1
}
else {
    if ($allcomputers.Count -gt 1){
        Write-Host $("Gefundene Systeme: " + $allcomputers.Count )
    }
}

$lastresultcount=0
$counter=0
foreach($c in $allcomputers){    # Alle gefundenen Computerobjekte durchiterieren        
    $counter+=1 # Objektfortschritt zählen
    if ($allcomputers.Count -gt 1) {
        [int]$percs=100/$allcomputers.Count * $counter # prozentualen Fortschritt errechnen
        Write-Progress -Activity ("Systeme werden abgefragt "+$counter+"/"+$allcomputers.Count+" (Ergebnisse bisher: "+$lastresultcount+")...") -Status "$percs% Fortschritt:" -PercentComplete $percs # Fortschrittsbalken anzeigen
    }

   
    # Sicherstellen, dass nicht zu viele BackgroundJobs gleichzeitig Aktiv sind
    $activejobs=$($(Get-Job -State Running).Count + $(Get-Job -State Completed).Count)  # Alle fertigen und aktiven jobs ...
    $informed_maxjobs=$false
    while ($activejobs -ge $maxconcurrent){        
        Start-Sleep 0.2        
        if ($informed_maxjobs -ne $true){
            Write-Warning $("Es sind bereits " + $activejobs + " Background-Jobs aktiv. Warte auf freie Slots...")
            $informed_maxjobs=$true
        }   
        # Zwischenergebnisse holen
        $cjobs = Get-Job -State Completed # Alle abgeschlossenen Jobs ermitteln
        foreach ($job in $cjobs){
            if ($job.HasMoreData -eq $true){
                $jobresults=Receive-Job $job # Ergebnisse des aktuellen Jobs ermitteln

                # Ergebnisse der Jobs holen
                foreach ($j in $jobresults){
                    foreach($res in $j){
                        $null=$resultset.Add($res)
                    }
                }
                Write-Verbose $("Ergebnis von `""+ $job.Name + "`" erhalten")
                
                # Abgeschlossenen Job entfernen
                Write-Verbose $("Job: `"" + $job.Name + "`" wird entfernt.")
                $job | Stop-Job
                $job | Remove-job  
            }

                      
        }
        $activejobs=$($(Get-Job -State Running).Count + $(Get-Job -State Completed).Count)  # Alle fertigen und aktiven jobs erneut ermitteln ... 
    }
    if ($resultset.Count -gt $lastresultcount){
        #Write-Host $("Gesamtergebnisse bisher: " + $resultset.Count)
        $lastresultcount = $resultset.Count
        }

    # Neuen Job erzeugen
    Write-Host $("Erzeuge Background-Job ("+($(Get-Job).Count+1)+"/"+$maxconcurrent+") zur Abfrage von: " + $c.DNSHostName)
    Start-Job -Name $("Query: " + $c.Name) -ArgumentList $c,$accountname -ScriptBlock{
        # Übernahme der Argumente (im Threadscope)
        $c=$args[0]
        $accountname=$args[1]

        [System.Collections.ArrayList]$resultset = @()  # Speichert den Gesamtergebnissatz

        # Nachfolgend Hilfsmethoden zur Abfrage von Diensten und Tasks, welche im Thread-scope existieren müssen.
        function getScheduledTasks($username, $computername){
            #Write-Host $("Ermittle Aufgaben ("+$username+"@"+$computername+")")
            # Ermittelt die geplanten Aufgaben eines Zielsystems            
            $filter = "*"
            if ($username -ne ""){
                $filter=$filter + $username + "*"  # Filter for a specific username
            }        
            # get all scheduledtasks
            try {
                $tasks = get-scheduledtask -cimsession $computername
            }
            catch {
                Write-Warning ("Unable to get sheduled tasks from `""+$computername+"`". => " + $_)
            }

            [System.Collections.ArrayList]$taskresults = @()

            foreach ($t in $tasks){ # process each entry of tasks
                $principal = $t.principal
                if ($principal -notlike $filter){
                    # Skipping as the user of the current task doesn't match our filter
                    #Write-Warning ("`""+$principal + "`" doesn't match `"" + $filter +"`"") #DEBUG
                    continue
                }
                $t | Add-Member -Force -MemberType NoteProperty -Name "Computername" -Value $computername
                $t | Add-Member -Force -MemberType NoteProperty -Name "Name" -Value $($t.TaskPath + $t.TaskName)
                # check if pricipal is group, user or unknown
                if ($principal.GroupId){
                    $t | Add-Member -Force -MemberType NoteProperty -Name "RunAs" -Value $($principal.GroupId + " (Group)")
                }
                elseif ($principal.UserId) {
                    $t | Add-Member -Force -MemberType NoteProperty -Name "RunAs" -Value $($principal.UserId + " (User)")
                }
                else {
                    $t | Add-Member -Force -MemberType NoteProperty -Name "RunAs" -Value "Not found !"
                }          
                $t | Add-Member -Force -MemberType NoteProperty -Name "Type" -Value "Scheduled-Task"
                $null=$taskresults.Add($t);
            }
        
            return $taskresults
        }
        
        function getServices($username, $computername){
            # Ermittelt die Dienste eines Zielsystems    
            # Einen WMI-Filter setzen
            # Write-Host $("Ermittle Dienste ("+$username+"@"+$computername+")")
            $filter="STARTNAME LIKE '%'"
            if ($username -ne ""){  # Wenn der Accountname angegeben wurde...
                $filter = $filter.Substring(0,$filter.Length-1) + "%" + $username + "%'" # ... diesen für den Filter nutzen/vorbereiten
                } 
        
            $services = Get-WmiObject -ComputerName $computername -Class Win32_Service -filter $filter -ErrorAction Stop | Select-Object PSComputerName,Startname,Name #,State,Startmode # ... die Dienste des Zielsystems zu ermitteln        
            foreach ($sfound in $services){
                $sfound | Add-Member -Force -MemberType NoteProperty -Name "Computername" -Value $sfound.PSComputername
                $sfound | Add-Member -Force -MemberType NoteProperty -Name "RunAs" -Value $($sfound.Startname +" (User)")
                $sfound | Add-Member -Force -MemberType NoteProperty -Name "Type" -Value "Windows-Service"
            }
        
            return $services
            }

        # Erzeugt für jeden Host einen Background-Job wodurch die Abfragen parallelisiert durchgeführt werden
        try {
            # check if system is reachable
            [String] $toping="";
            if ($null -eq $c.DNSHostName){
                Write-Warning $("No DNSHostName for " +$c.Name + " !!")
                $toping=$c.Name
            }
            else {
                $toping=$c.DNSHostName
            }
            if (!(Test-Connection -BufferSize 32 -Count 1 -ComputerName $toping -Quiet)) {
                Write-Warning $($toping + " ist nicht erreichbar und wird übersprungen.")
                
            }
            else {
                # Versuchen ...
                # Write-Host $("Ermittle Dienste und Aufgaben von `"" + $c.name + "`" (" + $counter + "/" + (&{If($allcomputers.Count -gt 1) {$allcomputers.Count} else{"1"}}) + ")")    
                $c_services = getServices $accountname $c.name  # Dienste             
                $c_tasks = getScheduledTasks $accountname $c.name  # geplante Tasks
                
                
                if ($c_services.Count -ge 1){
                    # Wenn mehr als ein Dienst gefunden wurde
                    #Write-Host $("Anzahl auf `"" + $c.name + "`" gefundene Dienste: " + $c_services.Count)
                    $null=$resultset.AddRange($c_services) # den Teilergebnissatz (dieser Host) dem Gesamtergebnis (alle Hosts) hinzufügen
                }
                else {            
                    $null=$resultset.Add($c_services) # das Teilergebnis (dieser Host) dem Gesamtergebnis (alle Hosts) hinzufügen
                }
            
                if ($c_tasks.Count -ge 1){
                    #Write-Host $("Anzahl auf `"" + $c.name + "`" gefundenen geplanten Aufgaben: " + $c_tasks.Count)
                    $null=$resultset.AddRange($c_tasks) # den Teilergebnissatz (dieser Host) dem Gesamtergebnis (alle Hosts) hinzufügen
                }
                else {
                    $null=$resultset.Add($c_tasks) # das Teilergebnis (dieser Host) dem Gesamtergebnis (alle Hosts) hinzufügen
                }           
            }
            
        }
        catch {
            # ... Falls der Versuch fehlschlägt
            #Write-Warning $($Error[0].ToString() + " => Konnte die Daten von `"" + $c.Name + "`" nicht abrufen:`r`nFehlt eine Berechtigung? Ist das System erreichbar? Ist der RPC-Dienst aktiv?")
            #write-warning $_.Exception|format-list -force
        }    
        return $resultset
    } | Out-Null
   
}

Write-Host $("Warte auf Beendigung der verbleibenden Background-Jobs (max. " + $waittimeout + " Sekunden)")
$jobresults=Get-Job | Wait-Job -Timeout $waittimeout | Receive-Job  # Auf Beendigung aller Jobs warten und die Ergebnisse aggrerieren

# Ergebnisse der Jobs holen
foreach ($j in $jobresults){
    foreach($res in $j){
        $null=$resultset.Add($res)
    }
}
foreach ($job in $(Get-Job)){
    Stop-Job -Job $job
    Remove-Job -Job $job # remove the job
    write-host $("Job: `"" + $job.Name + "`" wurde entfernt.")
}

# Ergebnisse aggerieren
Write-Host $("Ergebnissatz (Anzahl: " + $($resultset.Count) + "): ")
if ($resultset.Count -gt 0) {
    $sorted = $resultset | Select-Object -Property Computername,Name,RunAs,Type | Sort-Object -Property ComputerName,Type,RunAs,Name # Ergebnisse nach Computername und Benutzername sortieren

    #$sorted | Format-Table # Ausgabe auf der CLI

    $outfilepath = $exportdir.Trimend('\') + "\service_users__" + (&{If($accountname -eq "") {"all-users"} else {$accountname}}) + "-on-" + (&{If($allcomputers.Count -gt 1) {"all-computers"} else {$computername}}) + ".csv"
    $sorted | Export-Csv -Path $outfilepath -NoTypeInformation # Export in csv-Datei
    Write-Host $("Daten wurden exportiert nach: `"" + $outfilepath + "`"")

    $sorted | Out-GridView # Anzeige der Ergebnisse in einer GridView
}

exit 0
# SIG # Begin signature block
# MIITYwYJKoZIhvcNAQcCoIITVDCCE1ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJ0OmP28uOi1/zpD2lfK/0whF
# FUWggg/XMIIHeTCCBWGgAwIBAgIKGCSiEAAAAAAAAjANBgkqhkiG9w0BAQsFADAU
# MRIwEAYDVQQDEwlQT1JUQUwtQ0EwHhcNMTUxMTAzMDcxNDQxWhcNMjUxMDMwMDgy
# MjU4WjBHMRMwEQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9y
# dGFsMRgwFgYDVQQDEw9QT1JUQUxQS0ktU3ViQ0EwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCgICeRIo2o073jRxKD2z7YKixgeTQ2UCyI7BJUWdlcDqUF
# R1xWyEIEMdU49/VykdV0kZ3axtTsPEBGS+Ce6QVtHRt7QKoz6vn9UHsBLJmSG9XE
# VHLo2X7dGZSs71KYiPVP3LP+4/Zok2xR69N3IXsrGzsXIbBAtWE4Rk22kwyGzSVt
# 7s0ozfh26bvkX8SpjD4pyjEmoY24PNYg05US4gNDpwDjCZiqy/9OFgztmIzn6lng
# sK8ZYCbnPt6w8bCO7cuF+ffaPSCH7wijZRbCG2+FrkwyVwQIElpx4fpizkys+qG4
# rWGsyOf+8LlfJYzWGVIySKqYd1aEf+fCtS5jXy9MXb49eiXFtuSmtPbYGcMEIq9I
# SdrvbecUQxJjMngN8Y0EN1hmYngPBJh5RiK5RK+DN0gPUPfXYAviGbht91AEhk+O
# aacLkCtiX/oARBjiIH0d8MW5OC7TsOt3aJT48HXwJ9qkzoa37SFeX8tz0O3gjP3/
# AAntxvieWEeAL35NeUaKOgdEFwMS33LLefICxpyjd5KwV+PJc1TFNFwglLhiY4IX
# s12Sd9xlaDYMIkyaWaWmYDVluFk/i8lJ0I90aFTU0EzDFw2graqa1B8JoXnn31XE
# 1D+exvXKa7y1MWPYy3xUixoF1MYyV8qGEu0DGzWOLOaQbW7pGL5mfq09xq2kYwID
# AQABo4ICmDCCApQwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFHWW1PEdWYel
# TIyUQfasdpPFfrxPMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQE
# AwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFO6zQpTRmjvL3g0mN9kQ
# G903+ql+MIH9BgNVHR8EgfUwgfIwge+ggeyggemGgbBsZGFwOi8vL0NOPVBPUlRB
# TC1DQSxDTj1wb3J0YWxjYSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1wb3J0YWwsREM9a2xn
# P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxE
# aXN0cmlidXRpb25Qb2ludIY0aHR0cDovL3BvcnRhbGNhLmtsaW5pa3VtLWxpcHBl
# LmRlL2NlcnQvUE9SVEFMLUNBLmNybDCCAQUGCCsGAQUFBwEBBIH4MIH1MIGnBggr
# BgEFBQcwAoaBmmxkYXA6Ly8vQ049UE9SVEFMLUNBLENOPUFJQSxDTj1QdWJsaWMl
# MjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERD
# PXBvcnRhbCxEQz1rbGc/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNl
# cnRpZmljYXRpb25BdXRob3JpdHkwSQYIKwYBBQUHMAKGPWh0dHA6Ly9wb3J0YWxj
# YS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L3BvcnRhbGNhX1BPUlRBTC1DQS5jcnQw
# DQYJKoZIhvcNAQELBQADggIBAGG0fbbWhQxJwIXevUVL0DZZGXRIpPlwXQ6iy+yk
# CmyfOGJL2/HO45r7fRJBc2hOdEHDeZUPcLcPlCryburUb/wwV0ww66/EcHG06B3L
# seG5dUw3BB81edzJV9jEoOEYhPuHDUep2lWPmWF2yo40O8l600EeUKymg4gh2aKT
# F6DrpOahHeDaiZ50mjfFqJmmY3ed0nYSZcMF69dAQd24VVUmLnFeLhd2kwgL3Fei
# AImiSGNVoBJipuZy6LOWmu1mhPy31Yxbss8XYWcoRGf8WCB+2Uk1FJh16fw12vZk
# 70Nuj25AVBb9DoASsg3rvvsw0v4znPFRqFpQT6uBgo6kkAW0FlwVW/95I+2QkjkX
# nvwG+4Zl+qNyLicM4ydwLYZbnDka5xQp4HFqjUkCFde8gWogS4rGQpJFYlQ5Tj63
# 1G83vZFNyOrH1m9aJGudSGSBNzs6Djcr/h8sDe1TCJcXDRlhmDZxAogUB66oAgmL
# SP9/joRDo9EOMIbIbRra5Su3rn+72T3p6N2riedP+yiCfcSVg8fJLlsuO9zSsWHI
# 3qS/8W725GqN+TgFdSDtJRTQDnqwK9i9okRsRvyUvf8ZUlpYu4N7euytn1jecNfx
# Lbqn+/0MkXzrUksh04QKaD5voIbhVplucw6jPZi9BOtLtWIatGnbifshjg7qnBhq
# jb6XMIIIVjCCBj6gAwIBAgIKdox2awAAAAABAjANBgkqhkiG9w0BAQsFADBHMRMw
# EQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9ydGFsMRgwFgYD
# VQQDEw9QT1JUQUxQS0ktU3ViQ0EwHhcNMjEwNzI4MTE0MTU4WhcNMjMwNzI4MTE0
# MTU4WjBfMRMwEQYKCZImiZPyLGQBGRYDa2xnMRYwFAYKCZImiZPyLGQBGRYGcG9y
# dGFsMRowGAYDVQQLExFDZXJ0aWZpY2F0ZU93bmVyczEUMBIGA1UEAxMLRGVubmlz
# IE1hcngwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCh5XFP9+zJtf+l
# GHEgT22YIWTH1+g3Go/Yel5gP7Hfvs0CsunHUilVBR+Ksdzn8/3/rhcBao0itKVb
# qoDptUzoWVGIqYnZsK1kEcdwbbo9BfDnwvYlXI39AaSfYMIh33dLyTg5lhHNRXN+
# xOJs5CnnuWKw4SkFcC8Bzn7LSClxZ8d9Xq8vVFaiAr/VXyhaqTdhj6Klutm+Idcq
# 3BDWxJ3eD8KiqyuHjDfmIZvQFcQvbgMyZ0PwXzwtnKsAdzxIcHVBSQ1fu+T91KhL
# MBxxHEmrkbmJCnhdAcAypzy6kEgep1pu+OmVMVnOGnkdFqyu62jhz7LJ5narfBAY
# AIkjRKO1ue+GbzkOy+SUpSkHWPxm/zJnRmmlwMN/GBJawVw+fZ2IRKraMgFWHFw2
# fPizduo3QvJGYBqooeJpG8OswqIqJJVKuo8ax1O1bC6swx7G9o/HFx3lCCLHTM9R
# XbVSK/nSv8K8OK5ZRkL8L8JwWicpxk32DdaQ4VdJXMSm/eKPjE3DJPYxhwkFRSDK
# /bEvH/IzyUOIJVBUO3TkaEgOcMLCi8l5+75oayoftpmIUMHov3RnmW3sittS7Ukq
# 9BGhjbAU7khOAc9lr/pOTNabEc+45tPFyLw0GvCO0rwWwsi9vNJOFLmr4CAdMMJ+
# ebeSnTp4HQ+koJ1nr1sCMk8yH7lJcQIDAQABo4IDKjCCAyYwDgYDVR0PAQH/BAQD
# AgeAMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIPX9naGsug5hfGDJIOW/xWx
# pzyBFoKdyCqDp5JsAgFkAgECMB0GA1UdDgQWBBSLAVwySO9uZJxstCzJMKL8jPpp
# 0DAfBgNVHSMEGDAWgBR1ltTxHVmHpUyMlEH2rHaTxX68TzCCAQsGA1UdHwSCAQIw
# gf8wgfyggfmggfaGgbdsZGFwOi8vL0NOPVBPUlRBTFBLSS1TdWJDQSxDTj1QT1JU
# QUxQS0ksQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
# Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9cG9ydGFsLERDPWtsZz9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnSGOmh0dHA6Ly9wb3J0YWxjYS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L1BP
# UlRBTFBLSS1TdWJDQS5jcmwwggEfBggrBgEFBQcBAQSCAREwggENMIGtBggrBgEF
# BQcwAoaBoGxkYXA6Ly8vQ049UE9SVEFMUEtJLVN1YkNBLENOPUFJQSxDTj1QdWJs
# aWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9u
# LERDPXBvcnRhbCxEQz1rbGc/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNz
# PWNlcnRpZmljYXRpb25BdXRob3JpdHkwWwYIKwYBBQUHMAKGT2h0dHA6Ly9wb3J0
# YWxjYS5rbGluaWt1bS1saXBwZS5kZS9jZXJ0L1BPUlRBTFBLSS5wb3J0YWwua2xn
# X1BPUlRBTFBLSS1TdWJDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYJKwYB
# BAGCNxUKBA4wDDAKBggrBgEFBQcDAzAxBgNVHREEKjAooCYGCisGAQQBgjcUAgOg
# GAwWZGVubmlzLm1hcnhAcG9ydGFsLmtsZzANBgkqhkiG9w0BAQsFAAOCAgEAiSVu
# 6t4iy5fEJLpXB+uU6SttnBS3+OyMdkHbnOXivlXqyPGSyWFf03wxCPxfBSrHRyiO
# RuklEB2f7SiYIJ21IEZqbfTRIyvJHBZWkx3DP6NOgDuu0YfZKOtiplELxn1435DS
# bn2mr4sHjaX4gjBofHcUTp1NmRoGl8diWUTJsoGwQRgUnoyvTfrJj6i9LDQgEonj
# uq0zNCsDYTsgVC7XsFbIIxF0/R6W7ol2xFtVmGP0Wx34DRNTuACk5HHeGy2kCYYq
# 0SDYHwhHna2IZ9PWyjlzBwY7o9TBpaHsfJeB7k/sWJ8SZ2dReG6oTH36NMkYmIwN
# 6R45q7fU4g5uVeB0T7EKdbb3YmkwRhd0TKPtPYgXgR2EQmmQsflFgc76fkxey014
# R47BycJoY50XL/1rad+TwlTcJv6sTzQwyqwaiyWfgGBlFUdxqPbjqTWQnJoNtJhE
# rm442DSgfeBoUl6ZEVLp9w+E66kADBP4qZ2LCcbvmhAt+xzyUpTxdcCVYhVBY7wf
# KK2h6WWff8iBOrOxw1/V0p9JmBpaqnzaAE4/3bMIlurm9SUT3A6BZoSQdRPr/pnf
# XqfwfhO9uYvrgSJGC5ec/Nw9TPfQtBrpejy11Nuh//ZK/Y6NeT51WQG0wINPqV6u
# MJrIsqGlvj3K1Vae9CNgy8vI42bnnwn2dwrSCFkxggL2MIIC8gIBATBVMEcxEzAR
# BgoJkiaJk/IsZAEZFgNrbGcxFjAUBgoJkiaJk/IsZAEZFgZwb3J0YWwxGDAWBgNV
# BAMTD1BPUlRBTFBLSS1TdWJDQQIKdox2awAAAAABAjAJBgUrDgMCGgUAoHgwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU
# HyJRVi58KTyGlSFR+mMzmBbAmBQwDQYJKoZIhvcNAQEBBQAEggIAYn3rCK9ZmU+q
# tEuV7waKv4UqBbPhgrPfGHgsitePEnACf+EQWRWH9DaHIXdefrdQJs41p4CNGG6UL
# ZoK4sYUtGhF6PJvXDZ5a5BWpylR5mm5RLsP8Ydf2IRZmnKtoh9x/WthSlLva2vWc
# 9kM0/s0I3EyH2rVIEySRNzrKUBBBtHfFCmQzsw0/9diEBWz6K7R4jDSaUCYCDEvH
# pxr76K7odNpPpBWM2EG9or1kJl6OekBN1aGtOUYOXCy2d7G6xBefJdhYb+vN4ebk
# KuWzTfyGQHiTxWos9PW8IVzwv0ZgXWLp1efI5QeJ2gvtxpY+3RANYsl2ZFrYPm2X
# lQnpRQFmunRp0N5Y7OFZ2YQ7b6xS09P8M1O8fKBqBRaEhAo7mJjiagRu354HM5dJ
# jQUmw76vfZyLlhbMoRCvvS7+Gm5OwHitBGrJfRhzlVkyKsREX4aJhb2UzAVy5pxr
# 1Vqhu77tk4rB/Nr6aJHcLSgEfkbNdX/V66TVqHksite/CTdTSS4FxZdcHLGTWA0KP
# ln8UZlpStb+vt9dlRd0RIGAcjRsMoiry0XXooVAF6B5y8CxITmyU3+JLt+UD8cEM
# ST0cF1zLon1Xe9NXkRu7YiXlvqkZCLiGrL82I0VpAiCGceHao4rYG/xr6IuPPSFr
# aPB8q96ySUcCSFXhbRbf5qm8ccI+okU=
# SIG # End signature block
