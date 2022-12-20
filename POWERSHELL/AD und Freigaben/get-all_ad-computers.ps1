[System.Collections.ArrayList]$results= @()
get-ADComputer -filter '*' -searchbase "OU=Computer,OU=Informationstechnik,DC=firma,DC=firma,DC=local"
#$results.add()