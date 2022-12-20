<#
Ermittelt auffällige AD-Benutzerkonten und exportiert diese in csv-Dateien.
Auffällig ist:
- Lange nicht mehr angemeldet
- Noch nie angemeldet
- Admincount > 0, was bedeutet dass das Konto mindestens einmal administrative Rechte hatte (http://www.selfadsi.de/ads-attributes/user-adminCount.htm)
- Mitgliedschaft in sicherheitskritischen Gruppen

Es werden alle gefundenen DC's abgefragt und die entsprechenden Werte aggregiert:
- Letzte Anmeldung: 
    - https://www.active-directory-faq.de/2021/01/lastlogon-vs-lastlogontimestamp/
        - LastLogon gibt an, zu welchem Zeitpunkt sich ein Nutzer an einem bestimmten Domain Controller angemeldet hat
        - LastLogonTimestamp gibt hingegen an, wann die letzte Anmeldung in der Domäne stattfand. LastLogonTimestamp wird auf alle Domain Controller im AD-Forest repliziert.
            - https://docs.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp: a large integer that represents the number of 100-nanosecond intervals since January 1, 1601 (UTC)
                - Convert like this => [datetime]::FromFileTime(lastlogontimestamp).tostring('dd.MM.yyyy')
- logonCount: Die Summe aller, auf DC's gefundenen Werte 
    - https://docs.microsoft.com/en-us/windows/win32/adschema/a-logoncount        
        This attribute is not replicated and is maintained on each domain controller in the domain.
        To get an accurate value for the user's total number of successful logon attempts in the domain,
        each domain controller in the domain must be queried and the sum of the values should be used. 
        Keep in mind that the attribute is not replicated, therefore domain controllers that are retired may have counted logons for the user as well, 
        and these will be missing from the count.

D. Marx, 2021/07
#>

param (
    $maxlastlogondays=180,  # Tage ab denen eine Anmeldung als "vor langer Zeit" gilt
    $outfolder="C:\temp"  # In welchem Ordner sollen die csv-Dateien exportiert werden
)


#Funktionen
function getreachabledcs() {
    Write-Host "Ermittle erreichbare Domänencontroller"
    $dcs = Get-ADDomainController -filter * | Select-Object name,domain,forest,ipv4address,isglobalcatalog,isreadonly,ldapport,sslport  # Eine Liste aller Domänencontroller ermitteln
    $myreturn=@()
    foreach ($dc in $dcs){
        $hostname = $dc.name + "." + $dc.domain
        #if ($(Test-Netconnection -Computername $hostname -Port $dc.ldapport).TcpTestSucceeded -eq $true){
            Write-Host "Abfragbarer DC gefunden: " $hostname
            $myreturn += $dc
        #}
        #else {
        #    Write-Warning "Nicht abfragbarer DC: " $hostname
        #}
    }
    return $myreturn
}

function sumlogoncounts($user, $dcs){
    # Diese Funktion sammelt Informationen von allen angegebenen DC's bezüglich der Anzahl der Anmeldungen und summiert diese...

    [System.Collections.ArrayList]$dcstoremove = @()  # Eine (leere) Liste mit allen DC's die später entfernt werden sollen

    [Int]$sum = 0  

    foreach ($dc in $dcs){ 
        # alle dc's befragen
        $filter = "samaccountname -eq '" + $user.samaccountname + "'" # Den Filter vorbereiten. Wir suchen nach dem aktuellen Anmeldenamen
        $servername = $dc.name + "." + $dc.domain + ":" + $dc.ldapport # Den server-FQDN samt Port erzeugen        
        [int]$lc=0
        try {
            $lc= $(get-aduser -ErrorAction SilentlyContinue -filter $filter -Properties Samaccountname,logonCount -Server $servername | select logoncount).logoncount # Anzahl Anmeldungen des Benutzer auf aktuellem DC ermitteln 
            Write-host "`t* Anzahl der Anmeldungen wurde von $servername bezogen. => $lc"
            if ($lc -gt 0) {
                [Int]$logons = [convert]::ToInt32($lc, 10) # ... und in Integer konvertieren
                $sum = $sum + $logons
                }
            }
        catch {
            Write-Warning "`r`n`t* Konnte keine Informationen vom Server $servername erhalten! Ist der Server offline? Server wird beim nächsten mal übersprungen."
            # Den Server aus der Liste der abzufragenden Server entfernen
            $null=$dcstoremove.Add($dc) # aktuellen DC zum Entfernen vormerken            
            }
    }

    # Die zu behaltenden DC's für den nächsten Lauf anpassen
    
    try {
        foreach($dc in $dcstoremove){
            $null=$reachabledcs.Remove($dc)
            }
        }
    catch {
    }
    
    
    Write-Host "Anzahl gesamter Anmeldungen an allen DC's: " $sum
    
    return $sum
}

function getUserGroups($user){
    # Diese Funktion ermittelt die Gruppenzugehörigkeit eines Benutzerkontos und gibt diese als String zurück
    $myreturn = ""

    try {
        $groups = Get-ADPrincipalGroupMembership $user.samaccountname
        foreach ($group in $groups){
            $myreturn=$myreturn + $group.samaccountname +"; "
        }
    }
    catch {
    }
    return $myreturn
}

function hasGroupMembership($user, $groupstocheck){
    <#
    Diese Funktion ermittelt, ob ein Benutzerkonto direktes Mitglied bestimmter Sicherheitskritischer Gruppen ist.
    Es findet allerdings keine Analyse hinsichtlich verschachtelter Gruppenmitgliedschaften statt, welche letzlich zu den gleichen Rechten führen würde.

    https://docs.microsoft.com/de-de/windows/security/identity-protection/access-control/active-directory-security-groups
    https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/active-directory-security-groups
    https://ss64.com/nt/syntax-security_groups.html
    
    Sicherheitsgruppen SID's: https://docs.microsoft.com/de-de/windows/security/identity-protection/access-control/security-identifiers
	
	$user => Benutzerobjekt
	$groupstocheck => Array mit Benutzerkonten.
    #>

    # Auf Mitgliedschaft in allgemein bekannten Gruppen Prüfen
    $myreturn = $false
    try {
        $groups = Get-ADPrincipalGroupMembership $user.samaccountname
        foreach ($group in $groups){
            if ($group.SID.Value.StartsWith("S-1-5-")){ # S-1-5 =	NT Authority (Domainspezifisch oder buildin)
                foreach ($cgroup in $groupstocheck){ # Alle kritischen Gruppen iterieren
                    if ($group.SID.Value.Equals($cgroup)) { # Wenn der Gruppenbezeichner mit einem kritischen identifier endet,
                        Write-Warning $("Benutzermitgliedschaft in Gruppe `"" + $group + "`" gefunden!")
                        $myreturn = $true # True zurückgeben und beenden
                    }
                    
                }
            }
        }
    }
    catch {
    }

    return $myreturn
}

function hasProblematicGroupmembership($user, $domsid, $rootdomsid){
    # Prüft auf problematische Gruppenmitgliedschaften
    # $domsid = Domänenspezifischer Sicherheitsidentifier
    [System.Collections.ArrayList]$pgroupstocheck =@()
    $null=$pgroupstocheck.Add("S-1-5-32-547") # Power Users
    
    #$groupstocheck
    return $(hasGroupMembership $user $pgroupstocheck)
}

function hasCriticalGroupMembership($user, $domsid, $rootdomsid){
    # Prüft auf besonders kritische Gruppenmitgliedschaften
    [System.Collections.ArrayList]$cgroupstocheck=@() # Allgemein bekannte, kritische gruppen sind...     
    $null=$cgroupstocheck.Add("" + $domsid + "-512") # Domänenadmins
    $null=$cgroupstocheck.Add("" + $rootdomsid + "-518") # Schemaadministratoren 
    $null=$cgroupstocheck.Add("" + $rootdomsid + "-519") # Enterprise (Organisations) Administratoren
    $null=$cgroupstocheck.Add("" + $domsid + "-520") # Besitzer von Gruppenrichtlinienerstellern
    $null=$cgroupstocheck.Add("S-1-5-32-544-544") # Administratoren        
    $null=$cgroupstocheck.Add("S-1-5-32-548") # Kontooperatoren
    $null=$cgroupstocheck.Add("S-1-5-32-549") # Serveroperatoren
    $null=$cgroupstocheck.Add("S-1-5-32-550") # Druckoperatoren
    $null=$cgroupstocheck.Add("S-1-5-32-551"), # Sicherungsoperatoren
    $null=$cgroupstocheck.Add("S-1-5-32-552") # Replikatoren    
    #$groupstocheck
    return $(hasGroupMembership $user $cgroupstocheck)
}

# Alle abfragbaren DC's ermitteln 
[System.Collections.ArrayList]$reachabledcs = getreachabledcs
[String]$domainsid=$(Get-ADDomain).DomainSID # SID der aktuellen Domäne
Write-Host "SID der Domäne: " $domainsid

[String]$rootdomainsid=$(Get-ADDomain (Get-ADForest).RootDomain).DomainSID # SID der Root-Domäne
Write-Host "SID der Root-Domäne: " $rootdomainsid

# Alle AD-Benutzer ermitteln
Write-Host "Suche nach Benutzerkonten..."
$allusers=get-aduser -filter * -Properties Samaccountname,displayName,Surname,GivenName,Enabled,Samaccountname,whenCreated,LastlogonTimestamp,adminCount,pwdlastset,extensionAttribute1,extensionAttribute2,extensionAttribute3,extensionAttribute4,extensionAttribute5
$allprocessedusers=@()

# Unterschiedliche Listen anlegen, welche zur Einsortierung von Benutzerkonten mit bestimmten Eigenschaften verwendet werden.
$allenabledusers=@() # Nicht INAKTIVE Benutzerkonten

$userswithadminCount=@()  # Alle Benutzerkonten die mindestens einmal administrative Rechte hatten
$userswithnologons=@()  # Alle Benutzerkonten die sich noch nie angemeldet haben
$userswitholdlastlogons=@()  # Alle Benutzer die sich seit langer Zeit nicht mehr angemeldet haben

$enableduserswithadminCount=@()  # Alle NICHT-DEAKTIVIERTEN Benutzerkonten die mindestens einmal administrative Rechte hatten
$enableduserswithnologons=@()  # Alle NICHT-DEAKTIVIERTEN Benutzerkonten die sich noch nie angemeldet haben
$enableduserswitholdlastlogons=@()  # Alle NICHT-DEAKTIVIERTEN Benutzer die sich seit langer Zeit nicht mehr angemeldet haben

Write-Host "Gefundene Benutzerkonten" $allusers.Count
[int]$iteration=0
foreach ($user in $allusers){
    $iteration+=1
    [int]$percs=100/$allusers.Count * $iteration
    Write-Progress -Activity "Analyse läuft..." -Status "$percs% Abgeschlossen:" -PercentComplete $percs

    $msg = "`r`nVerarbeite Benutzerkonto " + $iteration + "/" + $allusers.Count +": " + $user.SamAccountName + " (" + $user.DisplayName + ")"
    Write-Host $msg
    
    if ($null -eq $user.logonCount){
        $user.logonCount=0;  # Wenn der logoncount nicht gesetzt und damit leer ist, diese auf 0 setzen...
    }
    if ($null -eq $user.adminCount){
        $user.adminCount=0;  # Wenn der admin nicht gesetzt und damit leer ist, diese auf 0 setzen...
    }

    # Methode erzeugen um den AD-synchronen Zeitstempel in ein Datumsformat zu konvertieren
    $LastLogonDate = { 
        if ($null -eq $this.LastlogonTimestamp -or $this.LastlogonTimestamp -le 0 ){
            "Never" # War noch nie angemeldet
        }
        else {
            [datetime]::FromFileTime($this.LastlogonTimestamp).tostring('dd.MM.yyyy')
        }
    }
    
    $user | Add-Member -Force -MemberType ScriptMethod -Name "CLLD" -Value $LastLogonDate # Die Methode dem Benutzer-Objekt (HIER IM SCRIPT nicht im AD) hinzufügen
    $user | Add-Member -Force -MemberType NoteProperty -Name "LastLogonDate" -Value $user.CLLD() # Feld mit dem umgerechnete Datum hinzufügen
    $user | Add-Member -Force -MemberType NoteProperty -Name "LastPasswordchange" -Value $(if ($null -eq $user.pwdlastset){"Never"} else {[datetime]::FromFileTime($user.pwdlastset).tostring('dd.MM.yyyy')}) # Feld mit dem umgerechneten Datum des pwdlastset hinzufügen 
    $user.logonCount = $(sumlogoncounts $user $reachabledcs) # Die Summe aller Anmeldungen des Benutzers von allen abfragbaren DC's ermitteln
  	$user | Add-Member -Force -MemberType NoteProperty -Name "HasProblematicGroupMembership" -Value $(hasProblematicGroupmembership $user $domainsid $rootdomainsid)  # Feld hinzufügen welches anzeigt ob der User eine kritische Gruppenmitgliedschaft hat
	$user | Add-Member -Force -MemberType NoteProperty -Name "HasCriticalGroupMembership" -Value $(hasCriticalGroupMembership $user $domainsid $rootdomainsid)  # Feld hinzufügen welches anzeigt ob der User eine kritische Gruppenmitgliedschaft hat    
    $user | Add-Member -Force -MemberType NoteProperty -Name "GroupMemberships" -Value $(getUserGroups $user)  # Gruppenzugehörigkeit ermitteln und als Feld einfügen

    if ($user.Enabled -eq $True){ # Wenn das Konto aktiv ist
        $allenabledusers += $user # Benutzer in die entsprechende Liste übernehmen
    }        

    if($user.logonCount -le 0){ # Noch nie angemeldet, da 0 gefundene Anmeldungen
        $userswithnologons+=$user # Benutzer in die entsprechende Liste übernehmen

        if ($user.Enabled -eq $True){ # und Konto aktiv
            $enableduserswithnologons += $user # Benutzer in die entsprechende Liste übernehmen
        }       
    }
    if($user.adminCount -gt 0){ # Mindestens einmal Admin gewesen
        $userswithadminCount+=$user # Benutzer in die entsprechende Liste übernehmen

        if ($user.Enabled -eq $True){ # und Konto aktiv
            $enableduserswithadminCount += $user # Benutzer in die entsprechende Liste übernehmen
        }     
    }
    Write-Host "Admincount: " $user.admincount

    Write-Host "Direkte Mitgliedschaft in problematischer Gruppe: " $user.HasProblematicGroupMembership
    
    Write-Host "Direkte Mitgliedschaft in sicherheitskritischer Gruppe: " $user.HasCriticalGroupMembership
    
    
      
    # write-host $user.LastlogonTimestamp $user.CLLD()  #DEBUG
    if($null -ne $user.LastlogonTimestamp) {
        if ($user.CLLD() -lt (Get-Date).AddDays(-1 * $maxlastlogondays)) { # Alle Benutzer, die länger als X-Tage nicht angemeldet waren            
            $userswitholdlastlogons+=$user # Benutzer in die entsprechende Liste übernehmen

            if ($user.Enabled -eq $True){ # und Konto aktiv
                $enableduserswitholdlastlogons += $user # Benutzer in die entsprechende Liste übernehmen
                }     
            }           
        }
    Write-Host "Letzte Anmeldung: " $user.LastLogonDate
    

    Write-Host "Letzer Kennwortwechsel: " $user.LastPasswordchange
    
    $allprocessedusers+=$user # Den bearbeiteten User (um Felder erweitert) der Liste der verarbeiteten User hinzufügen
    
}


Write-Host "Zusammenfassung:"
Write-Host "################"

Write-Host "Anzahl aller Benutzerkonten: "
$allusers.Count
Write-Host "davon aktiv"
$allenabledusers.Count
Write-Host "`r`n"

#$allusers | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-Alle.csv") -Encoding UTF8
$allprocessedusers | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-Alle.csv") -Encoding UTF8
$allenabledusers | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-Alle_AKTIV.csv") -Encoding UTF8

Write-Host "Anzahl der Benutzer, die mindestens einmal administatrive Rechte hatten: "
$userswithadminCount.Count
Write-Host "davon aktiv"
$enableduserswithadminCount.Count
Write-Host "`r`n"

$userswithadminCount | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-adminCount.csv") -Encoding UTF8
$enableduserswithadminCount | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-adminCount_AKTIV.csv") -Encoding UTF8

Write-Host "Anzahl der Benutzer, die noch nie angemeldet waren: "
$userswithnologons.Count
Write-Host "davon aktiv"
$enableduserswithnologons.Count
Write-Host "`r`n"

$userswithnologons | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-keine_Anmeldung.csv") -Encoding UTF8
$enableduserswithnologons | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-keine_Anmeldung_AKTIV.csv") -Encoding UTF8

Write-Host "Anzahl der Benutzer, die sich seit mindestens $maxlastlogondays Tagen nicht (mehr) angemeldet haben."
$userswitholdlastlogons.Count
Write-Host "davon aktiv"
$enableduserswitholdlastlogons.Count
Write-Host "`r`n"

$userswitholdlastlogons | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-Anmeldung_vor_mehr_als_" + $maxlastlogondays + "_Tagen.csv") -Encoding UTF8
$enableduserswitholdlastlogons | export-csv -Path $($outfolder.TrimEnd('\') + "\AD_Benuter-Anmeldung_vor_mehr_als_" + $maxlastlogondays + "_Tagen_AKTIV.csv") -Encoding UTF8

# SIG # Begin signature block
# MIITYwYJKoZIhvcNAQcCoIITVDCCE1ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUf4cHzziqHO1izZX+s6jfT64s
# kHqggg/XMIIHeTCCBWGgAwIBAgIKGCSiEAAAAAAAAjANBgkqhkiG9w0BAQsFADAU
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
# cRP9mNfjQnxvtLegz+oK+3fGsUIwDQYJKoZIhvcNAQEBBQAEggIAQNImeljvt13a
# TmQA9ggkWR9QXSJmIV2GxaJynRh1yjUztroZHAsNH7CNw5OKunL+wS7b/N0g0+8A
# Dox0hRtiUo4OgisTqm6vJieHKC5oJMsqeXONIVq+LRFnoZj0Ce3J4DWQAMbqyYDv
# JMjHD0gGSfI50dvk7jLQo3osBPdavf1v+6p+towrRmNI+tACXqyCro3rrUtc4aax
# dnEqrcSc9zQQzPawH/To1QryElcJzZl11tEjQvMKGuAvuO1ibmSrJQfiLUo2iZLg
# SHqqX5v5MmNoxHiLhwMk6FypPCND4aTCY7SRvMzkSb87J2j0htuLbllZdDjyc45x
# 66pw6mmxFqaG9BvtuF9bG6Qy2H/0RgGLboPAObcgUhRwXVSIMCt4wEVYkjePvnjS
# aHyKOEd+CEgNnEsbKyaBhEyp17ZP+O+Q+a/pRuI7CIxuggDw707CQWN1HAps8LlC
# WTRZGKunbS2mSo3NEL8lQBYesnAlH7UoT3Momk3WiKp6pLGjZk12jvpJMpq+i0W6
# HN5fo6E36PhxObmFFemcqbFG1sSaRf6TrMMFs2yyNhN9zE8ZeLyYPuDE0vzcTaqH
# PC58R0UTPmVYl7a2jfnSSBdEjuVGuZYeJRxafTNGUcTcR0dF3wMFHvcEiEEhVPoi
# hll3RXFkP+uvbtjDwWc4TS2tgJqjAXo=
# SIG # End signature block
