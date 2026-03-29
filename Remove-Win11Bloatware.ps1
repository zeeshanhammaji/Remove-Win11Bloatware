#Requires -Version 5.1
<#
.SYNOPSIS
    Windows 11 Bloatware Removal & Optimization Script

.DESCRIPTION
    A comprehensive, production-ready script to safely remove pre-installed bloatware
    from Windows 11 Home and Pro. Includes safety features such as restore point creation,
    full logging, dry run mode, and idempotent operation.

.PARAMETER DryRun
    Shows what would be removed/changed without executing any actions.

.PARAMETER LogPath
    Path to the log file. Defaults to "$env:USERPROFILE\Desktop\Win11Debloat.log"

.EXAMPLE
    # Interactive run with defaults
    .\Remove-Win11Bloatware.ps1

    # Preview mode - no changes made
    .\Remove-Win11Bloatware.ps1 -DryRun

    # Custom log path
    .\Remove-Win11Bloatware.ps1 -LogPath "C:\Logs\debloat.log"

.NOTES
    Author      : Windows 11 Debloat Script
    Version     : 2.0
    Requires    : PowerShell 5.1+, Windows 11, Administrator privileges
    Safe to run : Multiple times (idempotent)
    
    RESTORE: To reinstall removed apps, see the companion script:
             Restore-Win11Apps.ps1  (generated automatically on first run)
    
    WARNING: Review all toggles in the CONFIGURATION section before running.
             Some settings may impact features you rely on.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,
    [string]$LogPath = "$env:USERPROFILE\Desktop\Win11Debloat.log"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ==============================================================================
# CONFIGURATION — Edit these toggles before running
# ==============================================================================

$Config = [ordered]@{

    # --- Core Bloatware ---
    RemoveXboxApps          = $true   # Removes Xbox Game Bar, Xbox Identity Provider, etc.
    RemoveCortana           = $true   # Removes Cortana AI assistant
    RemoveTeamsConsumer     = $true   # Removes consumer Microsoft Teams (chat icon)
    RemoveClipchamp         = $true   # Removes Clipchamp video editor
    RemoveNewsAndInterests  = $true   # Removes MSN News app
    RemoveWeather           = $true   # Removes MSN Weather app
    RemoveGetHelp           = $true   # Removes Get Help / Contact Support app
    RemoveFeedbackHub       = $true   # Removes Feedback Hub
    RemoveMaps              = $true   # Removes Windows Maps
    RemoveZuneMusic         = $true   # Removes Groove Music (Zune Music)
    RemoveZuneVideo         = $true   # Removes Movies & TV (Zune Video)
    RemoveSolitaireCollection = $true # Removes Microsoft Solitaire Collection
    RemoveMixedReality      = $true   # Removes Mixed Reality Portal
    RemovePaint3D           = $true   # Removes Paint 3D (classic Paint is kept)
    RemoveSkype             = $true   # Removes Skype
    RemovePowerAutomate     = $true   # Removes Power Automate Desktop
    RemoveToDo              = $true   # Removes Microsoft To Do
    RemoveYourPhone         = $true   # Removes Phone Link / Your Phone
    RemoveBingSearch        = $true   # Removes Bing apps bundled in Store
    RemoveOneConnect        = $true   # Removes Mobile Plans
    RemovePeople            = $true   # Removes People app
    RemoveAlarms            = $true   # Removes Alarms & Clock
    RemovePrint3D           = $true   # Removes Print 3D
    RemoveStickyNotes       = $false  # Keep Sticky Notes (useful for many users)
    RemoveCalculator        = $false  # Keep Calculator (essential)
    RemoveCamera            = $false  # Keep Camera app
    RemoveSnippingTool      = $false  # Keep Snipping Tool (essential)

    # --- Optional / Risky Toggles (default: false) ---
    RemoveMicrosoftEdge     = $false  # Removing Edge can break some Windows features
    RemoveOneDrive          = $false  # Removes OneDrive client (files stay in cloud)
    RemoveWidgets           = $true   # Removes the Widgets panel (news feed)
    RemoveCopilot           = $true   # Removes Windows Copilot sidebar
    RemoveRecall            = $true   # Removes Windows Recall (AI screenshot feature)

    # --- Privacy & Telemetry ---
    DisableTelemetry        = $true   # Disables diagnostic data collection
    DisableAdvertisingId    = $true   # Disables personalized ad tracking ID
    DisableActivityHistory  = $true   # Disables activity timeline
    DisableLocationTracking = $false  # Keep location ON (some apps need it)

    # --- Performance & UI ---
    DisableBackgroundApps   = $true   # Stops Store apps from running in background
    DisableWindowsTips      = $true   # Disables "Did you know" tips and suggestions
    DisableConsumerFeatures = $true   # Disables auto-install of promoted Store apps
    DisableStartupApps      = $false  # Auto-disables all startup apps (aggressive)
    DisableCortanaSearch    = $true   # Disables Cortana from Windows Search
    DisableWebSearch        = $true   # Disables Bing results in Start Menu search
    DisableGameBar          = $true   # Disables Xbox Game Bar overlay

    # --- Restore Point ---
    CreateRestorePoint      = $true   # Creates a System Restore Point before changes
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

# Script metadata
$ScriptVersion  = "2.0"
$ScriptStart    = Get-Date
$RestoreScript  = Join-Path (Split-Path $LogPath) "Restore-Win11Apps.ps1"
$RemovedApps    = [System.Collections.Generic.List[string]]::new()
$SkippedApps    = [System.Collections.Generic.List[string]]::new()
$Errors         = [System.Collections.Generic.List[string]]::new()

# --- Logging ---
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS","ACTION","SKIP","DRY")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine   = "[$timestamp] [$Level] $Message"

    # File log (always)
    Add-Content -Path $LogPath -Value $logLine -Encoding UTF8

    # Console with colour
    $colour = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "ACTION"  { "Magenta" }
        "SKIP"    { "DarkGray" }
        "DRY"     { "Blue" }
        default   { "White" }
    }
    Write-Host $logLine -ForegroundColor $colour
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 70
    Write-Log ""
    Write-Log $line
    Write-Log "  $Title"
    Write-Log $line
}

# --- Elevation check ---
function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- OS Version check ---
function Test-Windows11 {
    $build = [System.Environment]::OSVersion.Version.Build
    return $build -ge 22000  # Windows 11 starts at build 22000
}

# ==============================================================================
# SAFETY CHECKS
# ==============================================================================

# Initialise log file
$null = New-Item -ItemType File -Path $LogPath -Force
Write-Log "Windows 11 Debloat Script v$ScriptVersion started" "INFO"
Write-Log "Log file: $LogPath" "INFO"
Write-Log "Dry Run: $DryRun" "INFO"

if (-not (Test-Administrator)) {
    Write-Log "Script must be run as Administrator. Please restart PowerShell as Admin." "ERROR"
    Write-Host "`nPress any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

if (-not (Test-Windows11)) {
    $build = [System.Environment]::OSVersion.Version.Build
    Write-Log "This script targets Windows 11 (build 22000+). Detected build: $build" "WARN"
    $confirm = Read-Host "Continue anyway? (y/N)"
    if ($confirm -notmatch '^[Yy]') { exit 0 }
}

# Dry Run banner
if ($DryRun) {
    Write-Host "`n" + ("~" * 70) -ForegroundColor Blue
    Write-Host "  DRY RUN MODE — No changes will be made to your system" -ForegroundColor Blue
    Write-Host ("~" * 70) + "`n" -ForegroundColor Blue
}

# ==============================================================================
# RESTORE POINT
# ==============================================================================

Write-Section "SYSTEM RESTORE POINT"

if ($Config.CreateRestorePoint -and -not $DryRun) {
    try {
        Write-Log "Creating System Restore Point..." "ACTION"
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer `
            -Description "Before Win11 Debloat Script v$ScriptVersion" `
            -RestorePointType "MODIFY_SETTINGS" `
            -ErrorAction Stop
        Write-Log "Restore point created successfully." "SUCCESS"
    } catch {
        Write-Log "Failed to create restore point: $_" "WARN"
        Write-Log "Tip: Restore points may be disabled. Enable via System Properties > System Protection." "WARN"
        $confirm = Read-Host "Continue without a restore point? (y/N)"
        if ($confirm -notmatch '^[Yy]') { exit 0 }
    }
} elseif ($DryRun) {
    Write-Log "[DRY] Would create a System Restore Point." "DRY"
} else {
    Write-Log "Restore point creation skipped (disabled in config)." "SKIP"
}

# ==============================================================================
# HELPER: Remove AppX Package (current user + provisioned)
# ==============================================================================

function Remove-BloatApp {
    <#
    .SYNOPSIS
        Removes an AppX package for the current user and from the provisioned
        (system-wide) list so it is not reinstalled for new users.
    #>
    param(
        [string]$AppName,       # Friendly display name for logging
        [string[]]$PackageNames # One or more package name patterns (wildcards OK)
    )

    Write-Log "Processing: $AppName" "ACTION"
    $found = $false

    foreach ($pattern in $PackageNames) {

        # --- Current user packages ---
        $userPkgs = Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue
        foreach ($pkg in $userPkgs) {
            $found = $true
            if ($DryRun) {
                Write-Log "[DRY] Would remove user package: $($pkg.PackageFullName)" "DRY"
            } else {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    Write-Log "Removed user package: $($pkg.PackageFullName)" "SUCCESS"
                    $RemovedApps.Add($AppName) | Out-Null
                } catch {
                    Write-Log "Failed to remove $($pkg.PackageFullName): $_" "ERROR"
                    $Errors.Add("$AppName - $($pkg.PackageFullName): $_") | Out-Null
                }
            }
        }

        # --- Provisioned (all-users / new-user) packages ---
        $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                    Where-Object { $_.PackageName -like "*$($pattern.TrimEnd('*').TrimStart('*'))*" }
        foreach ($pkg in $provPkgs) {
            $found = $true
            if ($DryRun) {
                Write-Log "[DRY] Would remove provisioned package: $($pkg.PackageName)" "DRY"
            } else {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                    Write-Log "Removed provisioned package: $($pkg.PackageName)" "SUCCESS"
                } catch {
                    Write-Log "Failed to remove provisioned $($pkg.PackageName): $_" "WARN"
                }
            }
        }
    }

    if (-not $found) {
        Write-Log "Not found (already removed or not installed): $AppName" "SKIP"
        $SkippedApps.Add($AppName) | Out-Null
    }
}

# ==============================================================================
# HELPER: Registry Operations
# ==============================================================================

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$Description = ""
    )

    if ($DryRun) {
        Write-Log "[DRY] Would set registry: $Path\$Name = $Value ($Description)" "DRY"
        return
    }

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Log "Registry set: $Name = $Value$(if ($Description) {" [$Description]"})" "SUCCESS"
    } catch {
        Write-Log "Failed to set registry $Path\$Name: $_" "ERROR"
        $Errors.Add("Registry $Path\$Name: $_") | Out-Null
    }
}

# ==============================================================================
# SECTION 1: CORE BLOATWARE REMOVAL
# ==============================================================================

Write-Section "SECTION 1: CORE BLOATWARE REMOVAL"

# Xbox Apps
if ($Config.RemoveXboxApps) {
    Remove-BloatApp "Xbox Apps (Game Bar, App, etc.)" @(
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.Xbox.TCUI"
    )
}

# Cortana
if ($Config.RemoveCortana) {
    Remove-BloatApp "Cortana" @("Microsoft.549981C3F5F10")
}

# Microsoft Teams (Consumer)
if ($Config.RemoveTeamsConsumer) {
    Remove-BloatApp "Microsoft Teams (Consumer)" @(
        "MicrosoftTeams",
        "MSTeams"
    )
    # Also remove the Chat icon from taskbar via registry
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "TaskbarMn" -Value 0 `
        -Description "Hide Teams Chat taskbar icon"
}

# Clipchamp
if ($Config.RemoveClipchamp) {
    Remove-BloatApp "Clipchamp" @("Clipchamp.Clipchamp")
}

# MSN News
if ($Config.RemoveNewsAndInterests) {
    Remove-BloatApp "News (MSN)" @("Microsoft.BingNews")
}

# MSN Weather
if ($Config.RemoveWeather) {
    Remove-BloatApp "Weather (MSN)" @("Microsoft.BingWeather")
}

# Get Help
if ($Config.RemoveGetHelp) {
    Remove-BloatApp "Get Help / Contact Support" @("Microsoft.GetHelp")
}

# Feedback Hub
if ($Config.RemoveFeedbackHub) {
    Remove-BloatApp "Feedback Hub" @("Microsoft.WindowsFeedbackHub")
}

# Maps
if ($Config.RemoveMaps) {
    Remove-BloatApp "Windows Maps" @("Microsoft.WindowsMaps")
}

# Groove Music (Zune Music)
if ($Config.RemoveZuneMusic) {
    Remove-BloatApp "Groove Music (Zune Music)" @("Microsoft.ZuneMusic")
}

# Movies & TV (Zune Video)
if ($Config.RemoveZuneVideo) {
    Remove-BloatApp "Movies & TV (Zune Video)" @("Microsoft.ZuneVideo")
}

# Solitaire Collection
if ($Config.RemoveSolitaireCollection) {
    Remove-BloatApp "Microsoft Solitaire Collection" @("Microsoft.MicrosoftSolitaireCollection")
}

# Mixed Reality Portal
if ($Config.RemoveMixedReality) {
    Remove-BloatApp "Mixed Reality Portal" @("Microsoft.MixedReality.Portal")
}

# Paint 3D
if ($Config.RemovePaint3D) {
    Remove-BloatApp "Paint 3D" @("Microsoft.MSPaint")
    # NOTE: Classic mspaint.exe (Paint) is a system component and is NOT removed
}

# Skype
if ($Config.RemoveSkype) {
    Remove-BloatApp "Skype" @("Microsoft.SkypeApp")
}

# Power Automate Desktop
if ($Config.RemovePowerAutomate) {
    Remove-BloatApp "Power Automate Desktop" @("Microsoft.PowerAutomateDesktop")
}

# Microsoft To Do
if ($Config.RemoveToDo) {
    Remove-BloatApp "Microsoft To Do" @("Microsoft.Todos")
}

# Phone Link (Your Phone)
if ($Config.RemoveYourPhone) {
    Remove-BloatApp "Phone Link (Your Phone)" @("Microsoft.YourPhone")
}

# Bing apps
if ($Config.RemoveBingSearch) {
    Remove-BloatApp "Bing Finance / Sports" @(
        "Microsoft.BingFinance",
        "Microsoft.BingSports"
    )
}

# Mobile Plans
if ($Config.RemoveOneConnect) {
    Remove-BloatApp "Mobile Plans (OneConnect)" @("Microsoft.OneConnect")
}

# People
if ($Config.RemovePeople) {
    Remove-BloatApp "People" @("Microsoft.People")
}

# Alarms & Clock
if ($Config.RemoveAlarms) {
    Remove-BloatApp "Alarms & Clock" @("Microsoft.WindowsAlarms")
}

# Print 3D
if ($Config.RemovePrint3D) {
    Remove-BloatApp "Print 3D" @("Microsoft.Print3D")
}

# Sticky Notes (optional, default: keep)
if ($Config.RemoveStickyNotes) {
    Remove-BloatApp "Sticky Notes" @("Microsoft.MicrosoftStickyNotes")
}

# ==============================================================================
# SECTION 2: OPTIONAL / RISKY REMOVALS
# ==============================================================================

Write-Section "SECTION 2: OPTIONAL REMOVALS (Widgets, Copilot, Edge, OneDrive)"

# Widgets
if ($Config.RemoveWidgets) {
    Remove-BloatApp "Windows Widgets" @("MicrosoftWindows.Client.WebExperience")
    # Also hide the Widgets button from taskbar
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "TaskbarDa" -Value 0 `
        -Description "Hide Widgets taskbar button"
}

# Windows Copilot
if ($Config.RemoveCopilot) {
    Remove-BloatApp "Windows Copilot" @(
        "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.Copilot"
    )
    Set-RegistryValue `
        -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" `
        -Name "TurnOffWindowsCopilot" -Value 1 `
        -Description "Disable Copilot via policy"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" `
        -Name "TurnOffWindowsCopilot" -Value 1 `
        -Description "Disable Copilot via policy (system-wide)"
    # Hide Copilot button from taskbar
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "ShowCopilotButton" -Value 0 `
        -Description "Hide Copilot taskbar button"
}

# Windows Recall (AI screenshot feature — privacy risk)
if ($Config.RemoveRecall) {
    Write-Log "Attempting to remove/disable Windows Recall..." "ACTION"
    $recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
    if ($recallFeature -and $recallFeature.State -eq "Enabled") {
        if ($DryRun) {
            Write-Log "[DRY] Would disable Windows Recall optional feature." "DRY"
        } else {
            try {
                Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction Stop | Out-Null
                Write-Log "Windows Recall optional feature disabled." "SUCCESS"
            } catch {
                Write-Log "Could not disable Recall via optional features: $_" "WARN"
            }
        }
    } else {
        Write-Log "Windows Recall feature not found or already disabled." "SKIP"
    }
    # Also set registry policy to disable Recall
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" `
        -Name "DisableAIDataAnalysis" -Value 1 `
        -Description "Disable Windows Recall AI data analysis"
}

# OneDrive
if ($Config.RemoveOneDrive) {
    Write-Section "OneDrive Removal"
    Write-Log "WARNING: Removing OneDrive. Your files remain in the cloud. This removes the sync client." "WARN"

    if (-not $DryRun) {
        # Stop OneDrive
        Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue

        # Uninstall via built-in uninstaller
        $odPaths = @(
            "$env:SystemRoot\System32\OneDriveSetup.exe",
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
            "$env:LocalAppData\Microsoft\OneDrive\OneDriveSetup.exe"
        )
        $uninstalled = $false
        foreach ($path in $odPaths) {
            if (Test-Path $path) {
                try {
                    Start-Process $path "/uninstall" -Wait -ErrorAction Stop
                    Write-Log "OneDrive uninstalled via: $path" "SUCCESS"
                    $uninstalled = $true
                    break
                } catch {
                    Write-Log "Uninstall attempt failed at $path: $_" "WARN"
                }
            }
        }
        if (-not $uninstalled) {
            Write-Log "OneDrive uninstaller not found. Attempting via winget..." "WARN"
            winget uninstall "Microsoft.OneDrive" --silent 2>&1 | ForEach-Object { Write-Log $_ "INFO" }
        }

        # Remove leftover folders
        @(
            "$env:UserProfile\OneDrive",
            "$env:LocalAppData\Microsoft\OneDrive",
            "$env:ProgramData\Microsoft OneDrive"
        ) | ForEach-Object {
            if (Test-Path $_) {
                try {
                    Remove-Item $_ -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed OneDrive folder: $_" "SUCCESS"
                } catch {
                    Write-Log "Could not remove folder $_ (may be in use): $_" "WARN"
                }
            }
        }

        # Remove OneDrive from Explorer sidebar
        Set-RegistryValue `
            -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" `
            -Name "System.IsPinnedToNameSpaceTree" -Value 0 `
            -Description "Remove OneDrive from Explorer sidebar"

        $RemovedApps.Add("OneDrive") | Out-Null
    } else {
        Write-Log "[DRY] Would stop and uninstall OneDrive, and clean up leftover folders." "DRY"
    }
}

# Microsoft Edge
if ($Config.RemoveMicrosoftEdge) {
    Write-Log "WARNING: Edge removal is experimental and may affect Windows Update and some system features." "WARN"
    $confirm = "y"
    if (-not $DryRun) {
        $confirm = Read-Host "Are you SURE you want to remove Microsoft Edge? (y/N)"
    }
    if ($confirm -match '^[Yy]' -or $DryRun) {
        if ($DryRun) {
            Write-Log "[DRY] Would attempt to remove Microsoft Edge via winget." "DRY"
        } else {
            try {
                $edgeUninstaller = Get-ChildItem `
                    "C:\Program Files (x86)\Microsoft\Edge\Application" `
                    -Recurse -Filter "setup.exe" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($edgeUninstaller) {
                    Start-Process $edgeUninstaller.FullName `
                        "--uninstall --system-level --verbose-logging --force-uninstall" `
                        -Wait
                    Write-Log "Microsoft Edge removal attempted." "SUCCESS"
                } else {
                    Write-Log "Edge setup.exe not found. Cannot uninstall Edge this way." "WARN"
                }
            } catch {
                Write-Log "Edge removal failed: $_" "ERROR"
            }
        }
    } else {
        Write-Log "Edge removal cancelled by user." "SKIP"
    }
}

# ==============================================================================
# SECTION 3: PRIVACY & TELEMETRY
# ==============================================================================

Write-Section "SECTION 3: PRIVACY & TELEMETRY"

if ($Config.DisableTelemetry) {
    Write-Log "Disabling telemetry and diagnostic data..." "ACTION"

    # Set telemetry level to Security (0) — only available on Enterprise/Education
    # On Home/Pro, minimum is Basic (1); setting 0 is silently upgraded to 1
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
        -Name "AllowTelemetry" -Value 0 `
        -Description "Disable telemetry (Security level)"

    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" `
        -Name "AllowTelemetry" -Value 0 `
        -Description "Disable telemetry (alternate key)"

    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" `
        -Name "AllowTelemetry" -Value 0 `
        -Description "Disable telemetry (WOW64)"

    # Disable DiagTrack (Connected User Experiences and Telemetry) service
    if (-not $DryRun) {
        try {
            Stop-Service "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service  "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "DiagTrack service disabled." "SUCCESS"
        } catch {
            Write-Log "Could not disable DiagTrack: $_" "WARN"
        }
    } else {
        Write-Log "[DRY] Would disable DiagTrack service." "DRY"
    }

    # Disable dmwappushservice (WAP Push Message Routing)
    if (-not $DryRun) {
        try {
            Stop-Service "dmwappushservice" -Force -ErrorAction SilentlyContinue
            Set-Service  "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "dmwappushservice disabled." "SUCCESS"
        } catch {
            Write-Log "Could not disable dmwappushservice: $_" "WARN"
        }
    } else {
        Write-Log "[DRY] Would disable dmwappushservice." "DRY"
    }

    # Disable Customer Experience Improvement Program
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" `
        -Name "CEIPEnable" -Value 0 `
        -Description "Disable CEIP"

    # Disable error reporting
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" `
        -Name "Disabled" -Value 1 `
        -Description "Disable Windows Error Reporting"
}

if ($Config.DisableAdvertisingId) {
    Write-Log "Disabling Advertising ID..." "ACTION"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
        -Name "Enabled" -Value 0 `
        -Description "Disable Advertising ID"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" `
        -Name "DisabledByGroupPolicy" -Value 1 `
        -Description "Disable Advertising ID via policy"
}

if ($Config.DisableActivityHistory) {
    Write-Log "Disabling Activity History / Timeline..." "ACTION"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
        -Name "EnableActivityFeed" -Value 0 `
        -Description "Disable Activity Feed"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
        -Name "PublishUserActivities" -Value 0 `
        -Description "Disable publishing user activities"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
        -Name "UploadUserActivities" -Value 0 `
        -Description "Disable uploading user activities"
}

if ($Config.DisableLocationTracking) {
    Write-Log "Disabling Location Tracking..." "ACTION"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" `
        -Name "Value" -Value "Deny" -Type "String" `
        -Description "Deny location access system-wide"
}

# ==============================================================================
# SECTION 4: PERFORMANCE & UI OPTIMIZATIONS
# ==============================================================================

Write-Section "SECTION 4: PERFORMANCE & UI OPTIMIZATIONS"

if ($Config.DisableBackgroundApps) {
    Write-Log "Disabling background app execution for Store apps..." "ACTION"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" `
        -Name "GlobalUserDisabled" -Value 1 `
        -Description "Disable all background Store apps (user)"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" `
        -Name "LetAppsRunInBackground" -Value 2 `
        -Description "Force background apps off via policy"
}

if ($Config.DisableWindowsTips) {
    Write-Log "Disabling Windows tips and suggestions..." "ACTION"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SubscribedContent-338389Enabled" -Value 0 `
        -Description "Disable 'Tips about Windows' notifications"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SubscribedContent-338388Enabled" -Value 0 `
        -Description "Disable Start menu suggestions"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SubscribedContent-353696Enabled" -Value 0 `
        -Description "Disable suggested apps in Start"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SystemPaneSuggestionsEnabled" -Value 0 `
        -Description "Disable app suggestions in Start menu"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SoftLandingEnabled" -Value 0 `
        -Description "Disable Start menu soft landing suggestions"
    # Disable lock screen tips/spotlight
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "RotatingLockScreenEnabled" -Value 0 `
        -Description "Disable Windows Spotlight on lock screen"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SubscribedContent-338393Enabled" -Value 0 `
        -Description "Disable Spotlight tips"
}

if ($Config.DisableConsumerFeatures) {
    Write-Log "Disabling consumer features (auto-app installs, promoted apps)..." "ACTION"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" `
        -Name "DisableWindowsConsumerFeatures" -Value 1 `
        -Description "Disable automatic installation of promoted Store apps"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "ContentDeliveryAllowed" -Value 0 `
        -Description "Disable content delivery manager"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "OemPreInstalledAppsEnabled" -Value 0 `
        -Description "Disable OEM pre-installed apps auto-install"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "PreInstalledAppsEnabled" -Value 0 `
        -Description "Disable pre-installed apps auto-install"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" `
        -Name "SilentInstalledAppsEnabled" -Value 0 `
        -Description "Disable silent app installs"
}

if ($Config.DisableCortanaSearch) {
    Write-Log "Disabling Cortana in Windows Search..." "ACTION"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" `
        -Name "AllowCortana" -Value 0 `
        -Description "Disable Cortana in search"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" `
        -Name "AllowCortanaAboveLock" -Value 0 `
        -Description "Disable Cortana above lock screen"
}

if ($Config.DisableWebSearch) {
    Write-Log "Disabling Bing web results in Start Menu search..." "ACTION"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
        -Name "BingSearchEnabled" -Value 0 `
        -Description "Disable Bing in Start search"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
        -Name "CortanaConsent" -Value 0 `
        -Description "Remove Cortana consent"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" `
        -Name "DisableWebSearch" -Value 1 `
        -Description "Disable web search in Search"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" `
        -Name "ConnectedSearchUseWeb" -Value 0 `
        -Description "Disable connected search web usage"
}

if ($Config.DisableGameBar) {
    Write-Log "Disabling Xbox Game Bar..." "ACTION"
    Set-RegistryValue `
        -Path "HKCU:\System\GameConfigStore" `
        -Name "GameDVR_Enabled" -Value 0 `
        -Description "Disable Game DVR"
    Set-RegistryValue `
        -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" `
        -Name "AllowGameDVR" -Value 0 `
        -Description "Disable Game DVR via policy"
    Set-RegistryValue `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" `
        -Name "AppCaptureEnabled" -Value 0 `
        -Description "Disable app capture"
}

# ==============================================================================
# SECTION 5: STARTUP APPS (Optional, aggressive)
# ==============================================================================

Write-Section "SECTION 5: STARTUP APPLICATIONS"

if ($Config.DisableStartupApps) {
    Write-Log "WARNING: Disabling all non-essential startup applications..." "WARN"
    # Safe list — these startup entries are system-critical and must NOT be disabled
    $safeStartupItems = @(
        "SecurityHealth",       # Windows Security / Defender
        "Windows Defender",
        "WindowsDefender",
        "MsMpEng",
        "OneDrive"              # Only kept if user opted to keep OneDrive
    )

    if ($DryRun) {
        Write-Log "[DRY] Would review and disable non-essential startup apps." "DRY"
    } else {
        $startupKeys = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        )
        foreach ($key in $startupKeys) {
            if (Test-Path $key) {
                $entries = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
                $entries.PSObject.Properties |
                    Where-Object { $_.Name -notin @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider") } |
                    ForEach-Object {
                        $skip = $false
                        foreach ($safe in $safeStartupItems) {
                            if ($_.Name -like "*$safe*") { $skip = $true; break }
                        }
                        if (-not $skip) {
                            try {
                                Remove-ItemProperty -Path $key -Name $_.Name -Force -ErrorAction Stop
                                Write-Log "Removed startup entry: $($_.Name)" "SUCCESS"
                            } catch {
                                Write-Log "Could not remove startup entry $($_.Name): $_" "WARN"
                            }
                        } else {
                            Write-Log "Kept safe startup entry: $($_.Name)" "SKIP"
                        }
                    }
            }
        }
    }
} else {
    Write-Log "Startup app cleanup skipped (DisableStartupApps = false)." "SKIP"
}

# ==============================================================================
# SECTION 6: GENERATE RESTORE SCRIPT
# ==============================================================================

Write-Section "SECTION 6: GENERATING RESTORE SCRIPT"

$restoreContent = @"
#Requires -Version 5.1
<#
.SYNOPSIS
    Restore script — reinstalls apps removed by Win11 Debloat Script v$ScriptVersion
.DESCRIPTION
    Run this script from an elevated PowerShell prompt to reinstall
    the apps that were removed. Internet connection required.
.NOTES
    Generated: $($ScriptStart.ToString("yyyy-MM-dd HH:mm:ss"))
    Original log: $LogPath
#>

# --- Apps removed by debloat script ---
# The following apps can be reinstalled via the Microsoft Store
# or via winget. Run this script in an elevated PowerShell window.

Write-Host "Reinstalling removed Windows 11 apps..." -ForegroundColor Cyan

`$appsToRestore = @(
$(($RemovedApps | Sort-Object -Unique | ForEach-Object { "    `"$_`"" }) -join "`n")
)

`$wingetAppIds = @{
    "Xbox Apps (Game Bar, etc.)"    = "Microsoft.GamingApp"
    "Cortana"                        = "9NFFX4SZZ23L"
    "Microsoft Teams (Consumer)"     = "Microsoft.Teams"
    "Clipchamp"                      = "Clipchamp.Clipchamp"
    "News (MSN)"                     = "Microsoft.BingNews"
    "Weather (MSN)"                  = "Microsoft.BingWeather"
    "Windows Maps"                   = "Microsoft.WindowsMaps"
    "Groove Music (Zune Music)"      = "Microsoft.ZuneMusic"
    "Movies & TV (Zune Video)"       = "Microsoft.ZuneVideo"
    "Microsoft Solitaire Collection" = "Microsoft.MicrosoftSolitaireCollection"
    "Skype"                          = "Microsoft.Skype"
    "Microsoft To Do"                = "Microsoft.Todos"
    "Phone Link (Your Phone)"        = "Microsoft.YourPhone"
    "People"                         = "Microsoft.People"
    "Windows Widgets"                = "MicrosoftWindows.Client.WebExperience"
    "OneDrive"                       = "Microsoft.OneDrive"
}

foreach (`$app in `$appsToRestore) {
    if (`$wingetAppIds.ContainsKey(`$app)) {
        `$id = `$wingetAppIds[`$app]
        Write-Host "Installing: `$app (`$id)..." -ForegroundColor Yellow
        winget install --id `$id --accept-source-agreements --accept-package-agreements
    } else {
        Write-Host "Please reinstall manually from Microsoft Store: `$app" -ForegroundColor Gray
    }
}

Write-Host "`nRestore complete. A reboot is recommended." -ForegroundColor Green
"@

if (-not $DryRun) {
    try {
        Set-Content -Path $RestoreScript -Value $restoreContent -Encoding UTF8
        Write-Log "Restore script generated: $RestoreScript" "SUCCESS"
    } catch {
        Write-Log "Could not write restore script: $_" "WARN"
    }
} else {
    Write-Log "[DRY] Would generate restore script at: $RestoreScript" "DRY"
}

# ==============================================================================
# SUMMARY REPORT
# ==============================================================================

Write-Section "SUMMARY REPORT"

$duration = (Get-Date) - $ScriptStart
$uniqueRemoved  = ($RemovedApps | Sort-Object -Unique)
$uniqueSkipped  = ($SkippedApps | Sort-Object -Unique)

Write-Log "Script completed in $([math]::Round($duration.TotalSeconds,1)) seconds." "INFO"
Write-Log "" "INFO"
Write-Log "Mode        : $(if ($DryRun) { 'DRY RUN (no changes made)' } else { 'LIVE' })" "INFO"
Write-Log "Apps Removed: $($uniqueRemoved.Count)" "INFO"
Write-Log "Apps Skipped: $($uniqueSkipped.Count) (not installed / already removed)" "INFO"
Write-Log "Errors      : $($Errors.Count)" "INFO"
Write-Log "" "INFO"

if ($uniqueRemoved.Count -gt 0) {
    Write-Log "--- Removed Apps ---" "SUCCESS"
    $uniqueRemoved | ForEach-Object { Write-Log "  [+] $_" "SUCCESS" }
}

if ($Errors.Count -gt 0) {
    Write-Log "" "INFO"
    Write-Log "--- Errors Encountered ---" "ERROR"
    $Errors | ForEach-Object { Write-Log "  [-] $_" "ERROR" }
}

Write-Log "" "INFO"
Write-Log "Log file    : $LogPath" "INFO"

if (-not $DryRun) {
    Write-Log "Restore     : $RestoreScript" "INFO"
    Write-Log "" "INFO"
    Write-Log "A REBOOT is recommended to complete all changes." "WARN"
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host "  Windows 11 Debloat complete!" -ForegroundColor Green
if ($DryRun) {
    Write-Host "  DRY RUN — No changes were made. Remove -DryRun to apply." -ForegroundColor Blue
} else {
    Write-Host "  Please REBOOT your PC to finalise all changes." -ForegroundColor Yellow
    Write-Host "  Restore script saved to: $RestoreScript" -ForegroundColor Cyan
}
Write-Host ("=" * 70) -ForegroundColor Green
Write-Host ""
