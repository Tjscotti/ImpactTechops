   
   #The purpose of this script is to get the unique Customer ID and add it to the in agent reporting tool in order to identify which customer the report is coming from.
   #This Script imports an XML file and extracts the Customer ID from the AgentMaintenanceSchedules.xml file within the N-Able directory.
   
   try {
    # Check if the AgentMaintenanceSchedules.xml file exists.
    if (Test-Path -Path "	C:\Program Files (x86)\N-Able Technologies\Windows Agent\config\AgentMaintenanceSchedules.xml") {
        try {
            # Import the XML file into a PowerShell object.
            $xml = [xml] (Get-Content -Path "C:\Program Files (x86)\N-Able Technologies\Windows Agent\config\AgentMaintenanceSchedules.xml")
        } catch {
            Write-Error "Failed to read or parse the XML file."
        }
    } else {
        Write-Error 'The file "AgentMaintenanceSchedules.xml" does not exist.'
    }

    # Check if the $xml variable is not null or empty and if the RebootMessageLogoURL property exists.
    if ($xml -and $xml.AgentMaintenanceSchedules.RebootMessageLogoURL) {
        try {
            # Extract the line containing the Customer ID.
            $line = $xml.AgentMaintenanceSchedules.RebootMessageLogoURL
           
            # Extract the Customer ID from the line and store it into a variable.
            $CustomerID = [regex]::Match($line, '\d+').Value
        } catch {
            if (-not $CustomerID) {
                Write-Error "Customer ID is null or empty."
            }
        }
    } else {
        Write-Error "The XML content is invalid or the RebootMessageLogoURL property does not exist."
    }
} catch {
    Write-Error "An unexpected error occurred: $_"
}