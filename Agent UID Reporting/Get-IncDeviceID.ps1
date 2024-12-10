# The purpose of this script is to get the unique Agent ID (DeviceID) and add it to the in agent reporting tool in order to identify which computer the report is coming from.
# This Script imports an XML file and extracts the Agent ID (DeviceID) from the executionerConfig.xml file within the N-Able directory.

try {
    # Check if the executionerConfig.xml file exists.
    if (Test-Path -Path ".\executionerConfig.xml") {
        try {
            # Import the XML file into a PowerShell object.
            $xml = [xml] (Get-Content -Path '.\executionerConfig.xml')
        } catch {
            Write-Error "Failed to read or parse the XML file."
        }
    } else {
        Write-Error 'The file ".\executionerConfig.xml" does not exist.'
    }

    # Check if the $xml variable is not null or empty.
    if ($xml) {
        try {
            # Convert the XML object to a string and search for the agentID pattern.
            $xmlString = $xml.OuterXml
            $match = [regex]::Match($xmlString, 'agentid=\d+')
            
            if ($match.Success) {
                # Extract the "AgentID='number value' from the match and store it into a variable.
                $line = $match.Value
                # Extract the number value from the line and store it into a variable.
                $DeviceID = -join ($line -split '\D+')
                Write-Output "DeviceID: $DeviceID"
            } else {
                Write-Error "DeviceID not found in the XML content."
            }
        } catch {
            Write-Error "An error occurred while searching for the DeviceID: $_"
        }
    } else {
        Write-Error "The XML content was not found."
    }
} catch {
    Write-Error "An unexpected error occurred: $_"
}