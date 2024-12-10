<#
.SYNOPSIS
    This script will attempt to connect the SentinelOne agent to the management server using the SentinelCtl.exe utility. The passphrase
    for the agent will need to be supplied.
.NOTES
    A SentinelOne client is determined to be "orphaned" when it is managed by an unknown management server. Currently the only
    known managenet console is 'https://usea1-impact01.sentinelone.net'
#>

# Initialization
$resultCode = 99
$OutputMessage = 'initialized'
$status = 'initialized'

# Verify the site token 
if ($stoken -eq 'None Selected' -and $stoken.length -ne '104' -and $stoken.length -ne '108') {
    $OutputMessage = "Token is wrong: $($stoken) <br>"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# verify the client pass phrase
if ([string]::IsNullOrEmpty($s1passphrase)) {
    $OutputMessage = "No passphrase has been provided"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
} 

$installationPath = '' 

# Test if SentinelOne is installed
if (-not (Get-Item 'HKLM:\SOFTWARE\Sentinel Labs' -ErrorAction SilentlyContinue)) {
    $OutputMessage = "SentinelOne is not installed on this computer"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Determine the correct installation directory - choose the last one created
if (Test-path 'C:\Program Files\SentinelOne' -PathType Container) {
    $installationPath = (get-childitem 'C:\Program Files\SentinelOne' -Directory -filter "Sentinel Agent*" | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName)
} elseif (Test-path 'C:\Program Files (x86)\SentinelOne' -PathType Container) {
    $installationPath = (get-childitem 'C:\Program Files (x86)\SentinelOne' -Directory -filter "Sentinel Agent*" | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName) 
} 

if ($installationPath -eq '') {
    $OutputMessage = "SentinelOne installation not found!"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Use SentinelCTL to get the management server 

# first make sure the utility exists 
if (-not (Test-Path "$installationPath\SentinelCtl.exe")) {
    $OutputMessage = "SentinelOne installation not found!"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Construct path to SentinelCtl utility
$sentinelCtl = $installationPath + '\SentinelCtl.exe'

#
# Try to connect the SentinelOne agent to the management server 
#
$processResponse = ""
$outfile = New-TemporaryFile

# Use SentinelCTL unload
Start-Process -FilePath $sentinelCtl -ArgumentList @("unload -k `"$($S1passphrase)`"") -NoNewWindow -Wait -RedirectStandardError $outfile
$processResponse = Get-Content $outfile

if (-Not [string]::IsNullOrWhiteSpace($processResponse)) {    
    $OutputMessage = "Unload of SentinelAgent failed, details $processResponse"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Use SentinelCTL bind
Start-Process -FilePath $sentinelCtl -ArgumentList @("bind $stoken -k `"$($S1passphrase)`"") -NoNewWindow -Wait -RedirectStandardError $outfile
$processResponse = Get-Content $outfile
if (-Not [string]::IsNullOrWhiteSpace($processResponse)) {     
    $OutputMessage = "BIND of SentinelAgent failed, details $processResponse"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Use SentinelCTL load
Start-Process -FilePath $sentinelCtl -ArgumentList @("load -a") -NoNewWindow -Wait -RedirectStandardError $outfile
$processResponse = Get-Content $outfile
if (-Not [string]::IsNullOrWhiteSpace($processResponse)) {
    $OutputMessage = "LOAD of SentinelAgent failed, details $processResponse"
    $status = 'Failed'
    $resultCode = 9
    exit $resultCode
}

# Set successfull completion here
$OutputMessage = "Rehoming of SentinelAgent successfull."
$status = 'Success'
$resultCode = 0