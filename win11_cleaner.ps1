#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 11 System Cleaner v1.2
.DESCRIPTION
    A comprehensive cleaning script for Windows 11.
    Cleans temporary files, caches, logs, browser data, and more.
    Must be run as Administrator.
.NOTES
    Created: 2026
    Supports: Windows 11
#>

# ============================================================
#  ADMIN CHECK
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script as Administrator..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# ============================================================
#  VARIABLES & LOGGING
# ============================================================
$LogFile = "$env:USERPROFILE\Desktop\Win11_Cleaner_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$TotalFreed = 0

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Host "$timestamp - $Message" -ForegroundColor Gray
}

function Get-FolderSize {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
    } catch {
        return 0
    }
    return 0
}

function Remove-ItemsSafe {
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) {
        Log "SKIP [$Label] - Path does not exist: $Path"
        return
    }
    
    $sizeBefore = Get-FolderSize -Path $Path
    try {
        # Remove all files first
        Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        
        # Remove all empty directories
        Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        
        $script:TotalFreed += $sizeBefore
        Log "DONE [$Label] - Freed approx ${sizeBefore} MB"
    } catch {
        Log "ERROR [$Label] - $($_.Exception.Message)"
    }
}

# ============================================================
#  BANNER
# ============================================================
Clear-Host
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       WINDOWS 11 SYSTEM CLEANER v1.2       " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log will be saved to: $LogFile" -ForegroundColor DarkGray
Write-Host ""
Log "===== CLEANING SESSION STARTED ====="
Write-Host ""

# ============================================================
#  MENU
# ============================================================
Write-Host "--- TEMPORARY FILES + CACHES ---" -ForegroundColor Yellow
Write-Host " [1]  Windows Temp Folder"
Write-Host " [2]  User Temp Folder"
Write-Host " [3]  Windows Update Cache"
Write-Host " [4]  Prefetch Files"
Write-Host ""
Write-Host "--- BROWSER CACHES ---" -ForegroundColor Yellow
Write-Host " [5]  Microsoft Edge Cache"
Write-Host " [6]  Google Chrome Cache"
Write-Host " [7]  Mozilla Firefox Cache"
Write-Host " [18] Brave Browser Cache"
Write-Host ""
Write-Host "--- WINDOWS LOGS + DIAGNOSTICS ---" -ForegroundColor Yellow
Write-Host " [8]  Windows Event Logs"
Write-Host " [9]  Windows Diagnostic Traces"
Write-Host " [10] CBS (Component-Based Servicing) Logs"
Write-Host ""
Write-Host "--- RECYCLE BIN + RESTORE ---" -ForegroundColor Yellow
Write-Host " [11] Empty Recycle Bin (All Drives)"
Write-Host " [12] Old Shadow Copies / Restore Points"
Write-Host ""
Write-Host "--- STARTUP + PERFORMANCE ---" -ForegroundColor Yellow
Write-Host " [19] Clear Windows Performance Counters"
Write-Host ""
Write-Host "--- DISK + STORAGE ---" -ForegroundColor Yellow
Write-Host " [20] Run Windows Disk Cleanup (automated)"
Write-Host " [21] Microsoft Store Cache"
Write-Host ""
Write-Host "--- APP + SYSTEM RESIDUAL ---" -ForegroundColor Yellow
Write-Host " [24] Windows Notification Cache"
Write-Host " [25] Recent Files + Jump List Cache"
Write-Host ""
Write-Host "--- WINDOWS SEARCH + INDEXING ---" -ForegroundColor Yellow
Write-Host " [15] Rebuild Windows Search Index"
Write-Host ""
Write-Host "--- THUMBNAIL + ICON CACHES ---" -ForegroundColor Yellow
Write-Host " [16] Thumbnail Cache"
Write-Host " [17] Icon Cache (IconCache.db)"
Write-Host ""
Write-Host "--- NETWORK ---" -ForegroundColor Yellow
Write-Host " [26] Flush DNS Cache"
Write-Host " [27] Reset TCP/IP Stack"
Write-Host ""
Write-Host "--- WINDOWS TELEMETRY + LOGS ---" -ForegroundColor Yellow
Write-Host " [28] Delivery Optimization Cache (DOSVC)"
Write-Host " [29] Windows Update Logs"
Write-Host ""
Write-Host "--- SYSTEM RESTORE ---" -ForegroundColor Yellow
Write-Host " [31] System Restore Points (all except latest)"
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " [A]  Run ALL tasks"
Write-Host " [Q]  Quit"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Enter task numbers separated by commas (e.g. 1,2,5,11) or 'A' for all:" -ForegroundColor Green
$userInput = Read-Host

# ============================================================
#  PARSE INPUT
# ============================================================
$allTasks = @(1,2,3,4,5,6,7,8,9,10,11,12,15,16,17,18,19,20,21,24,25,26,27,28,29,31)
$selectedTasks = @()

if ($userInput.Trim().ToUpper() -eq "A") {
    $selectedTasks = $allTasks
} elseif ($userInput.Trim().ToUpper() -eq "Q") {
    Write-Host "Exiting..." -ForegroundColor Red
    exit
} else {
    $selectedTasks = $userInput.Split(',') | ForEach-Object { [int]$_.Trim() }
}

Write-Host ""
Write-Host "Running selected tasks: $($selectedTasks -join ', ')" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 2

# ============================================================
#  TASK 1 - Windows Temp Folder
# ============================================================
if ($selectedTasks -contains 1) {
    Write-Host "[1] Cleaning Windows Temp Folder..." -ForegroundColor Cyan
    Remove-ItemsSafe -Path "$env:SystemRoot\Temp" -Label "Windows Temp"
}

# ============================================================
#  TASK 2 - User Temp Folder
# ============================================================
if ($selectedTasks -contains 2) {
    Write-Host "[2] Cleaning User Temp Folder..." -ForegroundColor Cyan
    Remove-ItemsSafe -Path "$env:USERPROFILE\AppData\Local\Temp" -Label "User Temp"
}

# ============================================================
#  TASK 3 - Windows Update Cache
# ============================================================
if ($selectedTasks -contains 3) {
    Write-Host "[3] Cleaning Windows Update Cache..." -ForegroundColor Cyan
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-ItemsSafe -Path "C:\Windows\SoftwareDistribution\Download" -Label "WU Cache"
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch {
        Log "ERROR [WU Cache] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 4 - Prefetch Files
# ============================================================
if ($selectedTasks -contains 4) {
    Write-Host "[4] Cleaning Prefetch Files..." -ForegroundColor Cyan
    Remove-ItemsSafe -Path "C:\Windows\Prefetch" -Label "Prefetch"
}

# ============================================================
#  TASK 5 - Microsoft Edge Cache
# ============================================================
if ($selectedTasks -contains 5) {
    Write-Host "[5] Cleaning Microsoft Edge Cache..." -ForegroundColor Cyan
    $edgePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker"
    )
    foreach ($p in $edgePaths) {
        Remove-ItemsSafe -Path $p -Label "Edge Cache"
    }
}

# ============================================================
#  TASK 6 - Google Chrome Cache
# ============================================================
if ($selectedTasks -contains 6) {
    Write-Host "[6] Cleaning Google Chrome Cache..." -ForegroundColor Cyan
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker"
    )
    foreach ($p in $chromePaths) {
        Remove-ItemsSafe -Path $p -Label "Chrome Cache"
    }
}

# ============================================================
#  TASK 7 - Firefox Cache
# ============================================================
if ($selectedTasks -contains 7) {
    Write-Host "[7] Cleaning Firefox Cache..." -ForegroundColor Cyan
    $ffProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffProfilePath) {
        $ffProfiles = Get-ChildItem -Path $ffProfilePath -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $ffProfiles) {
            Remove-ItemsSafe -Path "$($profile.FullName)\Cache2" -Label "Firefox Cache"
            Remove-ItemsSafe -Path "$($profile.FullName)\DOMCache" -Label "Firefox DOMCache"
        }
    } else {
        Log "SKIP [Firefox] - No Firefox profiles found"
    }
}


# ============================================================
#  TASK 18 - Brave Browser Cache
# ============================================================
if ($selectedTasks -contains 18) {
    Write-Host "[18] Cleaning Brave Browser Cache..." -ForegroundColor Cyan
    $bravePaths = @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Service Worker"
    )
    foreach ($p in $bravePaths) {
        Remove-ItemsSafe -Path $p -Label "Brave Cache"
    }
}
# ============================================================
#  TASK 8 - Windows Event Logs
# ============================================================
if ($selectedTasks -contains 8) {
    Write-Host "[8] Clearing Windows Event Logs..." -ForegroundColor Cyan
    try {
        $logNames = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordCount -gt 0 } |
            Select-Object -ExpandProperty LogName
        $count = 0
        foreach ($logName in $logNames) {
            try {
                $logObj = [System.Diagnostics.Eventing.Reader.EventLog]::new($logName)
                $logObj.Clear()
                $logObj.Dispose()
                $count++
            } catch {
                # Some logs are protected and cannot be cleared - skip silently
            }
        }
        Log "DONE [Event Logs] - Cleared $count event logs"
    } catch {
        Log "ERROR [Event Logs] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 9 - Windows Diagnostic Traces
# ============================================================
if ($selectedTasks -contains 9) {
    Write-Host "[9] Cleaning Diagnostic Traces..." -ForegroundColor Cyan
    $diagPaths = @(
        "C:\Windows\Diagnostics\ApplicationCrashDump"
        "C:\Windows\Diagnostics\MachineAppCrashDump"
        "C:\ProgramData\Microsoft\Windows\WER\LocalReports"
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
    )
    foreach ($p in $diagPaths) {
        Remove-ItemsSafe -Path $p -Label "Diagnostics"
    }
    # Handle per-user WER paths
    $userWerPaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.FullName)\AppData\Local\Microsoft\Windows\WER\ReportQueue" }
    foreach ($p in $userWerPaths) {
        Remove-ItemsSafe -Path $p -Label "User Diagnostics"
    }
}

# ============================================================
#  TASK 10 - CBS Logs
# ============================================================
if ($selectedTasks -contains 10) {
    Write-Host "[10] Cleaning CBS Logs..." -ForegroundColor Cyan
    Remove-ItemsSafe -Path "C:\Windows\Logs\CBS" -Label "CBS Logs"
}

# ============================================================
#  TASK 11 - Empty Recycle Bin
# ============================================================
if ($selectedTasks -contains 11) {
    Write-Host "[11] Emptying Recycle Bin..." -ForegroundColor Cyan
    try {
        $drives = Get-PSDrive -Persist | Where-Object { $_.Root -like "*:\" } | Select-Object -ExpandProperty Name
        $totalItems = 0
        foreach ($drive in $drives) {
            $recyclePath = "${drive}:\`$Recycle.Bin"
            if (Test-Path $recyclePath) {
                $items = Get-ChildItem -Path $recyclePath -Recurse -Force -ErrorAction SilentlyContinue
                $totalItems += ($items | Measure-Object).Count
                Get-ChildItem -Path $recyclePath -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Log "DONE [Recycle Bin] - Emptied. Found $totalItems items across all drives."
    } catch {
        Log "ERROR [Recycle Bin] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 12 - Old Shadow Copies
# ============================================================
if ($selectedTasks -contains 12) {
    Write-Host "[12] Removing old Shadow Copies..." -ForegroundColor Cyan
    Write-Host "     WARNING: This will delete ALL shadow copies except the latest." -ForegroundColor Red
    $confirm = Read-Host "     Type 'yes' to confirm"
    if ($confirm.Trim().ToLower() -eq "yes") {
        try {
            $shadows = Get-WmiObject -Class Win32_ShadowCopy -ErrorAction SilentlyContinue
            if ($null -eq $shadows) {
                Log "SKIP [Shadow Copies] - No shadow copies found"
            } elseif ($shadows.Count -le 1) {
                Log "SKIP [Shadow Copies] - Only 1 or fewer shadow copies exist. Nothing to delete."
            } else {
                $sorted = $shadows | Sort-Object { $_.CreateTime } -Descending
                $toDelete = $sorted[1..($sorted.Count - 1)]
                $deleteCount = 0
                foreach ($shadow in $toDelete) {
                    $shadow.Delete()
                    $deleteCount++
                }
                Log "DONE [Shadow Copies] - Deleted $deleteCount old shadow copies. Kept latest."
            }
        } catch {
            Log "ERROR [Shadow Copies] - $($_.Exception.Message)"
        }
    } else {
        Log "SKIP [Shadow Copies] - User cancelled"
    }
}

# ============================================================
#  TASK 15 - Rebuild Search Index
# ============================================================
if ($selectedTasks -contains 15) {
    Write-Host "[15] Rebuilding Windows Search Index..." -ForegroundColor Cyan
    try {
        $indexingService = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
        if ($indexingService) {
            Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            $indexPath = "C:\ProgramData\Microsoft\Windows\CoreSearchIndexPortableDatabase"
            if (Test-Path $indexPath) {
                Remove-Item -Path $indexPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
            Log "DONE [Search Index] - Index reset. Windows will rebuild automatically."
        } else {
            Log "ERROR [Search Index] - WSearch service not found"
        }
    } catch {
        Log "ERROR [Search Index] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 16 - Thumbnail Cache
# ============================================================
if ($selectedTasks -contains 16) {
    Write-Host "[16] Cleaning Thumbnail Cache..." -ForegroundColor Cyan
    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (Test-Path $thumbPath) {
        $thumbFiles = Get-ChildItem -Path $thumbPath -Filter "thumbcache_*" -Force -ErrorAction SilentlyContinue
        $size = 0
        foreach ($f in $thumbFiles) {
            $size += $f.Length
            Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
        }
        $sizeMB = [math]::Round($size / 1MB, 2)
        $script:TotalFreed += $sizeMB
        Log "DONE [Thumbnail Cache] - Freed approx ${sizeMB} MB"
    } else {
        Log "SKIP [Thumbnail Cache] - Explorer cache folder not found"
    }
}

# ============================================================
#  TASK 17 - Icon Cache
# ============================================================
if ($selectedTasks -contains 17) {
    Write-Host "[17] Rebuilding Icon Cache..." -ForegroundColor Cyan
    try {
        $iconCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\IconCache.db"
        if (Test-Path $iconCachePath) {
            # Stop Explorer to release the lock on IconCache.db
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3

            # Delete the icon cache
            Remove-Item -Path $iconCachePath -Force -ErrorAction SilentlyContinue

            # Restart Explorer
            Start-Process -FilePath "C:\Windows\explorer.exe"
            Start-Sleep -Seconds 2
            Log "DONE [Icon Cache] - IconCache.db removed. Explorer restarted to rebuild."
        } else {
            Log "SKIP [Icon Cache] - IconCache.db not found"
        }
    } catch {
        Log "ERROR [Icon Cache] - $($_.Exception.Message)"
    }
}


# ============================================================
#  TASK 19 - Clear Performance Counters
# ============================================================
if ($selectedTasks -contains 19) {
    Write-Host "[19] Clearing Windows Performance Counters..." -ForegroundColor Cyan
    try {
        lodctr /r 2>$null
        Log "DONE [Perf Counters] - Performance counters reset via lodctr /r"
    } catch {
        Log "ERROR [Perf Counters] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 20 - Run Disk Cleanup (automated)
# ============================================================
if ($selectedTasks -contains 20) {
    Write-Host "[20] Running Windows Disk Cleanup (automated)..." -ForegroundColor Cyan
    Write-Host "     This may take a minute..." -ForegroundColor DarkGray
    try {
        # Create a sageent config that selects all cleanup options
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\VolumeCaches"
        $keys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            Set-ItemProperty -Path $key.PSPath -Name "CleanupDescription" -Value "" -ErrorAction SilentlyContinue
        }
        # Run cleanmgr silently on C drive with /sageset:100 then /sagerun:100
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sageset:100" -Wait -NoNewWindow
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -NoNewWindow
        Log "DONE [Disk Cleanup] - cleanmgr completed on system drive"
    } catch {
        Log "ERROR [Disk Cleanup] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 21 - Microsoft Store Cache
# ============================================================
if ($selectedTasks -contains 21) {
    Write-Host "[21] Cleaning Microsoft Store Cache..." -ForegroundColor Cyan
    $storePaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.WindowsStore_Cache"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_Microsoft.WindowsStore\LocalCache"
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\PendingReboot"
    )
    foreach ($p in $storePaths) {
        Remove-ItemsSafe -Path $p -Label "Store Cache"
    }
    # Also run wsreset.exe silently to clear the store cache properly
    try {
        Start-Process -FilePath "wsreset.exe" -ArgumentList "-i" -Wait -NoNewWindow
        Log "DONE [Store Cache] - wsreset completed"
    } catch {
        Log "NOTE [Store Cache] - wsreset could not run, manual paths cleaned"
    }
}

# ============================================================
#  TASK 24 - Windows Notification Cache
# ============================================================
if ($selectedTasks -contains 24) {
    Write-Host "[24] Cleaning Windows Notification Cache..." -ForegroundColor Cyan
    $notifPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Notifications"
        "$env:LOCALAPPDATA\Microsoft\Windows\Notifications\Database"
    )
    foreach ($p in $notifPaths) {
        Remove-ItemsSafe -Path $p -Label "Notification Cache"
    }
}

# ============================================================
#  TASK 25 - Recent Files + Jump List Cache
# ============================================================
if ($selectedTasks -contains 25) {
    Write-Host "[25] Cleaning Recent Files + Jump List Cache..." -ForegroundColor Cyan
    $recentPaths = @(
        "$env:APPDATA\Microsoft\Windows\Recent"
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Recent"
        "$env:APPDATA\Microsoft\Windows\SendTo"
    )
    foreach ($p in $recentPaths) {
        Remove-ItemsSafe -Path $p -Label "Recent Files"
    }
    # Jump list / LMU custom destination files
    $jumpListPath = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
    Remove-ItemsSafe -Path $jumpListPath -Label "Jump List Custom"
    $jumpListPath2 = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    Remove-ItemsSafe -Path $jumpListPath2 -Label "Jump List Auto"
}


# ============================================================
#  TASK 26 - Flush DNS Cache
# ============================================================
if ($selectedTasks -contains 26) {
    Write-Host "[26] Flushing DNS Cache..." -ForegroundColor Cyan
    try {
        ipconfig /flushdns 2>$null
        Log "DONE [DNS Flush] - DNS cache flushed"
    } catch {
        Log "ERROR [DNS Flush] - $($_.Exception.Message)"
    }
}

# ============================================================
#  TASK 27 - Reset TCP/IP Stack
# ============================================================
if ($selectedTasks -contains 27) {
    Write-Host "[27] Resetting TCP/IP Stack..." -ForegroundColor Cyan
    Write-Host "     NOTE: Your network connection will briefly drop." -ForegroundColor Red
    $confirm = Read-Host "     Type 'yes' to confirm"
    if ($confirm.Trim().ToLower() -eq "yes") {
        try {
            netsh int ip reset 2>$null
            netsh int tcp reset 2>$null
            Log "DONE [TCP/IP Reset] - TCP/IP stack reset. Reconnection may be needed."
        } catch {
            Log "ERROR [TCP/IP Reset] - $($_.Exception.Message)"
        }
    } else {
        Log "SKIP [TCP/IP Reset] - User cancelled"
    }
}

# ============================================================
#  TASK 28 - Delivery Optimization Cache (DOSVC)
# ============================================================
if ($selectedTasks -contains 28) {
    Write-Host "[28] Cleaning Delivery Optimization Cache..." -ForegroundColor Cyan
    $dosPaths = @(
        "C:\Windows\SoftwareDistribution\DeliveryOptimization\Cache"
        "$env:LOCALAPPDATA\Microsoft\Windows\Delivery Optimization\Cache"
    )
    foreach ($p in $dosPaths) {
        Remove-ItemsSafe -Path $p -Label "DOSVC Cache"
    }
}

# ============================================================
#  TASK 29 - Windows Update Logs
# ============================================================
if ($selectedTasks -contains 29) {
    Write-Host "[29] Cleaning Windows Update Logs..." -ForegroundColor Cyan
    $wuLogPaths = @(
        "C:\Windows\Logs\WindowsUpdate"
        "C:\Windows\Logs\WinSetupLog"
        "C:\Windows\Logs\DISM"
        "C:\Windows\WindowsUpdate.log"
    )
    foreach ($p in $wuLogPaths) {
        Remove-ItemsSafe -Path $p -Label "WU Logs"
    }
}

# ============================================================
#  TASK 31 - System Restore Points (all except latest)
# ============================================================
if ($selectedTasks -contains 31) {
    Write-Host "[31] Removing old System Restore Points..." -ForegroundColor Cyan
    Write-Host "     WARNING: Keeps only the most recent restore point." -ForegroundColor Red
    $confirm = Read-Host "     Type 'yes' to confirm"
    if ($confirm.Trim().ToLower() -eq "yes") {
        try {
            $restorePoints = Get-WmiObject -Class Win32_ShadowCopy -ErrorAction SilentlyContinue |
                Where-Object { $_.OriginatingMachine -eq $env:COMPUTERNAME }
            if ($null -eq $restorePoints -or $restorePoints.Count -le 1) {
                Log "SKIP [Restore Points] - 1 or fewer restore points found. Nothing to delete."
            } else {
                $sorted = $restorePoints | Sort-Object { $_.CreateTime } -Descending
                $toDelete = $sorted[1..($sorted.Count - 1)]
                $deleteCount = 0
                foreach ($rp in $toDelete) {
                    $rp.Delete()
                    $deleteCount++
                }
                Log "DONE [Restore Points] - Deleted $deleteCount restore points. Kept latest."
            }
        } catch {
            Log "ERROR [Restore Points] - $($_.Exception.Message)"
        }
    } else {
        Log "SKIP [Restore Points] - User cancelled"
    }
}

# ============================================================
#  SUMMARY
# ============================================================
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "            CLEANING COMPLETE                " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Estimated space freed : ~${TotalFreed} MB" -ForegroundColor Green
Write-Host "  Log saved to          : $LogFile" -ForegroundColor DarkGray
Write-Host ""
Log "===== CLEANING SESSION ENDED | Total Freed: approx ${TotalFreed} MB ====="
Write-Host "=============================================" -ForegroundColor Cyan

Read-Host -Prompt "Press Enter to exit"