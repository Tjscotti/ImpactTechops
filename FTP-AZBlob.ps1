$Agentversions = get-ImpactIncDevices -Tableall | Where-Object { $_.AgentVersion -ne "NA" } 

$Agentversions | Group-Object AgentVersion | Select-Object Name, Count | Sort-Object Count -Descending
Write-Output ""
$totalCount = $Agentversions.Count
Write-Output "Total Count of devices: $totalCount"
