Clear-Host
Write-Host @"
    __________    _____         
   / ____/ __ \ '/ ___/         
  / __/ / / / /  \__ \          
 / /___/ /_/ /  ___/ /          
/_____/_____/  /____/           
                                
    Azure Copy Tool
"@ -ForegroundColor Cyan

Write-Host "`nWelcome! Initialising..." -ForegroundColor Yellow
Write-Host "Please wait while modules load...`n" -ForegroundColor Gray

# Ensure Az.Storage module is available
#if (-not (Get-Module -ListAvailable -Name Az.Storage)) {
#    Write-Host "Installing Az.Storage module..." -ForegroundColor Yellow
#    Install-Module Az.Storage -Scope CurrentUser -Force
#}
Import-Module Az.Storage

# Global flag for graceful stop
$global:stopRequested = $false

# Register Ctrl+Break handler for graceful stop
[console]::TreatControlCAsInput = $true

# AzCopy configuration
$azcopyPath = ".\azcopy.exe"

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

if (-not (Test-Path $azcopyPath)) {
    Write-Host "Error: azcopy.exe not found at $azcopyPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

$sourceKey = (Get-Content $sourceKeyFile -Raw).Trim()
$destKey = (Get-Content $destKeyFile -Raw).Trim()


# Optional pre-set values (leave empty to prompt)
$preSourceAccount = ""
$preSourceShare   = ""
$preDestAccount   = ""
$preDestShare     = ""

Write-Host "`n=== Azure Storage Configuration ===" -ForegroundColor Yellow
Write-Host ""

# Source
if ([string]::IsNullOrWhiteSpace($preSourceAccount)) {
    $sourceAccount = Read-Host "Source storage account name"
} else {
    $sourceAccount = $preSourceAccount
}

if ([string]::IsNullOrWhiteSpace($preSourceShare)) {
    $sourceShare = Read-Host "Source share name (main folder)"
} else {
    $sourceShare = $preSourceShare
}

Write-Host ""

# Destination
if ([string]::IsNullOrWhiteSpace($preDestAccount)) {
    $destAccount = Read-Host "Destination storage account name"
} else {
    $destAccount = $preDestAccount
}

if ([string]::IsNullOrWhiteSpace($preDestShare)) {
    $sameShare = Read-Host "Is the destination share name the same as source? (Y/N)"
    if ($sameShare -eq 'Y' -or $sameShare -eq 'y') {
        $destShare = $sourceShare
    } else {
        $destShare = Read-Host "Destination share name"
    }
} else {
    $destShare = $preDestShare
}


# Generate SAS tokens using Az.Storage (12 hour expiry)
Write-Host "`nGenerating SAS tokens..." -ForegroundColor Cyan

$sourceCtx = New-AzStorageContext -StorageAccountName $sourceAccount -StorageAccountKey $sourceKey
$destCtx = New-AzStorageContext -StorageAccountName $destAccount -StorageAccountKey $destKey

$sourceSasToken = New-AzStorageShareSASToken -Name $sourceShare -Context $sourceCtx -Permission "rl" -ExpiryTime (Get-Date).AddHours(12)
$destSasToken = New-AzStorageShareSASToken -Name $destShare -Context $destCtx -Permission "rwdlc" -ExpiryTime (Get-Date).AddHours(12)

# Build share URLs
$sourceShareUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare?$sourceSasToken"
$destShareUrl = "https://$destAccount.file.core.windows.net/$destShare?$destSasToken"

#Write-Host "Debug - Source SAS: $sourceSasToken" -ForegroundColor Gray
#Write-Host "Debug - Source URL: $sourceShareUrl" -ForegroundColor Gray
#Write-Host "Debug - Dest SAS: $destSasToken" -ForegroundColor Gray
#Write-Host "Debug - Dest URL: $destShareUrl" -ForegroundColor Gray
#
## Verify shares exist
#Write-Host "`nVerifying storage shares..." -ForegroundColor Cyan
#
#Write-Host "Debug - sourceAccount: $sourceAccount" -ForegroundColor Gray
#Write-Host "Debug - sourceShare: $sourceShare" -ForegroundColor Gray
#Write-Host "Debug - sourceSasToken length: $($sourceSasToken.Length)" -ForegroundColor Gray
#Write-Host "Debug - destAccount: $destAccount" -ForegroundColor Gray
#Write-Host "Debug - destShare: $destShare" -ForegroundColor Gray
#Write-Host "Debug - destSasToken length: $($destSasToken.Length)" -ForegroundColor Gray


##$sourceCheck = & $azcopyPath list "https://dccproject.file.core.windows.net/projects2?sv=2025-07-05&spr=https&st=2025-10-20T15%3A19%3A52Z&se=2025-10-21T15%3A19%3A52Z&sr=s&sp=rwl&sig=H%2FRZGTmvrTE0a%2BSogRTBsWwce7cybyTeQTOutYLyfds%3D" --output-type=text 2>&1 | Out-String
#$sourceCheck = & $azcopyPath list --output-type=text 2>&1 | Out-String
#
#if ($LASTEXITCODE -ne 0) {
#    Write-Host "Error: Cannot access source share '$sourceAccount/$sourceShare'" -ForegroundColor Red
#    Write-Host "Check that the account name, share name, and key are correct." -ForegroundColor Red
#    Write-Host "`nAzCopy output:" -ForegroundColor Red
#    Write-Host $sourceCheck -ForegroundColor Red
#    Read-Host "Press Enter to exit"
#    exit
#}
#
#$destCheck = & $azcopyPath list $destShareUrl --output-type=text | Select-Object -First 1
#if ($LASTEXITCODE -ne 0) {
#    Write-Host "Error: Cannot access destination share '$destAccount/$destShare'" -ForegroundColor Red
#    Write-Host "Check that the account name, share name, and key are correct." -ForegroundColor Red
#    Read-Host "Press Enter to exit"
#    exit
#}
#
#Write-Host "Both shares verified successfully." -ForegroundColor Green

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
$pathsFile = ".\ItemPaths.log"
if (-not (Test-Path $pathsFile)) {
    Write-Host "Error: ItemPaths.log not found in current directory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

$itemPaths = Get-Content $pathsFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim().TrimStart('.', '\', '/') }
if ($itemPaths.Count -eq 0) {
    Write-Host "Error: ItemPaths.log is empty" -ForegroundColor Red
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

#Write-Host ""
#$checkExistence = Read-Host "Check if all items exist before starting? (Y/N)"
#
#$notFound = @()
#if ($checkExistence -eq 'Y' -or $checkExistence -eq 'y') {
#    Write-Host "`nChecking source items..." -ForegroundColor Cyan
#    
#    foreach ($itemPath in $itemPaths) {
#        $checkPath = Split-Path $itemPath -Parent
#        if ([string]::IsNullOrEmpty($checkPath)) { $checkPath = "" }
#        
#        $checkUrl = "https://$sourceAccount.file.core.windows.net/$sourceShare/$checkPath?$sourceSasToken"
#        $itemName = Split-Path $itemPath -Leaf
#        
#        $output = & $azcopyPath list $checkUrl --output-type=text 2>&1 | Out-String
#        
#        if ($output -notmatch [regex]::Escape($itemName)) {
#            $notFound += $itemPath
#        }
#    }
#    
#    if ($notFound.Count -gt 0) {
#        Write-Host "`n$($notFound.Count) item(s) not found in source:" -ForegroundColor Red
#        $notFound | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
#        Write-Host ""
#        $proceedAnyway = Read-Host "Proceed anyway? (Y/N)"
#        if ($proceedAnyway -ne 'Y' -and $proceedAnyway -ne 'y') {
#            Write-Host "Copy cancelled." -ForegroundColor Yellow
#            Read-Host "Press Enter to exit"
#            exit
#        }
#    } else {
#        Write-Host "All items found in source." -ForegroundColor Green
#    }
#}

Write-Host ""
$confirmation = Read-Host "Proceed with copy? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Copy cancelled." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
$overwriteMode = Read-Host "If file already exists - Overwrite (O) or Skip (S)?"
$skipExisting = ($overwriteMode -eq 'S' -or $overwriteMode -eq 's')

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
    # Check for graceful stop request
    if ([console]::KeyAvailable) {
        $key = [console]::ReadKey($true)
        if ($key.Key -eq 'Pause' -or ($key.Modifiers -eq 'Control' -and $key.Key -eq 'C')) {
            Write-Host "`n*** Graceful stop requested. Finishing current item... ***" -ForegroundColor Yellow
            $global:stopRequested = $true
        }
    }
    
    if ($global:stopRequested) {
        Write-Host "Stopping after last completed item." -ForegroundColor Yellow
        break
    }
    
    $current++    
    $attempt = 0
    $maxAttempts = 2
    $completed = $false

    # Determine if it's a file or folder
    $isFile = [System.IO.Path]::HasExtension($itemPath)

    # Build source and destination URLs with SAS tokens
    if ($isFile) {
        $sourceUrl = "https://${sourceAccount}.file.core.windows.net/${sourceShare}/${itemPath}?${sourceSasToken}"
    } else {
        $sourceUrl = "https://${sourceAccount}.file.core.windows.net/${sourceShare}/${itemPath}/*?${sourceSasToken}"
    }
    $destUrl = "https://${destAccount}.file.core.windows.net/${destShare}/${itemPath}?${destSasToken}"

    Write-Host "[$current/$total] Copying: $itemPath" -ForegroundColor Cyan

    # Log the URLs being used (for debugging)
    #Write-Host "item path: $itemPath"
    #Write-Host "sourceURL: $sourceUrl"
    #Write-Host "destURL: $destUrl"

    #"SOURCE URL: $sourceUrl" | Out-File -FilePath $logFile -Append
    #"DEST URL:   $destUrl"   | Out-File -FilePath $logFile -Append

    while (-not $completed -and $attempt -lt $maxAttempts) {
        $attempt++

        if ($isFile) {
            if ($skipExisting) {
                $output = & $azcopyPath copy $sourceUrl $destUrl --overwrite=false --output-type=text 2>&1
            } else {
                $output = & $azcopyPath copy $sourceUrl $destUrl --overwrite=true --output-type=text 2>&1
            }
        } else {
            if ($skipExisting) {
                $output = & $azcopyPath copy $sourceUrl $destUrl --recursive --overwrite=false --output-type=text 2>&1
            } else {
                $output = & $azcopyPath copy $sourceUrl $destUrl --recursive --overwrite=true --output-type=text 2>&1
            }
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Success" -ForegroundColor Green
            "SUCCESS: $itemPath" | Out-File -FilePath $logFile -Append
            $succeeded++
            $completed = $true
        } else {
            Write-Host "  Attempt $attempt failed" -ForegroundColor Red
            $output | Out-File -FilePath $logFile -Append
            if ($attempt -ge $maxAttempts) {
                Write-Host "  Max attempts reached for $itemPath" -ForegroundColor Red
                do {
                    $choice = Read-Host "Choose: Retry (R), Skip (S), End (E)"
                } while ($choice -notin @('R','r','S','s','E','e'))

                switch ($choice.ToUpper()) {
                    'R' { $attempt = 0 } # reset attempts to retry
                    'S' { $failed++; $completed = $true } # skip to next
                    'E' { 
                        Write-Host "`n=== Copy Aborted by User ===" -ForegroundColor Yellow
                        "" | Out-File -FilePath $logFile -Append
                        "Az aborted: $(Get-Date)" | Out-File -FilePath $logFile -Append
                        "Total: $total | Succeeded: $succeeded | Failed: $failed" | Out-File -FilePath $logFile -Append
                        return
                    }
                }
            } else {
                Start-Sleep -Seconds 2 # small delay before retry
            }
        }
    }

    if (-not $completed -and $attempt -ge $maxAttempts) {
        Write-Host "  Failed after $maxAttempts attempts" -ForegroundColor Red
        "FAILED: $itemPath after $maxAttempts attempts" | Out-File -FilePath $logFile -Append
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