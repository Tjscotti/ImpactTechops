<#
.SYNOPSIS
    This script detects if a SentinelOne client is "orphaned". When the management console detects that SentinelOne is orphaned
    it will attempt to connect it to the management server using the SentinelCtl.exe utility.
.NOTES
    A SentinelOne client is determined to be "orphaned" when it is managed by an unknown management server. Currently the only
    known managenet console is 'https://usea1-impact01.sentinelone.net'
#>


$StatusObject = [PSCustomObject]@{
    RegistryPathExists                 = $False
    InstallationPathExists             = $False
    installationPath                   = $null
    SentinelCtlExists                  = $null
    $S1MgmtServer                      = $null
    AgentOrphaned                      = $null
    AgentMissing                       = $null
    AgentVersion                       = $null
    AgentOutOfDate                     = $false
    AgentServiceExists                 = $null
    AgentServiceStatus                 = $null
    AgentServiceStartupType            = $null
    AgentHelperServiceExists           = $null
    AgentHelperServiceStatus           = $null
    AgentHelperServiceStartupType      = $null
    StaticEngineServiceExists          = $null
    StaticEngineServiceStatus          = $null
    StaticEngineServiceStartupType     = $null
    LogProcessingServiceExists         = $null
    LogProcessingStatus                = $null
    LogProcessingStartupType           = $null

    AgentServiceFailedToStart          = $null
    AgentUpdaterServiceFailedToStart   = $null
    LogFileExists                      = $False
    AmpOrganizationKeyGood             = $False
    INCOrganizationKeyGood             = $False
    AmpOrganizationKey                 = $orgKey
    AmpAccountKey                      = $null
    RegistryOrgKey                     = $null
    RegistryAccountKey                 = $null
    RegistryOrgKeyExists               = $False
    AgentInWrongOrganization           = $False
    CertificateError                   = $null
    DNSResolutionError                 = $null
    DNSResolutionResults               = $null
    TCPConnectionError                 = $null
    TCPConnectionResults               = $null
    OutputMessage                      = $null
}

$FailPolicy = $True
[system.collections.arraylist]$StatusOutput = @()

$TestMode = $False

function Write-ImpactMessage {
    [cmdletBinding()]
    param(
        [ValidateSet('I', 'W', 'E')]
        [string]$loglevel,
        [string]$scriptname,
        [string]$message
    )

    BEGIN {            
        $DeviceID = $null
        $CustomerID = $null
        $NCentralAssetTag = $null
    }

    PROCESS {
        <#
        $ErrorActionPreference = 'SilentlyContinue'
        if (Test-Path -Path 'C:\ProgramData\SolarWinds MSP\Ecosystem Agent\Config\AgentConfigurations.xml' -PathType Leaf) {
            $xml = [xml] (Get-Content -Path 'C:\ProgramData\SolarWinds MSP\Ecosystem Agent\Config\AgentConfigurations.xml')
            if ($xml -and $xml.AgentConfigurations -and $xml.AgentConfigurations._agentId) {
                $agentid = $xml.AgentConfigurations._agentId
            }       
        }
        
        $ErrorActionPreference = 'Stop'
        #>
        
        Try {
            $NCentralAssetTag = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\N-able Technologies\NcentralAsset' -ErrorAction STOP).NcentralAssetTag
        }
        Catch {
        }

        try {
            $json_body = ConvertTo-Json @{
                ScriptName       = $ScriptName
                LogLevel         = $LogLevel
                DeviceName       = $env:COMPUTERNAME
                DeviceID         = $DeviceID
                NcentralAssetTag = $NcentralAssetTag
                CustomerID       = $CustomerID
                Message          = $Message
                sharedSecret     = '089324hjweaasdfasdfsdfa433sdfas'
                # TODO see devops nable wiki notes for ideas on getting ids from local xml files
            }
    
            $RequestResults = Invoke-WebRequest 'https://sortarius.impactnfr.com/MIT_AgentLog' -Body $json_body -Method POST -ErrorAction STOP
        }
        catch {
            Write-Verbose -Message "Write-ImpactMessage failed, details: $($_.Exception.message)"
        }
    }

    END {
    }
}


# Test if SentinelOne is installed
if (-not (Get-Item 'HKLM:\SOFTWARE\Sentinel Labs' -ErrorAction SilentlyContinue)) {
    $StatusObject.RegistryPathExists = $True
    $null = $StatusOutput.add('Registry path found - HKLM:\SOFTWARE\Sentinel Labs')
}
else {
    $StatusObject.RegistryPathExists = $False
    $null = $StatusOutput.add('Registry not path found - HKLM:\SOFTWARE\Sentinel Labs')
}

# Determine the correct installation directory
if (Test-Path 'C:\Program Files\SentinelOne' -PathType Container) { 
    $installationPath = (get-childitem 'C:\Program Files\SentinelOne' -Directory -filter "Sentinel Agent*" | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName)
} elseif (Test-path 'C:\Program Files (x86)\SentinelOne' -PathType Container) {
    $installationPath = (get-childitem 'C:\Program Files (x86)\SentinelOne' -Directory -filter "Sentinel Agent*" | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName) 
    $StatusObject.installationPath = $installationPath
    $StatusObject.InstallationPathExists = $True
    $null = $StatusOutput.add("Installation directory found: $installationPath")
}

else {
    $StatusObject.InstallationPathExists = $False
    $null = $StatusOutput.add('Sentinel One Program Files installation directory not found')
}

# Find service statuses
Try {
    $AgentService = Get-Service -Name 'Sentinel Agent' -ErrorAction STOP
    $StatusObject.AgentServiceExists = $True
}
Catch {
    $StatusOutput.add('Could not get Sentinel Agent service')
    $StatusObject.AgentServiceExists = $False
}
if ($StatusObject.AgentServiceExists -eq $True) {
    $StatusObject.AgentServiceStatus = $AgentService.Status
    $StatusObject.AgentServiceStartupType = $AgentService.StartType
}

Try {
    $AgentHelperService = Get-Service -Name 'SentinelHelperService' -ErrorAction STOP
    $StatusObject.AgentHelperServiceExists = $True
}
Catch {
    $StatusObject.AgentHelperServiceExists = $False
    $StatusOutput.add('Could not get Sentinel Helper service')
}
if ($StatusObject.AgentHelperServiceExists -eq $True) {
    $StatusObject.AgentHelperServiceStatus = $AgentHelperService.Status
    $StatusObject.AgentHelperServiceStartupType = $AgentHelperService.StartType
}

Try {
    $StaticEngineService = Get-Service -Name 'SentinelStaticEngine' -ErrorAction STOP
    $StatusObject.StaticEngineServiceExists = $True
}
Catch {
    $StatusOutput.add('Could not get Sentinel Static Engine service')
    $StatusObject.StaticEngineServiceExists = $False
}
if ($StatusObject.StaticEngineServiceExists -eq $True) {
    $StatusObject.StaticEngineServiceStatus = $StaticEngineService.Status
    $StatusObject.StaticEngineServiceStartupType = $StaticEngineService.StartType
}

Try {
    $AgentService = Get-Service -Name 'SentinelOne Agent Log Processing Service' -ErrorAction STOP
    $StatusObject.AgentServiceExists = $True
}
Catch {
    $StatusOutput.add('Could not get SentinelOne Agent Log Processing Service')
    $StatusObject.LogProcessingServiceExists = $False
}
if ($StatusObject.LogProcessingServiceExists -eq $True) {
    $StatusObject.LogProccessingServiceStatus = $LogProcessingService.Status
    $StatusObject.LogProcessingServiceStartupType = $LogProcessingervice.StartType
}

# Use SentinelCTL to get the management server 

# first make sure the utility exists 
if (-not (Test-Path "$installationPath\SentinelCtl.exe" -ErrorAction SilentlyContinue)) {
    $StatusObject.SentinelCtlExists = STrue
    $null = $StatusOutput.add('SentinelCtl.exe not found')
} else {
    
$outfile = New-TemporaryFile
Start-Process -FilePath $($installationPath + '\SentinelCtl.exe') -ArgumentList @("config -p server.mgmtServer") -NoNewWindow -Wait -RedirectStandardOutput $outfile
$s1MgmtServer = "$(Get-Content $outfile)`"".Split('"')[1] # Get the management server and strip out the double quotes
Remove-Item $outfile -ErrorAction SilentlyContinue

}

# Check to make sure the agent is already connected to the management server
$S1MgmtServerCfg = 'https://usea1-impact01.sentinelone.net'  # This is the current management server
if ($S1MgmtServer -eq $S1MgmtServerCfg) {
    $StatusObject.AgentOrphaned = $False
    $null = $StatusOutput.add( "The SentinelOne agent is correctly configured to the management server.")
} else {
    $null = $StatusOutput.add( "The SentinelOne agent is not configured to the correct management server.")
}

