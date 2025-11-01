<#
.SYNOPSIS
  Map embedded RSDS PDB names (flag_part_*.pdb) to their PE filenames.

.DESCRIPTION
  For each matching binary, runs: link -dump -headers <file>
  Parses CodeView (RSDS) entries and outputs a CSV and table:
    FileName, PdbName, GUID, Age, OffsetHex

  Usage:
    # default (all .exe in cwd)
    .\carve.ps1

    # specify pattern
    .\carve.ps1 -Pattern '*.bin'

    # save results to a custom file
    .\carve.ps1 -OutFile my_map.csv
#>

param(
    [string]$Pattern = '*.exe',
    [string]$OutFile = 'flag_part_map.csv',
    [switch]$Verbose
)

function Parse-LinkDumpLine {
    param($line)
    # Example line observed:
    # 68E7D8F0 cv            28 0001AC80    19C80    Format: RSDS, {B26C...}, 1, flag_part_5.pdb
    # Regex captures:
    #  - offsetHex (the column before "Format:")
    #  - GUID, age, pdb filename at end
    $regex = [regex]"cv\s+\S+\s+\S+\s+(?<offsetHex>[0-9A-Fa-f]+)\s+Format:\s*RSDS\s*,\s*\{(?<guid>[0-9A-Fa-f-]+)\}\s*,\s*(?<age>\d+)\s*,\s*(?<pdb>.+)$"
    $m = $regex.Match($line)
    if ($m.Success) {
        return @{
            offsetHex = $m.Groups['offsetHex'].Value
            guid      = $m.Groups['guid'].Value
            age       = [int]$m.Groups['age'].Value
            pdb       = $m.Groups['pdb'].Value.Trim()
        }
    }
    return $null
}

$results = @()

$files = Get-ChildItem -Path . -Filter $Pattern -File | Sort-Object Name
if (-not $files) {
    Write-Warning "No files matched pattern '$Pattern' in $(Get-Location)."
    return
}

foreach ($f in $files) {
    if ($Verbose) { Write-Host "[*] Inspecting $($f.Name)" -ForegroundColor Cyan }
    # Run link -dump -headers and capture output (stderr merged)
    # Note: ensure link.exe is on the PATH (VS Developer command prompt)
    $cmdOutput = & link -dump -headers $f.FullName 2>&1

    foreach ($line in $cmdOutput) {
        if ($line -match 'flag_part_') {
            $parsed = Parse-LinkDumpLine -line $line
            if ($parsed) {
                $obj = [PSCustomObject]@{
                    FileName  = $f.Name
                    OffsetHex = $parsed.offsetHex
                    GUID      = $parsed.guid
                    Age       = $parsed.age
                    PdbName   = $parsed.pdb
                }
                $results += $obj
                if ($Verbose) {
                    Write-Host ("  + {0} -> {1} (GUID {2}, age {3}, offset 0x{4})" -f $f.Name, $parsed.pdb, $parsed.guid, $parsed.age, $parsed.offsetHex)
                }
            } else {
                # If link produced a different formatting, attempt a looser parse
                # Try quick substring to extract the pdb name at end of line
                $last = $line.Trim() -split '\s+' | Select-Object -Last 1
                $obj = [PSCustomObject]@{
                    FileName  = $f.Name
                    OffsetHex = ''
                    GUID      = ''
                    Age       = ''
                    PdbName   = $last
                }
                $results += $obj
                if ($Verbose) { Write-Host "  + (loose parse) $($f.Name) -> $last" -ForegroundColor Yellow }
            }
        }
    }
}

if (-not $results) {
    Write-Warning "No 'flag_part_' entries were found in link output for files matching '$Pattern'."
} else {
    # De-duplicate and sort by PdbName then FileName
    $unique = $results | Sort-Object PdbName, FileName -Unique

    # Write to CSV
    $unique | Export-Csv -Path $OutFile -NoTypeInformation -Force

    # Pretty table to console
    Write-Host ""
    Write-Host "Mapping of binaries -> flag_part_*.pdb (written to $OutFile)" -ForegroundColor Green
    $unique | Format-Table -AutoSize

    # Also print a grouped view: for each pdb show which exe(s) reference it
    Write-Host "`nGrouped by PDB (which EXE points to this PDB):" -ForegroundColor Cyan
    $grouped = $unique | Group-Object PdbName
    foreach ($g in $grouped) {
        $pdb = $g.Name
        $exes = ($g.Group | Select-Object -ExpandProperty FileName) -join ", "
        $guids = ($g.Group | Select-Object -ExpandProperty GUID) -join ", "
        $offsets = ($g.Group | Select-Object -ExpandProperty OffsetHex) -join ", "
        Write-Host ("  {0} -> {1} (GUIDs: {2}; offsets: {3})" -f $pdb, $exes, $guids, $offsets)
    }
}

# end
