# Check if the CSV file exists
if (Test-Path -Path $csvFilePath) {
    Write-Host "CSV file exported successfully to $csvFilePath"
} else {
    Write-Host "Failed to export the CSV file."
}