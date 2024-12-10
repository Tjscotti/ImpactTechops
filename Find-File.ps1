# This script searches the filesystem for files containing the words "DeviceID" or "CustomerID"

# Define the path to search
$searchPath = "~\downloads"

# Define the words to search for
$searchWords = @("Schwab")

# Get all files in the specified path and its subdirectories
$files = Get-ChildItem -Path $searchPath -Recurse -File

foreach ($file in $files) {
    try {
        # Read the content of the file
        $content = Get-Content -Path $file.Name -Raw

        # Check if the content contains any of the search words
        foreach ($word in $searchWords) {
            if ($content -match $word) {
                Write-Output "File '$($file.Name)' contains the word '$word'"
            }
        }
    } catch {
        Write-Error "Failed to process file '$($file.Name)': $_"
    }
                
}

<# Define multiple paths to search
$searchPaths = @("C:\Path\To\Search1", "C:\Path\To\Search2", "C:\Path\To\Search3")

foreach ($searchPath in $searchPaths) {
    # Get all files in the specified path and its subdirectories
    $files = Get-ChildItem -Path $searchPath -Recurse -File

    foreach ($file in $files) {
        # Read the content of the file
        $content = Get-Content -Path $file.FullName -Raw

        # Check if the content contains any of the search words
        foreach ($word in $searchWords) {
            if ($content -match $word) {
                Write-Output "File '$($file.FullName)' contains the word '$word'"
                break
            }
        }
    }
#>}