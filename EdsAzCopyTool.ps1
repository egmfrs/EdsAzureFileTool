# AzCopy configuration
$azcopyPath = ".\azcopy.exe"  # Update if azcopy.exe is in a different location

# Read keys from files
$sourceKeyFile = ".\KeyOfSrc.log"
$destKeyFile = ".\KeyOfDest.log"

if (-not (Test-Path $sourceKeyFile)) {
    Write-Host "Error: KeyOfSrc.log not found in current directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if (-not (Test-Path $destKeyFile)) {
    Write-Host "Error: KeyOfDest.log not found in current directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

$sourceKey = (Get-Content $sourceKeyFile -Raw).Trim()
$destKey = (Get-Content $destKeyFile -Raw).Trim()

# Get storage account details from user
Write-Host "`n=== Azure Storage Configuration ===" -ForegroundColor Yellow
Write-Host ""

$sourceAccount = Read-Host "Source storage account name"
$sourceShare = Read-Host "Source share name (main folder)"
Write-Host ""
$destAccount = Read-Host "Destination storage account name"
$sameShare = Read-Host "Is the destination share name the same as source? (Y/N)"

if ($sameShare -eq 'Y' -or $sameShare -eq 'y') {
    $destShare = $sourceShare
} else {
    $destShare = Read-Host "Destination share name (main folder)"
}

# Verify shares exist
Write-Host "`nVerifying storage shares..." -ForegroundColor Cyan

$sourceShareUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare"
$destShareUrl = "https://$destAccount.file.core.windows.net/$destShare"

# Set source account credentials
$env:AZCOPY_ACCOUNT_NAME = $sourceAccount
$env:AZCOPY_ACCOUNT_KEY = $sourceKey

$sourceCheck = & $azcopyPath list $sourceShareUrl --output-type=text 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Cannot access source share '$sourceAccount/$sourceShare'" -ForegroundColor Red
    Write-Host "Check that the account name, share name, and key are correct." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Set destination account credentials
$env:AZCOPY_ACCOUNT_NAME = $destAccount
$env:AZCOPY_ACCOUNT_KEY = $destKey

$destCheck = & $azcopyPath list $destShareUrl --output-type=text 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Cannot access destination share '$destAccount/$destShare'" -ForegroundColor Red
    Write-Host "Check that the account name, share name, and key are correct." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}


Write-Host "Both shares verified successfully." -ForegroundColor Green

# Confirm source and destination roles
Write-Host "`n=== IMPORTANT: Confirm Copy Direction ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "SOURCE (read-only): $sourceAccount/$sourceShare" -ForegroundColor Cyan
Write-Host "  - This is the master location containing your files" -ForegroundColor Gray
Write-Host "  - Nothing will be written to or changed in this location" -ForegroundColor Gray
Write-Host ""
Write-Host "DESTINATION (will be modified): $destAccount/$destShare" -ForegroundColor Magenta
Write-Host "  - Files will be copied here" -ForegroundColor Gray
Write-Host "  - Existing files may be overwritten depending on your choice" -ForegroundColor Gray
Write-Host ""
$confirmDirection = Read-Host "Is this correct? (Y/N)"
if ($confirmDirection -ne 'Y' -and $confirmDirection -ne 'y') {
    Write-Host "Operation cancelled. Please restart and enter the correct accounts." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# Log file
$logFile = ".\AzCopyLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Read item paths from text file
$pathsFile = ".\ItemPaths.txt"
if (-not (Test-Path $pathsFile)) {
    Write-Host "Error: ItemPaths.txt not found in current directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if (-not (Test-Path $azcopyPath)) {
    Write-Host "Error: azcopy.exe not found at $azcopyPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

$itemPaths = Get-Content $pathsFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim().TrimStart(".\", "/", "\") }

if ($itemPaths.Count -eq 0) {
    Write-Host "Error: ItemPaths.txt is empty" -ForegroundColor Red
    Write-Host ""
    Write-Host "Example usage - add paths like these (one per line):" -ForegroundColor Yellow
    Write-Host "  Projects/123456" -ForegroundColor Gray
    Write-Host "  Projects/InspectionImages/2345678.B64" -ForegroundColor Gray
    Write-Host "  Projects/789012" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Each line can be either:" -ForegroundColor Yellow
    Write-Host "  - A folder path (will copy entire folder)" -ForegroundColor Gray
    Write-Host "  - A file path (will copy just that file)" -ForegroundColor Gray
    Read-Host "Press Enter to exit"
    exit
}

# Preview
$total = $itemPaths.Count
Write-Host "`n=== AzCopy Preview ===" -ForegroundColor Yellow
Write-Host "Total items to copy: $total" -ForegroundColor Yellow
Write-Host "From: $sourceAccount/$sourceShare" -ForegroundColor Cyan
Write-Host "To:   $destAccount/$destShare`n" -ForegroundColor Cyan

Write-Host "First 5 items:" -ForegroundColor White
$itemPaths | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" }

if ($total -gt 10) {
    Write-Host "  ..." -ForegroundColor Gray
    Write-Host "Last 5 items:" -ForegroundColor White
    $itemPaths | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
$checkExistence = Read-Host "Check if all items exist before starting? (Y/N)"

$notFound = @()
if ($checkExistence -eq 'Y' -or $checkExistence -eq 'y') {
    Write-Host "`nChecking source items..." -ForegroundColor Cyan
    
    foreach ($itemPath in $itemPaths) {
        $sourceUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare/$itemPath`?$sourceKey"
        
        # Use AzCopy list to check existence (checking parent directory)
        $checkPath = Split-Path $itemPath -Parent
        if ([string]::IsNullOrEmpty($checkPath)) { $checkPath = "" }
        
        $checkUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare/$checkPath`?$sourceKey"
        $itemName = Split-Path $itemPath -Leaf
        
        $output = & $azcopyPath list $checkUrl --output-type=text 2>&1 | Out-String
        
        if ($output -notmatch [regex]::Escape($itemName)) {
            $notFound += $itemPath
        }
    }
    
    if ($notFound.Count -gt 0) {
        Write-Host "`n$($notFound.Count) item(s) not found in source:" -ForegroundColor Red
        $notFound | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
        $proceedAnyway = Read-Host "Proceed anyway? (Y/N)"
        if ($proceedAnyway -ne 'Y' -and $proceedAnyway -ne 'y') {
            Write-Host "Copy cancelled." -ForegroundColor Yellow
            Read-Host "Press Enter to exit"
            exit
        }
    } else {
        Write-Host "All items found in source." -ForegroundColor Green
    }
}

Write-Host ""
$confirmation = Read-Host "Proceed with copy? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Copy cancelled." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

# Start logging
"AzCopy started: $(Get-Date)" | Out-File -FilePath $logFile
"Total items: $total" | Out-File -FilePath $logFile -Append
if ($notFound.Count -gt 0) {
    "Items not found in source check: $($notFound.Count)" | Out-File -FilePath $logFile -Append
    $notFound | ForEach-Object { "  NOT FOUND: $_" | Out-File -FilePath $logFile -Append }
}
"" | Out-File -FilePath $logFile -Append

Write-Host "`nStarting AzCopy transfer...`n" -ForegroundColor Green

$current = 0
$succeeded = 0
$failed = 0

foreach ($itemPath in $itemPaths) {
    $current++
    
    # Determine if it's a file or folder based on extension
    $isFile = [System.IO.Path]::HasExtension($itemPath)
    
    # Build source and destination URLs with account keys as connection strings
    $sourceUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare/$itemPath"
    $destUrl = "https://$destAccount.file.core.windows.net/$destShare/$itemPath"
    
    Write-Host "[$current/$total] Copying: $itemPath" -ForegroundColor Cyan
    
    # Run AzCopy with source and destination keys
    # Use --source-account-key and destination will use env variable
    $env:AZCOPY_ACCOUNT_KEY = $destKey
    
    if ($isFile) {
        $output = & $azcopyPath copy $sourceUrl $destUrl --source-account-key=$sourceKey --output-type=text 2>&1
    } else {
        $output = & $azcopyPath copy $sourceUrl $destUrl --source-account-key=$sourceKey --recursive --output-type=text 2>&1
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Success" -ForegroundColor Green
        "SUCCESS: $itemPath" | Out-File -FilePath $logFile -Append
        $succeeded++
    } else {
        Write-Host "  Failed" -ForegroundColor Red
        "FAILED: $itemPath" | Out-File -FilePath $logFile -Append
        $output | Out-File -FilePath $logFile -Append
        $failed++
    }
}

# Summary
Write-Host "`n=== Copy Complete ===" -ForegroundColor Yellow
Write-Host "Total: $total | Succeeded: $succeeded | Failed: $failed" -ForegroundColor Yellow
Write-Host "Log file: $logFile" -ForegroundColor Yellow

"" | Out-File -FilePath $logFile -Append
"AzCopy completed: $(Get-Date)" | Out-File -FilePath $logFile -Append
"Total: $total | Succeeded: $succeeded | Failed: $failed" | Out-File -FilePath $logFile -Append