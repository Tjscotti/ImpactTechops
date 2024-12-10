   
   #The purpose of this script is to get the unique Agent ID (ApplianceID) and add it to the in agent reporting tool in order to identify which customer the report is coming from.
   #This Script imports an XML file and extracts the Agent ID (ApplianceID) from the Applianceconfig.xml file within the N-Able directory.
   
   try {
    # Check if the Applianceconfig.xml file exists.
    if (Test-Path -Path " .\Applianceconfig.xml") {
        try {
            # Import the XML file into a PowerShell object.
            $xml = [xml] (Get-Content -Path '.\Applianceconfig.xml')
        } catch {
            Write-Error "Failed to read or parse the XML file."
        }
    } else {
        Write-Error 'The file "Applianceconfig.xml" does not exist.'
    }

    # Check if the $xml variable is not null or empty and if the Applianceconfig.ApplianceID property exists.
    if ($xml -and $xml.Applianceconfig.ApplianceID) {
        $AgentID = $xml.Applianceconfig.ApplianceID
    } else {
        Write-Error "The XML content is invalid or the Applianceconfig property does not exist."
    }
} catch {
    Write-Error "An unexpected error occurred: $_"
}


