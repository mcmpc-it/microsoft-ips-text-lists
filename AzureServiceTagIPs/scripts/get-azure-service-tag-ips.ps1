# ============================================
# Azure Service Tags IP Export Script (Optimized + LatestJson folder)
# ============================================
 
# Define output folders inside GitHub workspace
$workspace     = $env:GITHUB_WORKSPACE
$outputFolder  = Join-Path $workspace "AzureServiceTagIPs/texts"       # For IPv4/IPv6 text files
$latestJsonDir = Join-Path $workspace "AzureServiceTagIPs/json"        # For JSON storage
$latestJson    = Join-Path $latestJsonDir "LatestServiceTags.json"     # Single JSON file
 
# Ensure AzureIPs output folder exists
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
}
 
# Ensure LatestJson folder exists and is cleared before writing
if (!(Test-Path $latestJsonDir)) {
    New-Item -ItemType Directory -Path $latestJsonDir -Force | Out-Null
} else {
    # Remove any existing content to guarantee only ServiceTags.json is present after run
    Get-ChildItem -Path $latestJsonDir -Force | Remove-Item -Force -Recurse
}
 
# Microsoft download page for Azure Service Tags
$downloadPageUrl = "https://www.microsoft.com/en-us/download/details.aspx?id=56519"
Write-Host "Fetching latest Azure Service Tags JSON link..."
 
try {
    # Fetch page content
    $pageContent = Invoke-WebRequest -Uri $downloadPageUrl -UseBasicParsing
 
    # Extract JSON URL using Links property (less brittle than regex)
    $jsonUrl = ($pageContent.Links | Where-Object { $_.href -like "*ServiceTags*" }).href
    if (-not $jsonUrl) { throw "Failed to extract JSON URL from page." }
 
    Write-Host "Latest JSON URL: $jsonUrl"
} catch {
    Write-Error "Error fetching JSON URL: $_"
    exit 1
}
 
# Download JSON file to LatestJson folder (overwrite guaranteed)
try {
    Invoke-WebRequest -Uri $jsonUrl -OutFile $latestJson
    Write-Host "Downloaded Service Tags JSON to $latestJson"
} catch {
    Write-Error "Failed to download JSON file: $_"
    exit 1
}
 
# Parse JSON from LatestJson folder
try {
    $data = Get-Content $latestJson | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON: $_"
    exit 1
}
 
# Process each service tag into AzureIPs folder
foreach ($service in $data.values) {
    $serviceName = $service.name
    $prefixes = $service.properties.addressPrefixes
 
    $ipv4 = @()
    $ipv6 = @()
 
    foreach ($prefix in $prefixes) {
        # Validate IP using System.Net.IPAddress (support CIDR by splitting)
        $ipPart = $prefix.Split('/')[0]
        if ([System.Net.IPAddress]::TryParse($ipPart, [ref]$null)) {
            if ($ipPart -like "*:*") { $ipv6 += $prefix } else { $ipv4 += $prefix }
        }
    }
 
    # Write IPv4 file
    if ($ipv4.Count -gt 0) {
        $ipv4File = Join-Path $outputFolder "$serviceName-IPv4.txt"
        $ipv4 | Sort-Object | Set-Content $ipv4File
    }
 
    # Write IPv6 file
    if ($ipv6.Count -gt 0) {
        $ipv6File = Join-Path $outputFolder "$serviceName-IPv6.txt"
        $ipv6 | Sort-Object | Set-Content $ipv6File
    }
}
 
Write-Host "Done!"
Write-Host "ServiceTags.json saved (and overwritten each run) at: $latestJson"
Write-Host "Per-service IPv4/IPv6 lists saved in: $outputFolder"
