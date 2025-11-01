<#
.SYNOPSIS
    Scans an offline registry hive for "x of 8" patterns in value data
.DESCRIPTION
    Loads an offline registry hive and searches for patterns like x_of_8, x/8, x-8, xof8, -of-8 where x is 1-8 in registry value data
.PARAMETER HivePath
    Path to the offline registry hive file
.PARAMETER MountPoint
    Registry path where the hive will be temporarily mounted (default: HKLM\TempHive)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$HivePath,
    
    [Parameter(Mandatory=$false)]
    [string]$MountPoint = "HKLM\TempHive"
)

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges. Please run as administrator."
    exit 1
}

# Check if hive file exists
if (-not (Test-Path $HivePath)) {
    Write-Error "Hive file not found: $HivePath"
    exit 1
}

# Regex pattern to match x_of_8, x/8, x-8, xof8, x-of-8, xof-8 where x is 1-8
$pattern = '[1-8](_of_8|/8|-8|of8|-of-8|of-8)'

Write-Host "Loading hive from: $HivePath" -ForegroundColor Cyan
Write-Host "Mount point: $MountPoint" -ForegroundColor Cyan
Write-Host "Search pattern: $pattern" -ForegroundColor Cyan
Write-Host "Searching VALUE DATA only..." -ForegroundColor Cyan
Write-Host ""

# Load the hive
$loadResult = reg load $MountPoint $HivePath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to load hive: $loadResult"
    exit 1
}

Write-Host "Hive loaded successfully. Scanning..." -ForegroundColor Green
Write-Host ""

# Results collection
$results = @()
$flagChunks = @{}  # Hash table to store chunks by number

# Function to recursively search registry keys
function Search-RegistryKey {
    param(
        [string]$KeyPath
    )
    
    try {
        # Get the registry key
        $key = Get-Item -Path "Registry::$KeyPath" -ErrorAction SilentlyContinue
        
        if ($null -eq $key) {
            return
        }
        
        # Check all values in this key
        foreach ($valueName in $key.GetValueNames()) {
            # Check value data only
            $valueData = $key.GetValue($valueName)
            if ($valueData -is [string] -and $valueData -match $pattern) {
                $matchedPattern = $Matches[0]
                
                # Extract the number (1-8)
                if ($matchedPattern -match '^([1-8])') {
                    $chunkNumber = [int]$Matches[1]
                }
                
                $results += [PSCustomObject]@{
                    ChunkNumber = $chunkNumber
                    Path = $KeyPath
                    ValueName = $valueName
                    Data = $valueData
                    Match = $matchedPattern
                }
                
                # Store in flagChunks hash
                if (-not $flagChunks.ContainsKey($chunkNumber)) {
                    $flagChunks[$chunkNumber] = @()
                }
                $flagChunks[$chunkNumber] += $valueData
                
                Write-Host "[MATCH FOUND] Chunk $chunkNumber" -ForegroundColor Yellow
                Write-Host "  Path: $KeyPath\$valueName" -ForegroundColor Cyan
                Write-Host "  Data: $valueData" -ForegroundColor Green
                Write-Host "  Pattern: $matchedPattern" -ForegroundColor Magenta
                Write-Host ""
            }
        }
        
        # Recursively search subkeys
        foreach ($subKey in $key.GetSubKeyNames()) {
            Search-RegistryKey -KeyPath "$KeyPath\$subKey"
        }
    }
    catch {
        # Silently skip inaccessible keys
    }
}

# Start the search
try {
    Search-RegistryKey -KeyPath $MountPoint
}
finally {
    # Always unload the hive
    Write-Host "Unloading hive..." -ForegroundColor Cyan
    [gc]::Collect()
    Start-Sleep -Milliseconds 500
    
    $unloadResult = reg unload $MountPoint 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to unload hive cleanly: $unloadResult"
        Write-Warning "You may need to manually unload with: reg unload $MountPoint"
    } else {
        Write-Host "Hive unloaded successfully." -ForegroundColor Green
    }
}

# Display summary
Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "           SCAN COMPLETE" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Total matches found: $($results.Count)" -ForegroundColor Green
Write-Host ""

# Display flag chunks in order 1-8
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "        FLAG CHUNKS (In Order 1-8)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

for ($i = 1; $i -le 8; $i++) {
    Write-Host ""
    if ($flagChunks.ContainsKey($i)) {
        Write-Host "[$i of 8] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($flagChunks[$i] -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "[$i of 8] " -ForegroundColor Yellow -NoNewline
        Write-Host "NOT FOUND" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan

# Optionally export results
if ($results.Count -gt 0) {
    $exportPath = ".\registry_scan_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Sort-Object ChunkNumber | Export-Csv -Path $exportPath -NoTypeInformation
    Write-Host ""
    Write-Host "Detailed results exported to: $exportPath" -ForegroundColor Green
}