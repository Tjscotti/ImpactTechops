

<#
.SYNOPSIS
This script detects if a Huntress client is "orphaned" or has specific registry values signifying that the installation is not Impact owned and attempts to resolve this by uninstalling the client.
When the management console detects that huntress is not installed it will reinstall huntress and the "orphaned" condition will be resolved.
.NOTES
A Huntress client is determined to be "orphaned" when it logs authentication 401 errors when contacting the management consoleA huntress client is determined to be owned by a non-Impact source if the AccountKey and OrganizationKey on the client are not Impact's.
#>
<#
Tests to perform
1) Uninstall agent if orphaned and the INC Org Key is a correct Impact key
2) Do not Uninstall agent if orphaned and the INC Org Key is None Selected
3) Uninstall agent if orphaned and the INC Org Key is the wrong org key
4) Reverse the previous 3 and all permutations thereof

#>
# TODO
# Check resource usage of processes
# check service statuses, start or restart if needed
# check statup type, set to automatic if not automatic
# run huntressconnect.exe, parse results, report errors. Huntress uses cert pinning. If client uses DPI, Huntress will fail to work.
# https://support.huntress.io/hc/en-us/articles/4404005175187-Deep-Packet-Inspection-TLS-SSL-Interception-Cert-Pinning
# PS to check certificate is huntress.io or if it's been replaced


#

<# PS 4.0 to check connectivity
@("huntresscdn.com", "update.huntress.io", "huntress.io", "eetee.huntress.io", "huntress-installers.s3.amazonaws.com", "huntress-updates.s3.amazonaws.com", "huntress-uploads.s3.us-west-2.amazonaws.com", "huntress-user-uploads.s3.amazonaws.com", "huntress-rio.s3.amazonaws.com", "huntress-survey-results.s3.amazonaws.com", "notify.bugsnag.com") | Test-NetConnection -Port 443 | Select ComputerName, TcpTestSucceeded
#>


$StatusObject = [PSCustomObject]@{
    RegistryPathExists                 = $False
    InstallationPathExists             = $False
    installationPath                   = $null
    AgentOrphaned                      = $null
    AgentMissing                       = $null
    AgentVersion                       = $null
    AgentOutOfDate                     = $false
    AgentServiceExists                 = $null
    AgentUpdaterServiceExists          = $null
    AgentServiceStatus                 = $null
    AgentUpdaterServiceStatus          = $null
    AgentServiceStartupType            = $null
    AgentUpdaterServiceStartupType     = $null
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
    HuntressServerDNSResolutionError   = $null
    HuntressServerDNSResolutionResults = $null
    HuntressServerTCPConnectionError   = $null
    HuntressServerTCPConnectionResults = $null
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

#TESTING VALUES - Comment all below out after testing
#$OrgKey = 'None Selected' #TESTLINE
#$OrgKey = 'DO_NOT_USE_PLS_SELECT_FROM_DROPDOWN' #TESTLINE
$OrgKey = '98asdfa9sdfasdf' #TESTLINE
<#
$StatusObject.RegistryPathExists = $False
$StatusObject.RegistryPathExists = $True
$StatusObject.InstallationPathExists = $False
$StatusObject.InstallationPathExists = $True
$StatusObject.installationPath = $null
$StatusObject.installationPath = $null
$StatusObject.AgentOrphaned = $Null
$StatusObject.AgentOrphaned = $Null
$StatusObject.LogFileExists = $False
$StatusObject.LogFileExists = $True
$StatusObject.AmpOrganizationKeyGood = $False
$StatusObject.AmpOrganizationKeyGood = $True
$StatusObject.INCOrganizationKeyGood = $False
$StatusObject.INCOrganizationKeyGood = $True
$StatusObject.RegistryOrgKey = $null
$StatusObject.RegistryOrgKey = 'asdasdfasdf'
$StatusObject.RegistryAccountKey = $null
$StatusObject.RegistryAccountKey = $null
$StatusObject.RegistryOrgKeyExists = $False
$StatusObject.RegistryOrgKeyExists = $True
$StatusObject.AgentInWrongOrganization = $False
$StatusObject.AgentInWrongOrganization = $True
#>
#TESTING VALUES

$null = $StatusOutput.add("Executing with OrgKey '$($OrgKey)'")
# Test if huntress is installed
if ((Get-Item 'HKLM:\SOFTWARE\Huntress Labs\Huntress' -ErrorAction SilentlyContinue)) {
    $StatusObject.RegistryPathExists = $True
    $null = $StatusOutput.add('Registry path found - HKLM:\SOFTWARE\Huntress Labs\Huntress ')
}
else {
    $StatusObject.RegistryPathExists = $False
    $null = $StatusOutput.add('Registry not path found - HKLM:\SOFTWARE\Huntress Labs\Huntress')
}

# Determine the correct installation directory
if (Test-Path 'C:\Program Files\Huntress' -PathType Container) {
    $StatusObject.installationPath = 'C:\Program Files\Huntress'
    $StatusObject.InstallationPathExists = $True
    $null = $StatusOutput.add("Installation directory found: 'C:\Program Files\Huntress'")
}
elseif (Test-Path 'C:\Program Files (x86)\Huntress' -PathType Container) {
    $StatusObject.installationPath = 'C:\Program Files (x86)\Huntress'
    $StatusObject.InstallationPathExists = $True
    $null = $StatusOutput.add("Installation directory found: 'C:\Program Files (x86)\Huntress'")
}
else {
    $StatusObject.InstallationPathExists = $False
    $null = $StatusOutput.add('Program Files installation directory not found')
}

# Find service statuses
Try {
    $AgentService = Get-Service -Name 'HuntressAgent' -ErrorAction STOP
    $StatusObject.AgentServiceExists = $True
}
Catch {
    $StatusOutput.add('Could not get HuntressAgent service')
    $StatusObject.AgentServiceExists = $False
}
if ($StatusObject.AgentServiceExists -eq $True) {
    $StatusObject.AgentServiceStatus = $AgentService.Status
    $StatusObject.AgentServiceStartupType = $AgentService.StartType
}

Try {
    $AgentUpdaterService = Get-Service -Name 'HuntressUpdater' -ErrorAction STOP
    $StatusObject.AgentUpdaterServiceExists = $True
}
Catch {
    $StatusObject.AgentUpdaterServiceExists = $False
    $StatusOutput.add('Could not get HuntressUpdater service')
}
if ($StatusObject.AgentUpdaterServiceExists -eq $True) {
    $StatusObject.AgentUpdaterServiceStatus = $AgentUpdaterService.Status
    $StatusObject.AgentUpdaterServiceStartupType = $AgentUpdaterService.StartType
}
# Rio does not seem to be installed on test machine, it used to be present on Huntress installs, need to verify with DOT if they disabled it in the portal system wide
#Try {
#    $RioAgentService = Get-Service -Name 'HuntressAgent' -ErrorAction STOP
#}
#Catch {
#    $StatusOutput.add('Could not get HuntressAgent service')
#}

Try {
    # Check for orphaned agent
    Get-Content (Join-Path $StatusObject.installationPath 'HuntressAgent.log') -ErrorAction STOP -Tail 20 | ForEach-Object {
        if ($_ -like '*request - bad status code: 401*') { $StatusObject.AgentOrphaned = $True } 
    }
    if ($StatusObject.AgentOrphaned -eq $True) {
        $null = $StatusOutput.add('Agent is orphaned')
    }
    else {
        $StatusObject.AgentOrphaned = $False
        $null = $StatusOutput.add('Agent is not orphaned')
    }
    $StatusObject.LogFileExists = $True
}
Catch {
    $StatusObject.LogFileExists = $False
}

if ($orgKey -eq 'DO_NOT_USE_PLS_SELECT_FROM_DROPDOWN') {
    $FailPolicy = $True
    # Policy will fail in this case
    $StatusObject.AmpOrganizationKeyGood = $False
    $null = $StatusOutput.add('Invalid Organization Key provided.  Please select a valid key from the dropdown when executing the AMP')
}
else {
    $StatusObject.AmpOrganizationKeyGood = $True
}

if ($orgKey -eq 'None Selected' -or $OrgKey -eq '' -or $null -eq $OrgKey) {
    $FailPolicy = $True
    $StatusObject.INCOrganizationKeyGood = $False
    $null = $StatusOutput.add("Customer is not configured to AutoDeploy Huntress, OrgKey is 'None Selected' or empty. Either contact Operations to resolve, or this customer does not have Impact Huntress")
}
else {
    $StatusObject.INCOrganizationKeyGood = $True
}

if ($StatusObject.RegistryPathExists -eq $True) {
    # Check for specific registry values
    try {
        $StatusObject.RegistryOrgKey = (Get-ItemProperty 'HKLM:\SOFTWARE\Huntress Labs\Huntress' -Name OrganizationKey -ErrorAction Stop).OrganizationKey
        $StatusObject.RegistryAccountKey = (Get-ItemProperty 'HKLM:\SOFTWARE\Huntress Labs\Huntress' -Name AccountKey -ErrorAction Stop).AccountKey
        $StatusObject.RegistryOrgKeyExists = $True
        $null = $StatusOutput.add("Successfully retrieved OrgKey $($StatusObject.RegistryOrgKey) registry value")
        $null = $StatusOutput.add("Successfully retrieved AccountKey $($StatusObject.RegistryAccountKey) registry value")
    }
    catch {
        $StatusObject.RegistryOrgKeyExists = $False
        $null = $StatusOutput.add('Did not retrieve Org Key registry values')
    }
    try {
        $StatusObject.AgentVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Huntress Labs\Huntress' -Name AgentVersion -ErrorAction Stop).AgentVersion
        $null = $StatusOutput.add("Successfully retrieved AgentVersion $($StatusObject.AgentVersion) from registry")
    }
    catch {
        $null = $StatusOutput.add('Did not retrieve AgentVersion registry values')
    }

}
else {
    $StatusObject.RegistryOrgKeyExists = $False
}

# Test for MITM certificate interception
Try {
    ($WebRequest = [Net.WebRequest]::Create('https://huntress.io')).GetResponse().Dispose() 
    $OK = $True
}
catch {
    $OK = $False
    $FailPolicy = $True
    $StatusObject.CertificateError = $True
    $null = $StatusOutput.add("Unable to test for Deep TLS inspection, error is: '$(($error[0].Exception.innerexception).message)'. Fix DNS, firewall, or Contacts Ops.")
}
if ($OK) {
    if ($webRequest.ServicePoint.Certificate.Subject -eq 'CN=*.huntress.io, O=Huntress Labs Inc., L=Ellicott City, S=Maryland, C=US') {
        $StatusObject.CertificateError = $False
    }
    else {
        $FailPolicy = $True
        $StatusObject.CertificateError = $True
        $LogToSQL = $True
        $null = $StatusOutput.add('Deep TLS inspection possibly found, Agent cannot connect to Huntress properly. Exempt from DPI or Contact Ops.')
    }
}

# Test connectivity
$HuntressConnectivityServers = @('huntresscdn.coma', 'update.huntress.io', 'huntress.io', 'eetee.huntress.io', 'huntress-installers.s3.amazonaws.com', 'huntress-updates.s3.amazonaws.com', 'huntress-uploads.s3.us-west-2.amazonaws.com', 'huntress-user-uploads.s3.amazonaws.com', 'huntress-rio.s3.amazonaws.com', 'huntress-survey-results.s3.amazonaws.com')
[System.Collections.Arraylist]$ConnectivityTestResults = @()
foreach ($Server in $HuntressConnectivityServers) {
    $TCPClient = $Null
    $results = [PSCustomObject]@{
        Host   = $Server
        Result = $null
    }
    Try {
        $TCPClient = New-Object System.net.sockets.tcpclient($server, 443) -ErrorAction STOP
        if ($TCPClient.Connected) {
            $Results.Result = 'Connection Succeeded'
        }
        else {
            $FailPolicy = $True
            $Results.Result = 'Connection Failed'
        }
        $TCPClient.Close()
    }
    catch {
        $Results.Result = $($error[0].Exception.innerexception).message
    }
    $null = $ConnectivityTestResults.add($Results)
    
}
if ($ConnectivityTestResults.Result -contains 'No such host is known') {
    $FailPolicy = $True
    $StatusObject.HuntressServerDNSResolutionError = $True
    $StatusObject.HuntressServerDNSResolutionResults = $ConnectivityTestResults | Where-Object { $_.Result -eq 'No such host is known' }
    $LogToSQL = $True
    $null = $StatusOutput.add('Agent cannot resolve DNS for Huntress cloud servers. Fix DNS for domains below.')
    $StatusObject.HuntressServerDNSResolutionResults | ForEach-Object {
        $null = $StatusOutput.add("--- $($_.Host) -> $($_.Result)")
    }
    #$null = $StatusOutput.add($(($StatusObject.HuntressServerDNSResolutionResults | Out-String)).Trim())
}
else {
    $StatusObject.HuntressServerDNSResolutionError = $False
}

$NonDNSConnectivityResults = $ConnectivityTestResults | Where-Object { $_.Result -ne 'No such host is known' -and $_.Result -ne 'Connection Succeeded' }
if ($null -ne $NonDNSConnectivityResults) {
    $FailPolicy = $True
    $StatusObject.HuntressServerTCPConnectionError = $True
    $StatusObject.HuntressServerTCPConnectionResults = $NonDNSConnectivityResults
    $LogToSQL = $True
    $null = $StatusOutput.add('Found TCP connection errors. Agent cannot connect to port 443 for domains below.')
    $StatusObject.HuntressServerTCPConnectionResults | ForEach-Object {
        $null = $StatusOutput.add("--- $($_.Host) -> $($_.Result)")
    }
    #$StatusOutput.add('')
    #$null = $StatusOutput.add($(($StatusObject.HuntressServerTCPConnectionResults | Out-String)).Trim())
}
else {
    $StatusObject.HuntressServerTCPConnectionError = $False
}
# Row below ensures that the installation belongs to Impact and is at least installed properly
if ($StatusObject.RegistryPathExists -eq $True -and $StatusObject.InstallationPathExists -eq $True -and $StatusObject.AmpOrganizationKeyGood -eq $True -and $StatusObject.INCOrganizationKeyGood -eq $True -and $StatusObject.RegistryOrgKeyExists -eq $True) {
    $null = $StatusOutput.add("Org Key in registry is $($StatusObject.RegistryOrgKey)")
    if ($StatusObject.RegistryOrgKey.OrganizationKey -ne $orgKey -or $StatusObject.RegistryAccountKey.AccountKey -ne $accountKey) {
        $StatusObject.AgentInWrongOrganization = $True
        #$null = $StatusOutput.add("Org Key in registry is $($StatusObject.RegistryOrgKey.OrganizationKey)")
        $null = $StatusOutput.add("Org Key in Huntress is $($OrgKey) ")
        $null = $StatusOutput.add('Agent is in the wrong Organization')
    }
    else {
        $StatusObject.AgentInWrongOrganization = $False
        #$null = $StatusOutput.add("Org Key in registry is $($StatusObject.RegistryOrgKey.OrganizationKey)")
        $null = $StatusOutput.add("Org Key in Huntress is $($OrgKey) ")
        $null = $StatusOutput.add('Agent is in the correct Organization')
    }

    if ($StatusObject.AgentServiceStatus -ne 'Running' -and $StatusObject.AgentServiceExists -eq $True -and ($StatusObject.AgentInWrongOrganization -eq $False -and $StatusObject.AgentOrphaned -eq $False)) {
        $null = $StatusOutput.add('Agent Service Status not Running')
        if ($StatusObject.AgentServiceStartupType -ne 'Automatic') {
            $null = $StatusOutput.add('Agent Service StartupType not Automatic')
            if ($TestMode -eq $False) {
                Try {
                    Set-Service -Name HuntressAgent -StartupType Automatic -ErrorAction STOP
                    $StatusObject.AgentServiceStartupType = 'Automatic'
                    $OK = $True
                    $null = $StatusOutput.add('Set HuntressAgent StartupType to Automatic')
                }
                Catch {
                    $OK = $False
                    $null = $StatusOutput.add('Unable to Set HuntressAgent StartupType to Automatic')
                }
            }
            else { 
                $null = $StatusOutput.add("TestMode: Skipped 'Set-Service -Name HuntressAgent -StartupType Automatic -ErrorAction STOP'")
            }
            if ($OK) {
                if ($TestMode -eq $False) {
                    Try {
                        Start-Service -Name HuntressAgent -ErrorAction STOP
                        $StatusObject.AgentServiceFailedToStart = $False
                        $StatusObject.AgentServiceStatus = 'Running'
                        $null = $StatusOutput.add('Started HuntressAgent')
                    }
                    Catch {
                        $StatusObject.AgentServiceFailedToStart = $True
                        $null = $StatusOutput.add('Unable to start HuntressAgent')
                    }
                }
                else { 
                    $null = $StatusOutput.add("TestMode: Skipped 'Start-Service -Name HuntressAgent -ErrorAction STOP'")
                }
            }
        }
        elseif ($StatusObject.AgentServiceStartupType -eq 'Automatic') {
            if ($TestMode -eq $False) {
                Try {
                    Start-Service -Name HuntressAgent -ErrorAction STOP
                    $StatusObject.AgentServiceFailedToStart = $False
                    $StatusObject.AgentServiceStatus = 'Running'
                    $null = $StatusOutput.add('Started HuntressAgent')
                }
                Catch {
                    $null = $StatusOutput.add('Unable to start HuntressAgent')
                    $StatusObject.AgentServiceFailedToStart = $True
                }
            }
            else { 
                $null = $StatusOutput.add("TestMode: Skipped 'Start-Service -Name HuntressAgent -ErrorAction STOP'")
            }
        }
    }

    if ($StatusObject.AgentUpdaterServiceStatus -ne 'Running' -and $StatusObject.AgentUpdaterServiceExists -eq $True -and ($StatusObject.AgentInWrongOrganization -ne $True -or $StatusObject.AgentOrphaned -ne $True)) {
        if ($StatusObject.AgentUpdaterServiceStartupType -ne 'Automatic') {
            $StatusOutput.add('Agent Updater Service Status not Running')
            $StatusOutput.add('Agent Updater Service StartupType not Automatic')
            if ($TestMode -eq $False) {
                Try {
                    Set-Service -Name HuntressUpdater -StartupType Automatic -ErrorAction STOP
                    $StatusObject.AgentUpdaterServiceStartupType = 'Automatic'
                    $OK = $True
                    $null = $StatusOutput.add('Set HuntressUpdater StartupType to Automatic')
                }
                Catch {
                    $OK = $False
                    $null = $StatusOutput.add('Unable to Set HuntressUpdater StartupType to Automatic')
                }
            }
            else { 
                $null = $StatusOutput.add("TestMode: Skipped 'Set-Service -Name HuntressUpdater -StartupType Automatic -ErrorAction STOP'")
            }
            if ($OK) {
                if ($TestMode -eq $False) {
                    Try {
                        Start-Service -Name HuntressUpdater -ErrorAction STOP
                        $StatusObject.AgentUpdaterServiceFailedToStart = $False
                        $StatusObject.AgentUpdaterServiceStatus = 'Running'
                        $null = $StatusOutput.add('Started HuntressUpdater')
                    }
                    Catch {
                        $StatusObject.AgentUpdaterServiceFailedToStart = $True
                        $null = $StatusOutput.add('Unable to start HuntressUpdater')
                    }
                }
                else { 
                    $null = $StatusOutput.add("TestMode: Skipped 'Start-Service -Name HuntressUpdater -ErrorAction STOP'")
                }
            }
        }
        elseif ($StatusObject.AgentUpdaterServiceStartupType -eq 'Automatic') {
            if ($TestMode -eq $False) {
                Try {
                    Start-Service -Name HuntressUpdater -ErrorAction STOP
                    $StatusObject.AgentUpdaterServiceFailedToStart = $False
                    $StatusObject.AgentUpdaterServiceStatus = 'Running'
                    $null = $StatusOutput.add('Started HuntressUpdater')
                }
                Catch {
                    $StatusObject.AgentUpdaterServiceFailedToStart = $True
                    $null = $StatusOutput.add('Unable to start HuntressUpdater')
                }
            }
            else { 
                $null = $StatusOutput.add("TestMode: Skipped 'Start-Service -Name HuntressUpdater -ErrorAction STOP'") 
            }
        }
    }
    # Checks for every reason the agent might need to be uninstalled
    if ($StatusObject.AgentInWrongOrganization -eq $True -or $StatusObject.AgentOrphaned -eq $True -or $StatusObject.AgentUpdaterServiceFailedToStart -eq $True -or $StatusObject.AgentServiceFailedToStart -eq $True) {
        
        if ($TestMode -eq $False) {
            $null = $StatusOutput.add('Uninstalling Huntress')
            Start-Process -FilePath (Join-Path $StatusObject.installationPath 'Uninstall.exe') -ArgumentList '/S' -Wait -NoNewWindow

            if ((Get-Item 'HKLM:\SOFTWARE\Huntress Labs\Huntress' -ErrorAction SilentlyContinue)) {
                $FailPolicy = $True
                $null = $StatusOutput.add('Huntress agent uninstall failed')
            }
            else {
                $null = $StatusOutput.add('Huntress agent successfully removed')
            }
            $LogToSQL = $True
        }
        else {
            $null = $StatusOutput.add('TestMode: No uninstall performed')
        }
    }
    else {
        # Check services here?
        $null = $StatusOutput.add('No uninstallation remediation required at this time')
    }
}
elseif (($StatusObject.RegistryPathExists -ne $True -or $StatusObject.InstallationPathExists -ne $True) -and $StatusObject.AmpOrganizationKeyGood -eq $True -and $StatusObject.INCOrganizationKeyGood -eq $True) {
    # Delete some stuff

}
elseif ($StatusObject.AmpOrganizationKeyGood -ne $True -or $StatusObject.INCOrganizationKeyGood -or $True) {
    $null = $StatusOutput.add('No uninstallation remediation performed because the OrgKey is not valid')
}
else {
    $null = $StatusOutput.add('No uninstallation remediation required at this time')
}

if ($StatusObject.RegistryPathExists -ne $True -and $StatusObject.InstallationPathExists -ne $True -and $StatusObject.AmpOrganizationKeyGood -eq $True -and $StatusObject.INCOrganizationKeyGood -eq $True) {
    $StatusObject.AgentMissing = $True
    $LogToSQL = $True
    $FailPolicy = $True
    $null = $StatusOutput.add('Organization Key exists in INC, but Huntress agent is missing')
}

$StatusObject.OutputMessage = $StatusOutput
if ($LogToSQL -or $ForceLogToSQL) {
    # Force log is only set through the amp itself, default is false
    Try {
        $JSON_Body = $StatusObject | ConvertTo-Json -ErrorAction STOP
        $OK = $True
    }
    Catch {
        $OK = $False
        Write-Output 'Unable to convert output to JSON for Write-ImpactMessage, data not uploaded. Please inform Ops.'
    }
    if ($OK) {
        Write-ImpactMessage -loglevel E -scriptname 'Impact - HuntressAutoRepairAgents' -message $JSON_Body
    }
}

Write-Output $StatusOutput

