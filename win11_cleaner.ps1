#Requires -Version 5.1

# ============================================================
#  ADMIN CHECK
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    exit
}

# ============================================================
#  LOGGING
# ============================================================
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile    = Join-Path $ScriptDir ("SWDS_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
$TotalFreed = 0

function Log {
    param([string]$Msg)
    $ts   = Get-Date -Format "HH:mm:ss"
    $line = "$ts  $Msg"
    $line | Out-File -Append -FilePath $LogFile
    Write-Host $line -ForegroundColor DarkGray
}

function Get-FolderSize {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $sum = (Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
            return [math]::Round($sum / 1MB, 2)
        }
    } catch {}
    return 0
}

function Remove-ItemsSafe {
    param([string]$Path, [string]$Label, [int]$Retries = 2)
    if (-not (Test-Path $Path)) { Log "skip   $Label  (not found)"; return }
    
    $deletedBytes = 0
    $failedFiles = @()
    
    try {
        $files = Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $attempt = 0
            $deleted = $false
            while ($attempt -le $Retries) {
                try {
                    $fileSize = $f.Length
                    Remove-Item $f.FullName -Force -ErrorAction Stop
                    $deletedBytes += $fileSize
                    $deleted = $true
                    break
                } catch {
                    $attempt++
                    if ($attempt -le $Retries) { Start-Sleep -Milliseconds 300 }
                }
            }
            if (-not $deleted) {
                $failedFiles += $f.FullName
            }
        }

        Get-ChildItem $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                if (-not (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue)) {
                    # Directory size is approximate (sum of remaining files, but should be 0)
                    Remove-Item $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
            }

        # Calculate remaining size after cleanup
        $after = Get-FolderSize $Path
        $freedMB = [math]::Round($deletedBytes / 1MB, 2)
        $afterMB = [math]::Round($after, 2)
        
        # Only add positive freed space to total
        if ($freedMB -gt 0) {
            $script:TotalFreed += $freedMB
        }
        
        if ($failedFiles.Count -gt 0) {
            $lockedMB = [math]::Round(($after - ($deletedBytes / 1MB)), 2)
            if ($lockedMB -lt 0) { $lockedMB = $afterMB } # Fallback calculation
            Log "clear  $Label  ($freedMB MB freed, $lockedMB MB locked - $($failedFiles.Count) files could not be deleted)"
        }
        elseif ($afterMB -gt 0) {
            Log "clear  $Label  ($freedMB MB freed, $afterMB MB remains - possibly new files created during cleanup)"
        }
        else {
            Log "clear  $Label  ($freedMB MB)"
        }
        
    } catch {
        Log "error  $Label  $($_.Exception.Message)"
    }
}

function Remove-SubFolderContents {
    param([string]$ParentPath, [string]$Label)
    if (-not (Test-Path $ParentPath)) { Log "skip   $Label  (not found)"; return }
    $subs = Get-ChildItem $ParentPath -Directory -Force -ErrorAction SilentlyContinue
    foreach ($sub in $subs) {
        $mb = Get-FolderSize $sub.FullName
        Get-ChildItem $sub.FullName -File -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        $script:TotalFreed += $mb
        Log "clear  $Label\$($sub.Name)  ($mb MB)"
    }
}

function Stop-AppSafe {
    param([string]$ProcessName)
    $procs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Log "kill   $ProcessName"
    }
}

# ============================================================
#  FLUSH STDIN - prevents buffered Enter presses from
#  auto-confirming prompts (especially after long steps)
# ============================================================
function Clear-InputBuffer {
    $host.UI.RawUI.FlushInputBuffer()
}

function Confirm-Risky {
    param([string]$Warning)
    Clear-InputBuffer
    Write-Host ""
    Write-Host "  ! $Warning" -ForegroundColor Yellow
    $r = Read-Host "    [Y] to confirm, anything else to skip"
    return ($r.Trim().ToUpper() -eq "Y")
}

# ============================================================
#  BANNER
# ============================================================
Clear-Host
Write-Host ""
Write-Host "   _______          _______   _____ " -ForegroundColor Cyan
Write-Host "  / ____\ \        / /  __ \ / ____|" -ForegroundColor Cyan
Write-Host " | (___  \ \  /\  / /| |  | | (___  " -ForegroundColor Cyan
Write-Host "  \___ \  \ \/  \/ / | |  | |\___ \ " -ForegroundColor Cyan
Write-Host "  ____) |  \  /\  /  | |__| |____) |" -ForegroundColor Cyan
Write-Host " |_____/    \/  \/   |_____/|_____/ " -ForegroundColor Cyan
Write-Host ""
Write-Host "  System-Wide Deep Sweep" -ForegroundColor White
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host "  log -> $LogFile" -ForegroundColor DarkGray
Write-Host ""
Log "session start"
Write-Host ""

# ============================================================
#  MENU
# ============================================================
Write-Host "  TEMP + CACHE" -ForegroundColor White
Write-Host "   1  Windows Temp"
Write-Host "   2  User Temp"
Write-Host "   3  Windows Update Cache"
Write-Host "   4  Prefetch"
Write-Host ""
Write-Host "  BROWSERS" -ForegroundColor White
Write-Host "   5  Edge"
Write-Host "   6  Chrome"
Write-Host "   7  Firefox"
Write-Host "  18  Brave"
Write-Host ""
Write-Host "  APPS" -ForegroundColor White
Write-Host "  32  Spotify Cache"
Write-Host "  33  Telegram Cache"
Write-Host ""
Write-Host "  LOGS + DIAGNOSTICS" -ForegroundColor White
Write-Host "   8  Windows Event Logs"
Write-Host "   9  Diagnostic Traces"
Write-Host "  10  CBS Logs"
Write-Host ""
Write-Host "  RECYCLE + RESTORE" -ForegroundColor White
Write-Host "  11  Recycle Bin"
Write-Host "  12  Old Shadow Copies"
Write-Host "  31  Old Restore Points"
Write-Host ""
Write-Host "  PERFORMANCE + STARTUP" -ForegroundColor White
Write-Host "  19  Performance Counters"
Write-Host ""
Write-Host "  DISK + STORE" -ForegroundColor White
Write-Host "  20  Disk Cleanup (GUI)         [prompt]"
Write-Host "  21  Microsoft Store Cache"
Write-Host ""
Write-Host "  CACHE + ICONS" -ForegroundColor White
Write-Host "  15  Rebuild Search Index"
Write-Host "  16  Thumbnail Cache"
Write-Host "  17  Icon Cache"
Write-Host "  24  Notification Cache"
Write-Host "  25  Recent Files + Jump Lists"
Write-Host ""
Write-Host "  NETWORK" -ForegroundColor White
Write-Host "  26  Flush DNS"
Write-Host "  27  Reset TCP/IP Stack         [prompt]"
Write-Host ""
Write-Host "  TELEMETRY" -ForegroundColor White
Write-Host "  28  Delivery Optimization Cache"
Write-Host "  29  Windows Update Logs"
Write-Host ""
Write-Host "  GAMING" -ForegroundColor White
Write-Host "  34  Steam Cache"
Write-Host "  35  GPU Shader Cache            [prompt]"
Write-Host "  36  DirectX Shader Cache        [prompt]"
Write-Host "  37  Discord Cache"
Write-Host "  38  Xbox Game Bar / GameDVR / DXGI Logs"
Write-Host "  39  Crash Dumps"
Write-Host ""
Write-Host "  DEV TOOLS" -ForegroundColor White
Write-Host "  40  Visual Studio / .NET Temp"
Write-Host "  41  npm Cache"
Write-Host "  42  pip Cache"
Write-Host ""
Write-Host "  APPS (EXTRA)" -ForegroundColor White
Write-Host "  43  Zoom Cache"
Write-Host "  44  Adobe Cache"
Write-Host "  45  TeamViewer / AnyDesk Logs"
Write-Host "  46  OBS Temp"
Write-Host ""
Write-Host "  SYSTEM (EXTRA)" -ForegroundColor White
Write-Host "  47  Font Cache  (Explorer restarts)"
Write-Host "  48  WinSAT Results"
Write-Host "  49  Windows.old               [prompt]"
Write-Host "  50  DISM Component Cleanup    [prompt]"
Write-Host ""
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host "   A  Run all"  -ForegroundColor Cyan
Write-Host "   S  Simple  (skips: GPU shader, DirectX, TCP reset, Disk Cleanup, Font Cache, Windows.old, DISM Cleanup)" -ForegroundColor Cyan
Write-Host "   Q  Quit" -ForegroundColor Cyan
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tasks (e.g. 1,2,5  or  A  or  S): " -ForegroundColor Green -NoNewline
$userInput = Read-Host

$allTasks    = @(1,2,3,4,5,6,7,8,9,10,11,12,15,16,17,18,19,20,21,24,25,26,27,28,29,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50)
$simpleTasks = $allTasks | Where-Object { $_ -notin @(20,27,35,36,47,49,50) }

$selectedTasks = @()

switch ($userInput.Trim().ToUpper()) {
    "A" { $selectedTasks = $allTasks }
    "S" { $selectedTasks = $simpleTasks }
    "Q" { exit }
    default {
        $selectedTasks = $userInput.Split(",") | ForEach-Object { [int]$_.Trim() }
    }
}

Write-Host ""
$runningList = $selectedTasks -join ", "
Write-Host "  Running: $runningList" -ForegroundColor DarkGray
Write-Host ""
Start-Sleep -Seconds 1

# ============================================================
#  TASK 1 - Windows Temp
# ============================================================
if ($selectedTasks -contains 1) {
    Write-Host "  [1] Windows Temp" -ForegroundColor Cyan
    Remove-ItemsSafe "$env:SystemRoot\Temp" "Windows Temp"
}

# ============================================================
#  TASK 2 - User Temp
# ============================================================
if ($selectedTasks -contains 2) {
    Write-Host "  [2] User Temp" -ForegroundColor Cyan
    Remove-ItemsSafe "$env:USERPROFILE\AppData\Local\Temp" "User Temp"
}

# ============================================================
#  TASK 3 - Windows Update Cache
#  Fix: stop service with timeout, kill if needed, skip if stuck
# ============================================================
if ($selectedTasks -contains 3) {
    Write-Host "  [3] Windows Update Cache" -ForegroundColor Cyan
    try {
        $svc = Get-Service wuauserv -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            # Wait max 10 seconds for the service to stop
            $waited = 0
            while ((Get-Service wuauserv -ErrorAction SilentlyContinue).Status -ne 'Stopped' -and $waited -lt 10) {
                Start-Sleep -Seconds 1
                $waited++
            }
            # If still not stopped, force-kill svchost hosting it
            if ((Get-Service wuauserv -ErrorAction SilentlyContinue).Status -ne 'Stopped') {
                $pid = (Get-WmiObject Win32_Service -Filter "Name='wuauserv'" -ErrorAction SilentlyContinue).ProcessId
                if ($pid -and $pid -ne 0) {
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                }
            }
        }
        Remove-ItemsSafe "C:\Windows\SoftwareDistribution\Download" "WU Cache"
    } catch {
        Log "error  WU Cache  $($_.Exception.Message)"
    } finally {
        Start-Service wuauserv -ErrorAction SilentlyContinue
    }
}

# ============================================================
#  TASK 4 - Prefetch
# ============================================================
if ($selectedTasks -contains 4) {
    Write-Host "  [4] Prefetch" -ForegroundColor Cyan
    Remove-ItemsSafe "C:\Windows\Prefetch" "Prefetch"
}

# ============================================================
#  TASK 5 - Edge
# ============================================================
if ($selectedTasks -contains 5) {
    Write-Host "  [5] Edge Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Edge" }
}

# ============================================================
#  TASK 6 - Chrome
# ============================================================
if ($selectedTasks -contains 6) {
    Write-Host "  [6] Chrome Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Chrome" }
}

# ============================================================
#  TASK 7 - Firefox
# ============================================================
if ($selectedTasks -contains 7) {
    Write-Host "  [7] Firefox Cache" -ForegroundColor Cyan
    $ffRoot = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffRoot) {
        Get-ChildItem $ffRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-ItemsSafe "$($_.FullName)\Cache2"   "Firefox Cache2"
            Remove-ItemsSafe "$($_.FullName)\DOMCache" "Firefox DOMCache"
        }
    } else { Log "skip   Firefox (no profiles)" }
}

# ============================================================
#  TASK 18 - Brave
# ============================================================
if ($selectedTasks -contains 18) {
    Write-Host "  [18] Brave Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Service Worker"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Brave" }
}

# ============================================================
#  TASK 32 - Spotify
# ============================================================
if ($selectedTasks -contains 32) {
    Write-Host "  [32] Spotify Cache" -ForegroundColor Cyan
    Stop-AppSafe "Spotify"
    Remove-ItemsSafe "$env:LOCALAPPDATA\Spotify\Data"    "Spotify Data"
    Remove-ItemsSafe "$env:LOCALAPPDATA\Spotify\Storage" "Spotify Storage"
}

# ============================================================
#  TASK 33 - Telegram
# ============================================================
if ($selectedTasks -contains 33) {
    Write-Host "  [33] Telegram Cache" -ForegroundColor Cyan
    Stop-AppSafe "Telegram"
    $tdataBase = "$env:APPDATA\Telegram Desktop\tdata\user_data"
    Remove-SubFolderContents "$tdataBase\cache"       "Telegram cache"
    Remove-SubFolderContents "$tdataBase\media_cache" "Telegram media_cache"
    Remove-ItemsSafe "$env:APPDATA\Telegram Desktop\tdata\dumps" "Telegram dumps"
}

# ============================================================
#  TASK 8 - Event Logs
# ============================================================
if ($selectedTasks -contains 8) {
    Write-Host "  [8] Windows Event Logs" -ForegroundColor Cyan
    try {
        $count = 0
        Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
            Where-Object { $_.RecordCount -gt 0 } |
            ForEach-Object {
                try {
                    $l = [System.Diagnostics.Eventing.Reader.EventLog]::new($_.LogName)
                    $l.Clear(); $l.Dispose(); $count++
                } catch {}
            }
        Log "clear  Event Logs  ($count logs)"
    } catch { Log "error  Event Logs  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 9 - Diagnostic Traces
# ============================================================
if ($selectedTasks -contains 9) {
    Write-Host "  [9] Diagnostic Traces" -ForegroundColor Cyan
    $paths = @(
        "C:\Windows\Diagnostics\ApplicationCrashDump",
        "C:\Windows\Diagnostics\MachineAppCrashDump",
        "C:\ProgramData\Microsoft\Windows\WER\LocalReports",
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Diagnostics" }
    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemsSafe "$($_.FullName)\AppData\Local\Microsoft\Windows\WER\ReportQueue" "User WER"
    }
}

# ============================================================
#  TASK 10 - CBS Logs
# ============================================================
if ($selectedTasks -contains 10) {
    Write-Host "  [10] CBS Logs" -ForegroundColor Cyan
    Remove-ItemsSafe "C:\Windows\Logs\CBS" "CBS Logs"
}

# ============================================================
#  TASK 11 - Recycle Bin
# ============================================================
if ($selectedTasks -contains 11) {
    Write-Host "  [11] Recycle Bin" -ForegroundColor Cyan
    try {
        $n = 0
        $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
                  Select-Object -ExpandProperty DeviceID
        foreach ($drive in $drives) {
            $rb = "$drive\`$Recycle.Bin"
            if (Test-Path $rb) {
                $items = Get-ChildItem $rb -Recurse -Force -ErrorAction SilentlyContinue
                $n += ($items | Measure-Object).Count
                $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Log "clear  Recycle Bin  ($n items)"
    } catch { Log "error  Recycle Bin  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 12 - Old Shadow Copies
# ============================================================
if ($selectedTasks -contains 12) {
    Write-Host "  [12] Old Shadow Copies" -ForegroundColor Cyan
    if (Confirm-Risky "Deletes all shadow copies except the latest.") {
        try {
            $shadows = Get-WmiObject Win32_ShadowCopy -ErrorAction SilentlyContinue
            if (-not $shadows -or $shadows.Count -le 1) {
                Log "skip   Shadow Copies (none to delete)"
            } else {
                $sorted = $shadows | Sort-Object { $_.CreateTime } -Descending
                $sorted[1..($sorted.Count-1)] | ForEach-Object { $_.Delete() }
                Log "clear  Shadow Copies  ($($sorted.Count - 1) deleted)"
            }
        } catch { Log "error  Shadow Copies  $($_.Exception.Message)" }
    } else { Log "skip   Shadow Copies (user declined)" }
}

# ============================================================
#  TASK 15 - Rebuild Search Index
# ============================================================
if ($selectedTasks -contains 15) {
    Write-Host "  [15] Rebuild Search Index" -ForegroundColor Cyan
    try {
        Stop-Service WSearch -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Remove-Item "C:\ProgramData\Microsoft\Windows\CoreSearchIndexPortableDatabase" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service WSearch -ErrorAction SilentlyContinue
        Log "clear  Search Index (will rebuild)"
    } catch { Log "error  Search Index  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 16 - Thumbnail Cache
# ============================================================
if ($selectedTasks -contains 16) {
    Write-Host "  [16] Thumbnail Cache" -ForegroundColor Cyan
    $tp = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (Test-Path $tp) {
        $sz = 0
        Get-ChildItem $tp -Filter "thumbcache_*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $sz += $_.Length
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        }
        $mb = [math]::Round($sz / 1MB, 2)
        $script:TotalFreed += $mb
        Log "clear  Thumbnail Cache  ($mb MB)"
    } else { Log "skip   Thumbnail Cache" }
}

# ============================================================
#  TASK 17 - Icon Cache
# ============================================================
if ($selectedTasks -contains 17) {
    Write-Host "  [17] Icon Cache" -ForegroundColor Cyan
    try {
        $ic = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\IconCache.db"
        if (Test-Path $ic) {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep 3
            Remove-Item $ic -Force -ErrorAction SilentlyContinue
            Start-Process "C:\Windows\explorer.exe"
            Start-Sleep 2
            Log "clear  Icon Cache (Explorer restarted)"
        } else { Log "skip   Icon Cache (not found)" }
    } catch { Log "error  Icon Cache  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 19 - Performance Counters
# ============================================================
if ($selectedTasks -contains 19) {
    Write-Host "  [19] Performance Counters" -ForegroundColor Cyan
    try {
        cmd /c "lodctr /r" 2>&1 | Out-Null
        Log "clear  Performance Counters"
    } catch { Log "error  Performance Counters  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 20 - Disk Cleanup (prompt)
# ============================================================
if ($selectedTasks -contains 20) {
    Write-Host "  [20] Disk Cleanup (GUI)" -ForegroundColor Cyan
    if (Confirm-Risky "This will open the Windows Disk Cleanup wizard.") {
        try {
            Start-Process "cleanmgr.exe" -ArgumentList "/sageset:100" -Wait -NoNewWindow
            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -NoNewWindow
            Log "clear  Disk Cleanup"
        } catch { Log "error  Disk Cleanup  $($_.Exception.Message)" }
    } else { Log "skip   Disk Cleanup (user declined)" }
}

# ============================================================
#  TASK 21 - Microsoft Store Cache
# ============================================================
if ($selectedTasks -contains 21) {
    Write-Host "  [21] Microsoft Store Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\PendingReboot"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Store Cache" }
    try {
        Start-Process "wsreset.exe" -ArgumentList "-i" -Wait -NoNewWindow
        Log "clear  Store Cache (wsreset done)"
    } catch { Log "note   Store Cache (wsreset skipped)" }
}

# ============================================================
#  TASK 24 - Notification Cache
# ============================================================
if ($selectedTasks -contains 24) {
    Write-Host "  [24] Notification Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Notifications",
        "$env:LOCALAPPDATA\Microsoft\Windows\Notifications\Database"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Notifications" }
}

# ============================================================
#  TASK 25 - Recent Files + Jump Lists
# ============================================================
if ($selectedTasks -contains 25) {
    Write-Host "  [25] Recent Files + Jump Lists" -ForegroundColor Cyan
    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Recent",
        "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations",
        "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Recent" }
}

# ============================================================
#  TASK 26 - Flush DNS
# ============================================================
if ($selectedTasks -contains 26) {
    Write-Host "  [26] Flush DNS" -ForegroundColor Cyan
    try {
        ipconfig /flushdns 2>$null
        Log "clear  DNS Cache"
    } catch { Log "error  DNS  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 27 - Reset TCP/IP Stack (prompt)
# ============================================================
if ($selectedTasks -contains 27) {
    Write-Host "  [27] Reset TCP/IP Stack" -ForegroundColor Cyan
    if (Confirm-Risky "Network connection will briefly drop.") {
        try {
            netsh int ip reset 2>$null
            netsh int tcp reset 2>$null
            Log "clear  TCP/IP Stack (reboot recommended)"
        } catch { Log "error  TCP/IP  $($_.Exception.Message)" }
    } else { Log "skip   TCP/IP (user declined)" }
}

# ============================================================
#  TASK 28 - Delivery Optimization Cache
# ============================================================
if ($selectedTasks -contains 28) {
    Write-Host "  [28] Delivery Optimization Cache" -ForegroundColor Cyan
    $paths = @(
        "C:\Windows\SoftwareDistribution\DeliveryOptimization\Cache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Delivery Optimization\Cache"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "DOSVC" }
}

# ============================================================
#  TASK 29 - Windows Update Logs
# ============================================================
if ($selectedTasks -contains 29) {
    Write-Host "  [29] Windows Update Logs" -ForegroundColor Cyan
    $folders = @(
        "C:\Windows\Logs\WindowsUpdate",
        "C:\Windows\Logs\WinSetupLog",
        "C:\Windows\Logs\DISM"
    )
    foreach ($p in $folders) { Remove-ItemsSafe $p "WU Logs" }
    $wuLog = "C:\Windows\WindowsUpdate.log"
    if (Test-Path $wuLog) {
        $mb = [math]::Round((Get-Item $wuLog).Length / 1MB, 2)
        Remove-Item $wuLog -Force -ErrorAction SilentlyContinue
        $script:TotalFreed += $mb
        Log "clear  WU Logs (WindowsUpdate.log)  ($mb MB)"
    }
}

# ============================================================
#  TASK 31 - Old Restore Points
# ============================================================
if ($selectedTasks -contains 31) {
    Write-Host "  [31] Old Restore Points" -ForegroundColor Cyan
    if (Confirm-Risky "Keeps only the most recent restore point. Older ones will be permanently deleted.") {
        try {
            $rps = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
            if (-not $rps -or @($rps).Count -le 1) {
                Log "skip   Restore Points (only 1 or none - nothing to delete)"
            } else {
                $sorted = @($rps) | Sort-Object SequenceNumber -Descending
                # Delete all except the most recent (highest SequenceNumber)
                $toDelete = $sorted[1..($sorted.Count - 1)]
                foreach ($rp in $toDelete) {
                    try {
                        $null = (Get-WmiObject -Class SystemRestore -Namespace root\default -ErrorAction SilentlyContinue) |
                            Where-Object { $_.SequenceNumber -eq $rp.SequenceNumber } |
                            ForEach-Object { $_.Delete() }
                    } catch {}
                }
                # Fallback: vssadmin delete shadows if WMI delete didn't work
                # (restore points are backed by VSS snapshots)
                & vssadmin delete shadows /For=C: /Oldest /Quiet 2>$null
                Log "clear  Restore Points  ($($toDelete.Count) deleted, kept latest: '$($sorted[0].Description)')"
            }
        } catch { 
            Log "error  Restore Points  $($_.Exception.Message)" 
        }
    } else { 
        Log "skip   Restore Points (user declined)" 
    }
}

# ============================================================
#  TASK 34 - Steam Cache
# ============================================================
if ($selectedTasks -contains 34) {
    Write-Host "  [34] Steam Cache" -ForegroundColor Cyan
    Stop-AppSafe "steam"
    $paths = @(
        "C:\Program Files (x86)\Steam\htmlcache",
        "C:\Program Files (x86)\Steam\shadercache",
        "$env:LOCALAPPDATA\Steam\htmlcache",
        "$env:LOCALAPPDATA\Steam\shadercache"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Steam Cache" }
    $steamLibs = @("C:\Program Files (x86)\Steam", "$env:LOCALAPPDATA\Steam")
    foreach ($lib in $steamLibs) {
        Remove-ItemsSafe "$lib\steamapps\shadercache" "Steam Shader Cache"
        Remove-ItemsSafe "$lib\package\chunks"        "Steam Download Chunks"
    }
    $libFile = "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf"
    if (Test-Path $libFile) {
        $content = Get-Content $libFile -ErrorAction SilentlyContinue
        $content | Select-String '"path"\s+"([^"]+)"' | ForEach-Object {
            $libPath = $_.Matches[0].Groups[1].Value -replace "\\\\", "\"
            Remove-ItemsSafe "$libPath\steamapps\shadercache" "Steam Shader Cache (lib)"
        }
    }
}

# ============================================================
#  TASK 35 - GPU Shader Cache (prompt)
# ============================================================
if ($selectedTasks -contains 35) {
    Write-Host "  [35] GPU Shader Cache" -ForegroundColor Cyan
    if (Confirm-Risky "Clears NVIDIA/AMD shader caches. Games will rebuild them on next launch (may cause stutters).") {
        $nvPaths = @(
            "$env:LOCALAPPDATA\NVIDIA\DXCache",
            "$env:LOCALAPPDATA\NVIDIA\GLCache",
            "$env:APPDATA\NVIDIA\ComputeCache"
        )
        foreach ($p in $nvPaths) { Remove-ItemsSafe $p "NVIDIA Cache" }
        $amdPaths = @(
            "$env:LOCALAPPDATA\AMD\DxCache",
            "$env:LOCALAPPDATA\AMD\VkCache",
            "$env:TEMP\AMD"
        )
        foreach ($p in $amdPaths) { Remove-ItemsSafe $p "AMD Cache" }
    } else { Log "skip   GPU Shader Cache (user declined)" }
}

# ============================================================
#  TASK 36 - DirectX Shader Cache (prompt)
# ============================================================
if ($selectedTasks -contains 36) {
    Write-Host "  [36] DirectX Shader Cache" -ForegroundColor Cyan
    if (Confirm-Risky "Clears DirectX D3DSCache. Games/apps will rebuild on next launch.") {
        Remove-ItemsSafe "$env:LOCALAPPDATA\D3DSCache" "D3DSCache"
    } else { Log "skip   D3DSCache (user declined)" }
}

# ============================================================
#  TASK 37 - Discord Cache
# ============================================================
if ($selectedTasks -contains 37) {
    Write-Host "  [37] Discord Cache" -ForegroundColor Cyan
    Stop-AppSafe "Discord"
    $paths = @(
        "$env:APPDATA\discord\Cache\Cache_Data",
        "$env:APPDATA\discord\Code Cache",
        "$env:APPDATA\discord\GPUCache",
        "$env:APPDATA\discord\DawnCache",
        "$env:APPDATA\discordptb\Cache\Cache_Data",
        "$env:APPDATA\discordptb\Code Cache",
        "$env:APPDATA\discordptb\GPUCache",
        "$env:APPDATA\discordcanary\Cache\Cache_Data",
        "$env:APPDATA\discordcanary\Code Cache",
        "$env:APPDATA\discordcanary\GPUCache"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Discord" }
}

# ============================================================
#  TASK 38 - Xbox Game Bar / GameDVR
# ============================================================
if ($selectedTasks -contains 38) {
    Write-Host "  [38] Xbox Game Bar / GameDVR / DXGI Logs" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe\LocalCache",
        "$env:LOCALAPPDATA\Packages\Microsoft.XboxApp_8wekyb3d8bbwe\LocalCache",
        "$env:LOCALAPPDATA\Packages\Microsoft.GamingApp_8wekyb3d8bbwe\LocalCache",
        "$env:APPDATA\Microsoft\Windows\GameDVR",
        "$env:LOCALAPPDATA\Microsoft\Windows\GameDVR",
        "$env:LOCALAPPDATA\Temp\WinStore_Log",
        "C:\Windows\Logs\WMI",
        "C:\Windows\System32\WDI\LogFiles"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "GameDVR/DXGI" }
    $dxgiLogs  = @(Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "DXGI*.log" -Force -ErrorAction SilentlyContinue)
    $dxgiLogs += @(Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "D3D*.log"  -Force -ErrorAction SilentlyContinue)
    $sz = 0
    foreach ($f in $dxgiLogs) {
        $sz += $f.Length
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    }
    $mb = [math]::Round($sz / 1MB, 2)
    $script:TotalFreed += $mb
    if ($dxgiLogs.Count -gt 0) { Log "clear  DXGI Logs  ($($dxgiLogs.Count) files, $mb MB)" }
}

# ============================================================
#  TASK 39 - Crash Dumps
# ============================================================
if ($selectedTasks -contains 39) {
    Write-Host "  [39] Crash Dumps" -ForegroundColor Cyan
    $paths = @(
        "C:\Windows\Minidump",
        "C:\Windows\MEMORY.DMP",
        "$env:LOCALAPPDATA\CrashDumps",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Crash Dumps" }
    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-ItemsSafe "$($_.FullName)\AppData\Local\CrashDumps" "User Crash Dumps"
    }
}

# ============================================================
#  TASK 40 - Visual Studio / .NET Temp
# ============================================================
if ($selectedTasks -contains 40) {
    Write-Host "  [40] Visual Studio / .NET Temp" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\VisualStudio\Packages\_Temp",
        "$env:LOCALAPPDATA\Microsoft\WebSiteCache",
        "$env:APPDATA\Microsoft\VisualStudio",
        "$env:LOCALAPPDATA\Temp\VSFeedbackIntelliCodeLogs",
        "$env:LOCALAPPDATA\Temp\Microsoft Visual Studio",
        "$env:LOCALAPPDATA\Microsoft\dotnet",
        "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Temporary ASP.NET Files",
        "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "VS/.NET Temp" }
    $roslyn = @(Get-ChildItem "$env:TEMP" -Filter "VBCSCompiler*" -Force -ErrorAction SilentlyContinue)
    $sz = 0
    foreach ($f in $roslyn) {
        $sz += $f.Length
        Remove-Item $f.FullName -Force -Recurse -ErrorAction SilentlyContinue
    }
    $mb = [math]::Round($sz / 1MB, 2)
    $script:TotalFreed += $mb
    if ($roslyn.Count -gt 0) { Log "clear  Roslyn Compiler Temp  ($mb MB)" }
}

# ============================================================
#  TASK 41 - npm Cache
# ============================================================
if ($selectedTasks -contains 41) {
    Write-Host "  [41] npm Cache" -ForegroundColor Cyan
    try {
        $npmCache = & npm config get cache 2>$null
        if ($npmCache -and (Test-Path $npmCache)) {
            Remove-ItemsSafe $npmCache "npm Cache"
        } else {
            Remove-ItemsSafe "$env:APPDATA\npm-cache" "npm Cache"
            Remove-ItemsSafe "$env:LOCALAPPDATA\npm-cache" "npm Cache"
        }
    } catch { Log "error  npm Cache  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 42 - pip Cache
# ============================================================
if ($selectedTasks -contains 42) {
    Write-Host "  [42] pip Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\pip\Cache",
        "$env:APPDATA\pip\Cache"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "pip Cache" }
}

# ============================================================
#  TASK 43 - Zoom Cache
# ============================================================
if ($selectedTasks -contains 43) {
    Write-Host "  [43] Zoom Cache" -ForegroundColor Cyan
    Stop-AppSafe "Zoom"
    $paths = @(
        "$env:APPDATA\Zoom\data\cache",
        "$env:APPDATA\Zoom\logs",
        "$env:LOCALAPPDATA\Zoom\logs",
        "$env:TEMP\Zoom"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Zoom" }
}

# ============================================================
#  TASK 44 - Adobe Cache
# ============================================================
if ($selectedTasks -contains 44) {
    Write-Host "  [44] Adobe Cache" -ForegroundColor Cyan
    $paths = @(
        "$env:LOCALAPPDATA\Adobe\Color\Cache",
        "$env:APPDATA\Adobe\Common\Media Cache Files",
        "$env:APPDATA\Adobe\Common\Media Cache",
        "$env:LOCALAPPDATA\Temp\Adobe",
        "$env:LOCALAPPDATA\Adobe\Lightroom\Cache",
        "$env:LOCALAPPDATA\Adobe\Creative Cloud Libraries\com.adobe.librariesaccessagent\Cache"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Adobe Cache" }
}

# ============================================================
#  TASK 45 - TeamViewer / AnyDesk Logs
# ============================================================
if ($selectedTasks -contains 45) {
    Write-Host "  [45] TeamViewer / AnyDesk Logs" -ForegroundColor Cyan
    $paths = @(
        "$env:APPDATA\TeamViewer\Logs",
        "C:\Program Files\TeamViewer\Logs",
        "C:\Program Files (x86)\TeamViewer\Logs",
        "$env:APPDATA\AnyDesk",
        "$env:PROGRAMDATA\AnyDesk"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "Remote Access Logs" }
}

# ============================================================
#  TASK 46 - OBS Temp
# ============================================================
if ($selectedTasks -contains 46) {
    Write-Host "  [46] OBS Temp" -ForegroundColor Cyan
    Stop-AppSafe "obs64"
    Stop-AppSafe "obs32"
    $paths = @(
        "$env:APPDATA\obs-studio\logs",
        "$env:APPDATA\obs-studio\crashes",
        "$env:APPDATA\obs-studio\profiler_data"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "OBS" }
}

# ============================================================
#  TASK 47 - Font Cache (prompt -- restarts Explorer)
# ============================================================
if ($selectedTasks -contains 47) {
    Write-Host "  [47] Font Cache" -ForegroundColor Cyan
    if (Confirm-Risky "Deletes font cache DB files. Explorer will be restarted briefly.") {
        try {
            Stop-Service FontCache  -Force -ErrorAction SilentlyContinue
            Stop-Service FontCache3 -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            $sz = 0
            Get-ChildItem "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache" `
                -Filter "*.dat" -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $sz += $_.Length
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            }
            Remove-Item "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache3\FontCache3.dat" `
                -Force -ErrorAction SilentlyContinue
            Start-Service FontCache  -ErrorAction SilentlyContinue
            Start-Service FontCache3 -ErrorAction SilentlyContinue
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process "C:\Windows\explorer.exe"
            $mb = [math]::Round($sz / 1MB, 2)
            $script:TotalFreed += $mb
            Log "clear  Font Cache  ($mb MB, Explorer restarted)"
        } catch { Log "error  Font Cache  $($_.Exception.Message)" }
    } else { Log "skip   Font Cache (user declined)" }
}

# ============================================================
#  TASK 48 - WinSAT Results
# ============================================================
if ($selectedTasks -contains 48) {
    Write-Host "  [48] WinSAT Results" -ForegroundColor Cyan
    Remove-ItemsSafe "C:\Windows\Performance\WinSAT\DataStore" "WinSAT"
}

# ============================================================
#  TASK 49 - Windows.old (prompt)
# ============================================================
if ($selectedTasks -contains 49) {
    Write-Host "  [49] Windows.old" -ForegroundColor Cyan
    if (Test-Path "C:\Windows.old") {
        if (Confirm-Risky "Permanently deletes C:\Windows.old. You will LOSE the ability to roll back to your previous Windows version.") {
            try {
                $sz = Get-FolderSize "C:\Windows.old"
                & takeown /F "C:\Windows.old" /R /D Y 2>$null
                & icacls "C:\Windows.old" /grant administrators:F /T /C /Q 2>$null
                Remove-Item "C:\Windows.old" -Recurse -Force -ErrorAction SilentlyContinue
                $freed = [math]::Round($sz - (Get-FolderSize "C:\Windows.old"), 2)
                $script:TotalFreed += $freed
                Log "clear  Windows.old  ($freed MB)"
            } catch { Log "error  Windows.old  $($_.Exception.Message)" }
        } else { Log "skip   Windows.old (user declined)" }
    } else { Log "skip   Windows.old (not found)" }
}

# ============================================================
#  TASK 50 - DISM Component Store Cleanup (prompt)
# ============================================================
if ($selectedTasks -contains 50) {
    Write-Host "  [50] DISM Component Cleanup" -ForegroundColor Cyan
    if (Confirm-Risky "Runs DISM /StartComponentCleanup. Takes several minutes and cannot be undone.") {
        try {
            Log "note   DISM Component Cleanup starting (this takes a while)..."
            & dism /online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
            Log "clear  DISM Component Cleanup (done)"
        } catch { Log "error  DISM  $($_.Exception.Message)" }
    } else { Log "skip   DISM (user declined)" }
}

# ============================================================
#  SUMMARY
# ============================================================
$FreedGB = [math]::Round($TotalFreed / 1024, 2)
Write-Host ""
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host "  DONE" -ForegroundColor Green
Write-Host ""
if ($TotalFreed -ge 1024) {
    Write-Host "  Freed  ~$FreedGB GB" -ForegroundColor Cyan
} else {
    Write-Host "  Freed  ~$TotalFreed MB" -ForegroundColor Cyan
}
Write-Host "  Log    $LogFile" -ForegroundColor DarkGray
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Log "session end  |  freed ~$TotalFreed MB"

Read-Host "  Press Enter to exit"