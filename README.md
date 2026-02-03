# Win11 Cleaner

A PowerShell script for cleaning and maintaining Windows 11 systems. Removes temporary files, browser caches, system logs, and other junk — all from an interactive menu so you pick exactly what runs.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![OS](https://img.shields.io/badge/Windows-11-lightgrey)
![Version](https://img.shields.io/badge/Version-1.2-green)

---

## Requirements

- Windows 11
- PowerShell 5.1 or later
- Administrator privileges (the script auto-elevates if not already running as Admin)

---

## Setup

### Allow the script to run

PowerShell blocks unsigned scripts by default. Run this once in an elevated PowerShell window to allow `.ps1` files for your account:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

### Run the script
```powershell
.\Win11_Cleaner.ps1
```

Or right-click the file and select **Run with PowerShell**.

---

## Available Tasks

### Temporary Files + Caches

| # | Task |
|---|------|
| 1 | Windows Temp Folder |
| 2 | User Temp Folder |
| 3 | Windows Update Cache |
| 4 | Prefetch Files |

### Browser Caches

| # | Task |
|---|------|
| 5 | Microsoft Edge Cache |
| 6 | Google Chrome Cache |
| 7 | Mozilla Firefox Cache |
| 18 | Brave Browser Cache |

> **Note:** Browser cleaning targets cache and temp files only. Cookies and login sessions are not touched — you will not be logged out of anything.

### Windows Logs + Diagnostics

| # | Task |
|---|------|
| 8 | Windows Event Logs |
| 9 | Windows Diagnostic Traces |
| 10 | CBS (Component-Based Servicing) Logs |

### Recycle Bin + Restore

| # | Task |
|---|------|
| 11 | Empty Recycle Bin (All Drives) |
| 12 | Old Shadow Copies / Restore Points |

### Startup + Performance

| # | Task |
|---|------|
| 19 | Clear Windows Performance Counters |

### Disk + Storage

| # | Task |
|---|------|
| 20 | Run Windows Disk Cleanup (automated) |
| 21 | Microsoft Store Cache |

### App + System Residual

| # | Task |
|---|------|
| 24 | Windows Notification Cache |
| 25 | Recent Files + Jump List Cache |

### Windows Search + Indexing

| # | Task |
|---|------|
| 15 | Rebuild Windows Search Index |

### Thumbnail + Icon Caches

| # | Task |
|---|------|
| 16 | Thumbnail Cache |
| 17 | Icon Cache (IconCache.db) |

### Network

| # | Task |
|---|------|
| 26 | Flush DNS Cache |
| 27 | Reset TCP/IP Stack |

### Windows Telemetry + Logs

| # | Task |
|---|------|
| 28 | Delivery Optimization Cache (DOSVC) |
| 29 | Windows Update Logs |

### System Restore

| # | Task |
|---|------|
| 31 | System Restore Points (all except latest) |

---

## Usage

When the script launches, you'll see the full menu. You can either:

- **Pick specific tasks** — enter the numbers separated by commas, e.g. `1,2,5,18`
- **Run everything** — enter `A`
- **Quit** — enter `Q`

### Tasks that require confirmation

The following tasks will prompt you to type `yes` before they execute, since they have a bigger impact:

- **12** — Deletes all shadow copies except the most recent one
- **27** — Resets the TCP/IP stack (network will briefly drop and reconnect)
- **31** — Deletes all system restore points except the most recent one

---

## Logging

Every run generates a log file on your Desktop:
```
Win11_Cleaner_Log_YYYY-MM-DD_HH-mm-ss.txt
```

It records every task that ran, was skipped, or errored, along with how much space each task freed.

---

## Safe to run?

- **Browser tasks** only clear cache — cookies and sessions are untouched.
- **Task 12 and 31** keep your most recent shadow copy / restore point and only delete older ones.
- **Task 15** resets the search index — Windows rebuilds it automatically in the background.
- **Task 17** restarts Explorer briefly to rebuild the icon cache.
- **Task 20** runs the built-in Windows Disk Cleanup tool silently.
- **Task 27** resets TCP/IP — your network will reconnect on its own within a few seconds.

---

## License

This project is unlicensed and provided as-is for personal use.