# Source and destination paths
$sourceBase = "Z:\Projects"
$destinationBase = "Y:\Projects"
$logFile = ".\FolderCopyLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Read project IDs from text file (one ID per line)
$idsFile = ".\FolderIDs.log"
if (-not (Test-Path $idsFile)) {
    Write-Host "Error: FolderIDs.log not found in current directory" -ForegroundColor Red
    exit
}

$projectIds = Get-Content $idsFile | Where-Object { $_.Trim() -ne "" }

# Preview and confirmation
$total = $projectIds.Count
Write-Host "`n=== Copy Preview ===" -ForegroundColor Yellow
Write-Host "Total project folders to copy: $total" -ForegroundColor Yellow
Write-Host "From: $sourceBase" -ForegroundColor Cyan
Write-Host "To:   $destinationBase`n" -ForegroundColor Cyan

Write-Host "First 5 projects:" -ForegroundColor White
$projectIds | Select-Object -First 5 | ForEach-Object { Write-Host "  \$_" }

if ($total -gt 10) {
    Write-Host "  ..." -ForegroundColor Gray
    Write-Host "Last 5 projects:" -ForegroundColor White
    $projectIds | Select-Object -Last 5 | ForEach-Object { Write-Host "  \$_" }
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

# Create log directory if it doesn't exist
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

# Start logging
"Copy started: $(Get-Date)" | Out-File -FilePath $logFile

$currentProject = 0
$succeededFiles = 0
$skippedFiles = 0
$failedFiles = 0
$missingFolders = 0

Write-Host "`nStarting copy...`n" -ForegroundColor Green

# Copy each project folder
foreach ($projectId in $projectIds) {
    $currentProject++
    $sourceFolder = Join-Path $sourceBase $projectId
    $destFolder = Join-Path $destinationBase $projectId
    
    Write-Host "[$currentProject/$total] Processing project: $projectId" -ForegroundColor Cyan
    
    if (Test-Path $sourceFolder) {
        # Create destination folder if it doesn't exist
        if (-not (Test-Path $destFolder)) {
            New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
        }
        
        # Get all files in the source folder
        $files = Get-ChildItem -Path $sourceFolder -File
        
        if ($files.Count -eq 0) {
            Write-Host "  Folder is empty" -ForegroundColor Gray
            "EMPTY FOLDER: \$projectId" | Out-File -FilePath $logFile -Append
        } else {
            Write-Host "  Found $($files.Count) file(s)" -ForegroundColor White
            
            foreach ($file in $files) {
                $destFile = Join-Path $destFolder $file.Name
                $relativePath = "\$projectId\$($file.Name)"
                
                # Check if destination file exists and skip if needed
                if ($skipExisting -and (Test-Path $destFile)) {
                    Write-Host "    Skipped: $($file.Name)" -ForegroundColor Yellow
                    "SKIPPED: $relativePath (already exists)" | Out-File -FilePath $logFile -Append
                    $skippedFiles++
                } else {
                    try {
                        Copy-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction Stop
                        Write-Host "    Copied: $($file.Name)" -ForegroundColor Green
                        "SUCCESS: $relativePath" | Out-File -FilePath $logFile -Append
                        $succeededFiles++
                    } catch {
                        Write-Host "    Failed: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
                        "FAILED: $relativePath - $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
                        $failedFiles++
                    }
                }
            }
        }
    } else {
        Write-Host "  Folder not found" -ForegroundColor Red
        "FOLDER NOT FOUND: \$projectId" | Out-File -FilePath $logFile -Append
        $missingFolders++
    }
}

# Summary
Write-Host "`n=== Copy Complete ===" -ForegroundColor Yellow
Write-Host "Projects processed: $total" -ForegroundColor Yellow
Write-Host "Files - Succeeded: $succeededFiles | Skipped: $skippedFiles | Failed: $failedFiles" -ForegroundColor Yellow
Write-Host "Missing folders: $missingFolders" -ForegroundColor Yellow
Write-Host "Log file: $logFile" -ForegroundColor Yellow

"" | Out-File -FilePath $logFile -Append
"Copy completed: $(Get-Date)" | Out-File -FilePath $logFile -Append
"Projects processed: $total" | Out-File -FilePath $logFile -Append
"Files - Succeeded: $succeededFiles | Skipped: $skippedFiles | Failed: $failedFiles" | Out-File -FilePath $logFile -Append
"Missing folders: $missingFolders" | Out-File -FilePath $logFile -Append