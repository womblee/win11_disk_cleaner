<h1 align="center">Windows 11 Disk Cleaner (W11DS)</h1>

<p align="center">A PowerShell script for cleaning and maintaining Windows 11 systems. Removes temporary files, browser caches, app caches, system logs, GPU shader caches, crash dumps, and more — all from an interactive menu so you pick exactly what runs.</p>

<hr>

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![OS](https://img.shields.io/badge/Windows-11-lightgrey)
![Version](https://img.shields.io/badge/Version-2.0-green)

---

## Requirements

- Windows 8.1, 10 or 11
- Administrator privileges (the script auto-elevates if not already running as Admin)
  
  <img width="488" height="257" alt="image" src="https://github.com/user-attachments/assets/3450fcfd-d3ec-4097-b05d-4b5703f9ca4c" />

---

## Usage

### Method 1 — Download and run ❤️

**Copy and paste** this into your PowerShell window **as administrator**.

```powershell
irm https://raw.githubusercontent.com/womblee/win11_disk_cleaner/main/win11_cleaner.ps1 -OutFile "$env:TEMP\win11_cleaner.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\win11_cleaner.ps1"
```

### Method 2 — Run locally

If you've cloned or downloaded the repo, allow `.ps1` files to run (one-time):

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

Then run:

```powershell
.\win11_cleaner.ps1
```

If Windows says the file is blocked, unblock it first:

```powershell
Unblock-File -Path .\win11_cleaner.ps1
```

---

## Menu

When the script launches you'll see the full task list. Enter numbers separated by commas, `A` to run everything, or `Q` to quit.

```
1,2,6,34      run specific tasks
A             run all tasks
Q             quit
```

---

## Available Tasks

### Temp + Cache

| # | Task |
|---|------|
| 1 | Windows Temp Folder |
| 2 | User Temp Folder |
| 3 | Windows Update Cache |
| 4 | Prefetch Files |

### Browsers

| # | Task |
|---|------|
| 5 | Microsoft Edge |
| 6 | Google Chrome |
| 7 | Mozilla Firefox |
| 18 | Brave |

> Cache and temp files only. Cookies and login sessions are not touched.

### Apps

| # | Task |
|---|------|
| 32 | Spotify Cache |
| 33 | Telegram Cache |

> Spotify and Telegram are terminated before clearing. They relaunch normally afterwards.

### Logs + Diagnostics

| # | Task |
|---|------|
| 8 | Windows Event Logs |
| 9 | Windows Diagnostic Traces |
| 10 | CBS (Component-Based Servicing) Logs |

### Recycle + Restore

| # | Task |
|---|------|
| 11 | Empty Recycle Bin (all drives) |
| 12 | Old Shadow Copies (keeps latest) |
| 31 | Old System Restore Points (keeps latest) |

### Performance + Startup

| # | Task |
|---|------|
| 19 | Windows Performance Counters |

### Disk + Store

| # | Task |
|---|------|
| 20 | Windows Disk Cleanup (GUI) |
| 21 | Microsoft Store Cache |

### Cache + Icons

| # | Task |
|---|------|
| 15 | Rebuild Windows Search Index |
| 16 | Thumbnail Cache |
| 17 | Icon Cache |
| 24 | Notification Cache |
| 25 | Recent Files + Jump Lists |

### Network

| # | Task |
|---|------|
| 26 | Flush DNS Cache |
| 27 | Reset TCP/IP Stack |

### Telemetry

| # | Task |
|---|------|
| 28 | Delivery Optimization Cache (DOSVC) |
| 29 | Windows Update Logs |

### Gaming

| # | Task |
|---|------|
| 34 | Steam Cache (HTML cache, shader cache, download depots) |
| 35 | GPU Shader Cache (NVIDIA + AMD) |
| 36 | DirectX Shader Cache (D3DSCache) |
| 37 | Discord Cache (stable, PTB, Canary) |
| 38 | Xbox Game Bar / GameDVR / DXGI Logs |
| 39 | Crash Dumps (minidumps, app dumps, WER reports) |

> Steam and Discord are terminated before clearing.

### Dev Tools

| # | Task |
|---|------|
| 40 | Visual Studio / .NET Temp (packages temp, ASP.NET temp files, Roslyn compiler cache) |

---

## Tasks that require confirmation

These tasks prompt `[Y]` before running due to their impact:

| # | Reason |
|---|--------|
| 12 | Deletes all shadow copies except the most recent |
| 20 | Opens the Windows Disk Cleanup wizard |
| 27 | Resets TCP/IP stack — network will briefly drop |
| 31 | Deletes all restore points except the most recent |

---

## Logging

Each run saves a log file in the same folder as the script:

```
cleaner_YYYYMMDD_HHmmss.log
```

Every task is logged as `clear`, `skip`, or `error`, with the amount freed in MB.

---

## Safe to run?

- **Browser tasks** only clear cache — cookies and sessions are untouched.
- **Tasks 12 and 31** keep your most recent shadow copy / restore point.
- **Task 15** resets the search index — Windows rebuilds it automatically in the background.
- **Task 17** restarts Explorer briefly to rebuild the icon cache.
- **Task 20** opens the built-in Windows Disk Cleanup tool.
- **Task 27** resets TCP/IP — network reconnects on its own within seconds.
- **GPU / DirectX shader caches** (35, 36) are rebuilt automatically by your drivers and games on next launch.
- **Crash dumps** (39) are debug files only — safe to delete unless you are actively diagnosing a crash.

---

## License

Copyright [2026] [nloginov]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
