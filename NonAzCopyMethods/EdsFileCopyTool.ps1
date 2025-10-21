# Source and destination paths
$source = "Z:\Projects\InspectionImages"
$destination = "Y:\Projects\InspectionImages"
$logFile = ".\CopyLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Read file IDs from text file (one ID per line)
$idsFile = ".\FileIDs.log"
if (-not (Test-Path $idsFile)) {
    Write-Host "Error: FileIDs.log not found in current directory" -ForegroundColor Red
    exit
}

$fileIds = Get-Content $idsFile | Where-Object { $_.Trim() -ne "" }

# Preview and confirmation
$total = $fileIds.Count
Write-Host "`n=== Copy Preview ===" -ForegroundColor Yellow
Write-Host "Total files to copy: $total" -ForegroundColor Yellow
Write-Host "From: $source" -ForegroundColor Cyan
Write-Host "To:   $destination`n" -ForegroundColor Cyan

Write-Host "First 5 files:" -ForegroundColor White
$fileIds | Select-Object -First 5 | ForEach-Object { Write-Host "  $_.B64" }

if ($total -gt 10) {
    Write-Host "  ..." -ForegroundColor Gray
    Write-Host "Last 5 files:" -ForegroundColor White
    $fileIds | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_.B64" }
}

Write-Host ""
$overwriteMode = Read-Host "If file already exists in destination - Skip (S) or Overwrite (O)?"
if ($overwriteMode -ne 'S' -and $overwriteMode -ne 's' -and $overwriteMode -ne 'O' -and $overwriteMode -ne 'o') {
    Write-Host "Invalid option. Please enter S or O." -ForegroundColor Red
    exit
}
$skipExisting = ($overwriteMode -eq 'S' -or $overwriteMode -eq 's')

Write-Host ""
$confirmation = Read-Host "Proceed with copy? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Copy cancelled." -ForegroundColor Yellow
    exit
}

# Create destination folder if it doesn't exist
if (-not (Test-Path $destination)) {
    New-Item -Path $destination -ItemType Directory -Force
}

# Create log directory if it doesn't exist
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

# Start logging
"Copy started: $(Get-Date)" | Out-File -FilePath $logFile

$current = 0
$succeeded = 0
$failed = 0
$skipped = 0

Write-Host "`nStarting copy...`n" -ForegroundColor Green

# Copy each file
foreach ($id in $fileIds) {
    $current++
    $fileName = "$id.B64"
    $sourceFile = Join-Path $source $fileName
    $destFile = Join-Path $destination $fileName
    
    Write-Host "[$current/$total] Processing: $fileName" -ForegroundColor Cyan
    
    if (Test-Path $sourceFile) {
        # Check if destination file exists and skip if needed
        if ($skipExisting -and (Test-Path $destFile)) {
            Write-Host "  Skipped (already exists)" -ForegroundColor Yellow
            "SKIPPED: $fileName (already exists)" | Out-File -FilePath $logFile -Append
            $skipped++
        } else {
            try {
                Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop
                Write-Host "  Copied successfully" -ForegroundColor Green
                "SUCCESS: $fileName" | Out-File -FilePath $logFile -Append
                $succeeded++
            } catch {
                Write-Host "  Copy failed: $($_.Exception.Message)" -ForegroundColor Red
                "FAILED: $fileName - $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
                $failed++
            }
        }
    } else {
        Write-Host "  File not found" -ForegroundColor Red
        "NOT FOUND: $fileName" | Out-File -FilePath $logFile -Append
        $failed++
    }
}

# Summary
Write-Host "`n=== Copy Complete ===" -ForegroundColor Yellow
Write-Host "Total: $total | Succeeded: $succeeded | Skipped: $skipped | Failed: $failed" -ForegroundColor Yellow
Write-Host "Log file: $logFile" -ForegroundColor Yellow

"" | Out-File -FilePath $logFile -Append
"Copy completed: $(Get-Date)" | Out-File -FilePath $logFile -Append
"Total: $total | Succeeded: $succeeded | Skipped: $skipped | Failed: $failed" | Out-File -FilePath $logFile -Append