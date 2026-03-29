# Remove-Win11Bloatware

A comprehensive, production-ready PowerShell script to safely remove bloatware and optimize Windows 11.

## Features

- **Bloatware Removal** — Xbox, Cortana, Microsoft Teams, Clipchamp, News, Weather, Maps, Zune, and more
- **Edge Removal** — Optional complete removal of Microsoft Edge
- **OneDrive Removal** — Optional unlinking and uninstallation of OneDrive
- **Telemetry & Telemetry** — Disable diagnostics tracking, feedback hub, and tailored experiences
- **Background Apps** — Disable apps running in the background
- **Tips & Notifications** — Remove tips app and disable tips notifications
- **Widgets** — Remove Windows Widgets board and widget service
- **Windows Copilot** — Disable and remove Windows Copilot
- **Windows Recall** — Disable Windows Recall snapshot feature
- **Startup Apps** — Remove unwanted apps from Windows startup
- **Consumer Features** — Disable "Suggested" apps in the Start menu and "Recommended" in File Explorer

## Safety Features

- **Restore Point** — Automatically creates a System Restore point before making changes
- **Logging** — Full transcript logging with timestamps
- **Dry-Run Mode** — Preview all changes without applying them (`-DryRun`)
- **Idempotent** — Safe to run multiple times; re-running won't break anything
- **Admin Check** — Requires Administrator privileges
- **OS Validation** — Confirms Windows 10/11 before proceeding
- **Try/Catch** — All operations wrapped in error handling
- **Confirmation Prompts** — Prompts before each major change
- **Summary Report** — End-of-run report showing what was done and what failed

## Requirements

- Windows 10 or Windows 11 (Home or Pro)
- Administrator privileges
- PowerShell 5.1 or higher

No third-party tools required.

## Usage

### Quick Start

```powershell
# Run with all defaults (interactive prompts)
.\Remove-Win11Bloatware.ps1

# Dry-run (preview changes)
.\Remove-Win11Bloatware.ps1 -DryRun

# Disable specific categories
.\Remove-Win11Bloatware.ps1 -RemoveXbox -RemoveTeams -RemoveCortana

# Skip all prompts (fully automated)
.\Remove-Win11Bloatware.ps1 -Unattended

# Disable everything except essential services
.\Remove-Win11Bloatware.ps1 -RemoveAll
```

### All Switches

| Switch | Description |
|---|---|
| `-DryRun` | Preview all operations without making changes |
| `-Unattended` | Skip all confirmation prompts |
| `-RemoveXbox` | Remove Xbox app and related components |
| `-RemoveCortana` | Remove Cortana |
| `-RemoveTeams` | Remove Microsoft Teams (personal) |
| `-RemoveClipchamp` | Remove Clipchamp video editor |
| `-RemoveNews` | Remove Microsoft News |
| `-RemoveWeather` | Remove Weather app |
| `-RemoveMaps` | Remove Maps app |
| `-RemoveZune` | Remove Zune Music Player |
| `-RemoveEdge` | Remove Microsoft Edge |
| `-RemoveOneDrive` | Remove OneDrive |
| `-DisableTelemetry` | Disable telemetry and diagnostics |
| `-DisableBackgroundApps` | Disable apps running in background |
| `-DisableTips` | Remove tips app and notifications |
| `-RemoveWidgets` | Remove Windows Widgets |
| `-DisableCopilot` | Disable Windows Copilot |
| `-DisableRecall` | Disable Windows Recall |
| `-RemoveStartupApps` | Remove unwanted startup apps |
| `-DisableConsumerFeatures` | Disable "Suggested" apps and recommendations |
| `-RemoveAll` | Enable all removal options |
| `-RestoreAll` | Restore all removed apps and re-enable all services |
| `-SkipRestorePoint` | Skip creating a restore point |

### Restore Script

On first run, the script automatically generates a companion restore script: `Restore-Win11Apps.ps1`. This script will re-install all removed apps and re-enable all disabled services. Keep this file safe.

You can also trigger restore mode by running:
```powershell
.\Remove-Win11Bloatware.ps1 -RestoreAll
```

## What Gets Removed / Disabled

### Apps Removed
- Microsoft.XboxIdentityProvider
- Microsoft.XboxSpeechService
- Microsoft.GamingApp
- Microsoft.BingNews
- Microsoft.BingWeather
- Microsoft.WindowsMaps
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo
- Microsoft.Windows.Photos
- Microsoft.GetHelp
- Microsoft.Getstarted
- Microsoft.MicrosoftOfficeHub
- Microsoft.MicrosoftSolitaireCollection
- Microsoft.Office.OneNote
- Microsoft.OneDrive (optional)
- Microsoft.Todos
- Microsoft.People
- Microsoft.PowerAutomateDesktop
- Microsoft.YourPhone
- Microsoft.Windows.Cortana
- MicrosoftTeams
- Microsoft.Clipchamp
- Microsoft.MicrosoftEdge (optional)
- Microsoft.549981C3P5RR1 (Copilot)

### Services Disabled
- DiagTrack (Connected User Experiences and Telemetry)
- dmwappushservice (Device Management Wireless Application Protocol)
- RetailDemo

### Registry Changes
- Telemetry levels reduced
- Feedback frequency set to Never
- Tailored experiences disabled
- Windows Update delivery optimization disabled
- Cortana policy restrictions
- Search web suggestions disabled
- Copilot removed from taskbar
- Recall snapshots disabled
- Consumer features disabled
- Background app permissions revoked

### Scheduled Tasks Removed
- XblGameSaveTask
- XblGameSaveTaskLogon
- Consolidator
- UsrOvrApiRefl
- KernelCeipTask
- DmClient

## What Is NOT Modified

The script intentionally avoids modifying critical Windows components:

- Windows Update
- Microsoft Store
- Windows Defender / Security
- Networking stack
- Print services
- Hyper-V
- WSL

## Logs

All runs are logged. Log files are saved to:
- `%LOCALAPPDATA%\Remove-Win11Bloatware\Logs\`

## Disclaimer

This script modifies Windows system components. Use at your own risk. Always back up important data and create a restore point before running. The companion restore script (`Restore-Win11Apps.ps1`) can undo most changes.

## License

MIT License — see [LICENSE](LICENSE) for details.
