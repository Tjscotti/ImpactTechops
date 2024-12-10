# Define the URL of the website
$website = "https://huntress.io"

# Create a .NET WebRequest object for the URL
$request = [System.Net.HttpWebRequest]::Create($website)

# Set Security Protocols (TLS1.2 and TLS1.3 are recommended)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

# Retrieve the SSL Certificate from the response
$certificate = $request.ServicePoint.Certificate

# Output certificate details
$certificate| Format-List *
