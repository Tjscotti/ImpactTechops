function Get-SQLXmlToCsv {
<#
.DESCRIPTION
 Get an exported XML file backup of a group of SQL Tables, convert the file to a Powershell object and then export one or more desired tables into CSV format.

.EXAMPLE

.EXAMPLE

.EXAMPLE
 
.EXAMPLE

 #>
 [CmdletBinding()]
 param(
 [String]$CliXmlPath = "c:\scripts\file.clixml",
 [csv]$exportPath = "~",
 [xml]$xmlData = (Import-CliXml $Path)
 )
 

$xmlData = Import-clixml .\SQL_TABLE_BACKUP-9-28-24-7-15.clixml
$xmldata.count
$xmldata.cloudflare_zones | export-csv CloudeFlareZones.csv
$xmldata | get-member
$CF_Zones = $xmldata.Cloudflare_Zones
$CF_Zones
$CF_Zones = $xmldata.Cloudflare_Zones | out-host -paging
$csvFilePath = ".\CloudFlare_Zones.csv"
$csvFilePath 
$customersTable | Export-Csv -Path $csvFilePath -NoTypeInformation

Import-Csv -Path .\CloudFlare_Zones.csv | Format-Table -AutoSize | out-host -paging

}

re