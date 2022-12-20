[uint16]$i=1
$j=1
[uint16]$max=256
$min=0
[uint64]$iteration=1
while ($true){
    $perc=100/$max*$i
    Write-Progress -Activity ("Working....") -Status "$perc% Fortschritt:" -PercentComplete $perc # Fortschrittsbalken anzeigen
    if($i -eq $max){
        $j=$j*-1
    }
    if($i -eq $min){
        $j=$j*-1
        $iteration+=1
    }
    $i+=$j
    [String]$pre=""
    $precount=$iteration
    while ($precount -gt 0){
        $pre=$pre+"*"
        $precount-=1
    }
    $pre=$pre+" "
    Write-Host ($pre+$i)
    }