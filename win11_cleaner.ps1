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
$LogFile    = Join-Path $ScriptDir ("cleaner_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
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
    param([string]$Path, [string]$Label)
    if (-not (Test-Path $Path)) { Log "skip   $Label"; return }
    $mb = Get-FolderSize $Path
    try {
        Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        $script:TotalFreed += $mb
        Log "clear  $Label  ($mb MB)"
    } catch {
        Log "error  $Label  $($_.Exception.Message)"
    }
}

function Remove-SubFolderContents {
    param([string]$ParentPath, [string]$Label)
    if (-not (Test-Path $ParentPath)) { Log "skip   $Label"; return }
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

function Confirm-Risky {
    param([string]$Warning)
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
Write-Host "  WIN11 CLEANER" -ForegroundColor Cyan
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
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
Write-Host "  20  Disk Cleanup (GUI)"
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
Write-Host "  27  Reset TCP/IP Stack"
Write-Host ""
Write-Host "  TELEMETRY" -ForegroundColor White
Write-Host "  28  Delivery Optimization Cache"
Write-Host "  29  Windows Update Logs"
Write-Host ""
Write-Host "  GAMING" -ForegroundColor White
Write-Host "  34  Steam Cache (shader + download depots)"
Write-Host "  35  GPU Shader Cache (NVIDIA / AMD)"
Write-Host "  36  DirectX Shader Cache (D3DSCache)"
Write-Host "  37  Discord Cache"
Write-Host "  38  Xbox Game Bar / GameDVR / DXGI Logs"
Write-Host "  39  Crash Dumps (system + app)"
Write-Host ""
Write-Host "  DEV TOOLS" -ForegroundColor White
Write-Host "  40  Visual Studio / .NET Temp"
Write-Host ""
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host "   A  Run all     Q  Quit" -ForegroundColor Cyan
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Tasks (e.g. 1,2,5 or A): " -ForegroundColor Green -NoNewline
$userInput = Read-Host

$allTasks = @(1,2,3,4,5,6,7,8,9,10,11,12,15,16,17,18,19,20,21,24,25,26,27,28,29,31,32,33,34,35,36,37,38,39,40)
$selectedTasks = @()

if ($userInput.Trim().ToUpper() -eq "A") {
    $selectedTasks = $allTasks
} elseif ($userInput.Trim().ToUpper() -eq "Q") {
    exit
} else {
    $selectedTasks = $userInput.Split(",") | ForEach-Object { [int]$_.Trim() }
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
# ============================================================
if ($selectedTasks -contains 3) {
    Write-Host "  [3] Windows Update Cache" -ForegroundColor Cyan
    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Remove-ItemsSafe "C:\Windows\SoftwareDistribution\Download" "WU Cache"
        Start-Service wuauserv -ErrorAction SilentlyContinue
    } catch { Log "error  WU Cache  $($_.Exception.Message)" }
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
        Get-PSDrive -Persist | Where-Object { $_.Root -like "*:\" } | ForEach-Object {
            $rb = "$($_.Name):\`$Recycle.Bin"
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
    } else { Log "skip   Shadow Copies (user cancelled)" }
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
        lodctr /r 2>$null
        Log "clear  Performance Counters"
    } catch { Log "error  Performance Counters  $($_.Exception.Message)" }
}

# ============================================================
#  TASK 20 - Disk Cleanup
# ============================================================
if ($selectedTasks -contains 20) {
    Write-Host "  [20] Disk Cleanup (GUI)" -ForegroundColor Cyan
    if (Confirm-Risky "This will open the Windows Disk Cleanup wizard.") {
        try {
            Start-Process "cleanmgr.exe" -ArgumentList "/sageset:100" -Wait -NoNewWindow
            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -NoNewWindow
            Log "clear  Disk Cleanup"
        } catch { Log "error  Disk Cleanup  $($_.Exception.Message)" }
    } else { Log "skip   Disk Cleanup (user cancelled)" }
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
#  TASK 27 - Reset TCP/IP Stack
# ============================================================
if ($selectedTasks -contains 27) {
    Write-Host "  [27] Reset TCP/IP Stack" -ForegroundColor Cyan
    if (Confirm-Risky "Network connection will briefly drop.") {
        try {
            netsh int ip reset 2>$null
            netsh int tcp reset 2>$null
            Log "clear  TCP/IP Stack (reboot recommended)"
        } catch { Log "error  TCP/IP  $($_.Exception.Message)" }
    } else { Log "skip   TCP/IP (user cancelled)" }
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
    $paths = @(
        "C:\Windows\Logs\WindowsUpdate",
        "C:\Windows\Logs\WinSetupLog",
        "C:\Windows\Logs\DISM",
        "C:\Windows\WindowsUpdate.log"
    )
    foreach ($p in $paths) { Remove-ItemsSafe $p "WU Logs" }
}

# ============================================================
#  TASK 31 - Old Restore Points
# ============================================================
if ($selectedTasks -contains 31) {
    Write-Host "  [31] Old Restore Points" -ForegroundColor Cyan
    if (Confirm-Risky "Keeps only the most recent restore point.") {
        try {
            $rps = Get-WmiObject Win32_ShadowCopy -ErrorAction SilentlyContinue |
                   Where-Object { $_.OriginatingMachine -eq $env:COMPUTERNAME }
            if (-not $rps -or $rps.Count -le 1) {
                Log "skip   Restore Points (nothing to delete)"
            } else {
                $sorted = $rps | Sort-Object { $_.CreateTime } -Descending
                $sorted[1..($sorted.Count-1)] | ForEach-Object { $_.Delete() }
                Log "clear  Restore Points  ($($sorted.Count - 1) deleted, kept latest)"
            }
        } catch { Log "error  Restore Points  $($_.Exception.Message)" }
    } else { Log "skip   Restore Points (user cancelled)" }
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
    # Steam library shader caches - check default and common library locations
    $steamLibs = @("C:\Program Files (x86)\Steam", "$env:LOCALAPPDATA\Steam")
    foreach ($lib in $steamLibs) {
        Remove-ItemsSafe "$lib\steamapps\shadercache" "Steam Shader Cache"
        Remove-ItemsSafe "$lib\package\chunks"        "Steam Download Chunks"
    }
    # Also check for Steam library folders file and parse extra libraries
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
#  TASK 35 - GPU Shader Cache
# ============================================================
if ($selectedTasks -contains 35) {
    Write-Host "  [35] GPU Shader Cache" -ForegroundColor Cyan
    # NVIDIA
    $nvPaths = @(
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\NVIDIA\GLCache",
        "$env:APPDATA\NVIDIA\ComputeCache"
    )
    foreach ($p in $nvPaths) { Remove-ItemsSafe $p "NVIDIA Cache" }
    # AMD
    $amdPaths = @(
        "$env:LOCALAPPDATA\AMD\DxCache",
        "$env:LOCALAPPDATA\AMD\VkCache",
        "$env:TEMP\AMD"
    )
    foreach ($p in $amdPaths) { Remove-ItemsSafe $p "AMD Cache" }
}

# ============================================================
#  TASK 36 - DirectX Shader Cache
# ============================================================
if ($selectedTasks -contains 36) {
    Write-Host "  [36] DirectX Shader Cache" -ForegroundColor Cyan
    Remove-ItemsSafe "$env:LOCALAPPDATA\D3DSCache" "D3DSCache"
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
    # DXGI / D3D debug logs
    $dxgiLogs = Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "DXGI*.log" -Force -ErrorAction SilentlyContinue
    $dxgiLogs += Get-ChildItem "$env:LOCALAPPDATA\Temp" -Filter "D3D*.log" -Force -ErrorAction SilentlyContinue
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
    # Per-user crash dumps from other users
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
    # Roslyn / build server logs
    $roslyn = Get-ChildItem "$env:TEMP" -Filter "VBCSCompiler*" -Force -ErrorAction SilentlyContinue
    $sz = 0
    foreach ($f in $roslyn) { $sz += $f.Length; Remove-Item $f.FullName -Force -Recurse -ErrorAction SilentlyContinue }
    $mb = [math]::Round($sz / 1MB, 2)
    $script:TotalFreed += $mb
    if ($roslyn.Count -gt 0) { Log "clear  Roslyn Compiler Temp  ($mb MB)" }
}

# ============================================================
#  SUMMARY
# ============================================================
$FreedGB = [math]::Round($TotalFreed / 1024, 2)
Write-Host ""
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host "  DONE" -ForegroundColor Green
Write-Host ""
if ($TotalFreed -ge 1024) {
    Write-Host "  Freed  ~$FreedGB GB" -ForegroundColor Green
} else {
    Write-Host "  Freed  ~$TotalFreed MB" -ForegroundColor Green
}
Write-Host "  Log    $LogFile" -ForegroundColor DarkGray
Write-Host "  -------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Log "session end  |  freed ~$TotalFreed MB"

Read-Host "  Press Enter to exit"
