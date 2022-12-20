<# 
Dieses Skript demonstriert den Unterschied zwischen einer ungebremsten While-Schleife un einer, die in der Zwischenzeit Aufgaben durchführt oder "gebremst" wird
Bei der Entwicklung von multi-threaded-netzwerkdiensten ist es beispielsweise hilfreich, den Thread zur Verbindungsannahme am Ende der Schleife kurz zu pausieren.
    -> Dadurch wird die CPU-Auslastung signifikant verringert.
Eine "ungebremste"-Schleife lastet einen CPU Thread voll aus, da diese die CPU permanent instruiert Sprungbefehle auszuführen.
#>

write-Host "Bitte die CPU Auslastung beobachten... Abbruch mit Strg+C"

[Int32]$maxval=8199023

[Int32]$i = 0
Write-Host "ungebremste Schleife"
while ($i -lt $maxval){ <# While-Schleife ohne Thread.Sleep -> lastet einen CPU-Thread voll aus. #>
    $i++
} 

$i = 0
Write-Host "gebremste Schleife"
while ($i -lt $maxval/3){ <# While-Schleife mit Thread.Sleep, welcher bei jeder Iteration 1ms pausiert -> verursacht keine enorme Last#>
    $i++
    Start-Sleep -Milliseconds 1    
} 

Write-Host "done"
exit 0