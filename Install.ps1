#requires -Version 7.2
[CmdletBinding()]
param(
    [switch]$SkipDependencies,
    [string]$ConfigHome = (Join-Path $env:USERPROFILE '.config/ps-config'),
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$TerminalSettingsPath
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This installer targets Windows and PowerShell 7.' }
$config = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json

if (-not $TerminalSettingsPath) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft/Windows Terminal/settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json')
    )
    $TerminalSettingsPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $TerminalSettingsPath) { throw 'Open Windows Terminal once, then retry or pass -TerminalSettingsPath.' }
}
# Parse before any changes. PowerShell 7 accepts Terminal JSON comments/trailing commas.
$terminal = Get-Content -LiteralPath $TerminalSettingsPath -Raw | ConvertFrom-Json -AsHashtable
if (-not $terminal.profiles) { $terminal.profiles = @{} }
if (-not $terminal.profiles.defaults) { $terminal.profiles.defaults = @{} }
if (-not $terminal.profiles.defaults.font) { $terminal.profiles.defaults.font = @{} }
$terminal.profiles.defaults.font.face = $config.fontFace
$terminal.profiles.defaults.font.weight = $config.fontWeight
$terminal.profiles.defaults.colorScheme = $config.colorScheme
$pwshProfile = @($terminal.profiles.list | Where-Object {
    $_.source -eq 'Windows.Terminal.PowershellCore' -or $_.commandline -match '(?i)\bpwsh(?:\.exe)?\b'
})
if ($pwshProfile.Count -eq 0) {
    $newProfile = @{
        guid = '{e9076836-695b-4b1b-a6c2-239415b2fd07}'
        name = 'PowerShell 7'
        commandline = 'pwsh.exe'
        hidden = $false
    }
    $terminal.profiles.list = @($terminal.profiles.list) + @($newProfile)
    $pwshProfile = @($newProfile)
}
foreach ($entry in $pwshProfile) {
    # Inherit shared appearance instead of keeping a second copy per profile.
    if ($entry.font) {
        $entry.font.Remove('face')
        $entry.font.Remove('weight')
        if ($entry.font.Count -eq 0) { $entry.Remove('font') }
    }
    foreach ($key in @('colorScheme', 'background', 'foreground', 'selectionBackground', 'cursorColor')) {
        $entry.Remove($key)
    }
}
$terminal.defaultProfile = $pwshProfile[0].guid

if (-not $SkipDependencies) { & (Join-Path $PSScriptRoot 'scripts/Install-Dependencies.ps1') }
New-Item -ItemType Directory -Path $ConfigHome -Force | Out-Null
$backupDir = Join-Path $ConfigHome ('backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $TerminalSettingsPath -Destination (Join-Path $backupDir 'terminal.settings.json')
if (Test-Path -LiteralPath $ProfilePath) {
    Copy-Item -LiteralPath $ProfilePath -Destination (Join-Path $backupDir 'profile.ps1')
}
foreach ($file in @('profile.ps1', 'functions.ps1', 'config.json')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $ConfigHome $file) -Force
}
$themesDir = Join-Path $ConfigHome 'themes'
New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'themes') -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $themesDir $_.Name) -Force
}
$start = '# >>> ps-config >>>'
$end = '# <<< ps-config <<<'
$installedProfile = (Join-Path $ConfigHome 'profile.ps1').Replace("'", "''")
$loader = "$start`r`n. '$installedProfile'`r`n$end"
$existing = if (Test-Path -LiteralPath $ProfilePath) { Get-Content -LiteralPath $ProfilePath -Raw } else { '' }
$pattern = '(?ms)^' + [regex]::Escape($start) + '\r?\n.*?^' + [regex]::Escape($end)
if ($existing -match $pattern) {
    $profileText = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $loader })
} else {
    $profileText = $existing.TrimEnd() + "`r`n" + $loader + "`r`n"
}
New-Item -ItemType Directory -Path (Split-Path -Parent $ProfilePath) -Force | Out-Null
Set-Content -LiteralPath $ProfilePath -Value $profileText -Encoding utf8 -NoNewline
$terminal | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $TerminalSettingsPath -Encoding utf8
Write-Host "Profile: $ProfilePath"
Write-Host "Backup:  $backupDir"
Write-Host 'Restart Windows Terminal to load the font and profile.'
