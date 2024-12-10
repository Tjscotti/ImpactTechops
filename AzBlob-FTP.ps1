# Authenticate with Azure using Managed Identity
$azContext = (Get-AzContext).Account.Id
if (-not $azContext) {
    Connect-AzAccount -Identity
}

# Define variables
$localFilePath = "C:\path\to\your\local\file.txt"
$ftpServer = "ftp://yourstorageaccountname.blob.core.windows.net"
$ftpUsername = "yourstorageaccountname"
$ftpPassword = "yourstorageaccountkey"
$remoteFilePath = "/containername/file.txt"

# Create a WebClient object
$webClient = New-Object System.Net.WebClient
$webClient.Credentials = New-Object System.Net.NetworkCredential($ftpUsername, $ftpPassword)

# Upload the file
$webClient.UploadFile("$ftpServer$remoteFilePath", $localFilePath)

# Clean up
$webClient.Dispose()