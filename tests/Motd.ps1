#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'profile.ps1')
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Ten test jest skryptem (-File), więc prawdziwe MOTD ma pozostać niewidoczne.
Assert (-not (Test-PsConfigInteractiveSession)) 'Script session incorrectly recognized as interactive.'
$output = @(Show-Motd *>&1)
Assert ($output.Count -eq 0) 'MOTD produced output in a script session.'

if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    Assert (Test-PsConfigInteractiveSession -StartupArguments @('-NoLogo')) 'Normal terminal rejected.'
    Assert (Test-PsConfigInteractiveSession -StartupArguments @('-NoExit', '-Command', 'Get-Date')) 'Interactive startup command rejected.'
    Assert (Test-PsConfigInteractiveSession -StartupArguments @('-WorkingDirectory', 'C:\', '-ExecutionPolicy', 'RemoteSigned')) 'Startup option values mistaken for script.'
    foreach ($arguments in @(
        @('-NonInteractive'), @('-NonI', '-NoExit'), @('-NonInt'),
        @('-Command', 'Get-Date'), @('-c', 'Get-Date'), @('-EncodedCommand', 'AAAA'),
        @('-File', 'example.ps1'), @('example.ps1'), @('-File', 'example.ps1', '-NoExit')
    )) {
        Assert (-not (Test-PsConfigInteractiveSession -StartupArguments $arguments)) "Unsafe startup accepted: $arguments"
    }
}

# Przechwyć samą prezentację bez wypisywania powitania ani zmiany ustawień konsoli.
& {
    function Test-PsConfigInteractiveSession { $true }
    function Get-Date { [datetime]'2026-09-22' }
    # Stałe dane testowe niezależne od późniejszych zmian imienia i wyglądu.
    $global:PsConfigMotd.Name = 'Hubert'
    $global:PsConfigMotd.Stars = '⭐ 🌟 ✨ 🌠'
    $global:PsConfigMotd.DateFormat = 'dddd, d MMMM yyyy'
    $global:PsConfigMotd.LineCharacter = '─'
    $global:PsConfigMotd.Enabled = $true
    $lines = [Collections.Generic.List[string]]::new()
    function Write-Host {
        param($Object, $ForegroundColor)
        $lines.Add([string]$Object)
    }
    $exitCode = $global:LASTEXITCODE
    $culture = [Globalization.CultureInfo]::CurrentCulture.Name
    $encoding = [Console]::OutputEncoding.CodePage
    Show-Motd
    Assert ($lines[1] -ceq 'Cześć, Hubert!  ⭐ 🌟 ✨ 🌠') 'Unicode greeting corrupted.'
    Assert ($lines[2] -ceq 'Dzisiaj: wtorek, 22 września 2026') 'Polish date incorrect.'
    Assert ($lines[3] -ceq "Komputer: $([Environment]::MachineName)") 'Hostname incorrect.'
    $width = 0
    try { $width = [Console]::WindowWidth } catch { }
    if ($width -le 0) {
        try { $width = $Host.UI.RawUI.WindowSize.Width } catch { }
    }
    try {
        if ([Console]::BufferWidth -gt 0 -and $width -gt 0) { $width = [Math]::Min($width, [Console]::BufferWidth) }
    } catch { }
    if ($width -gt 1) {
        Assert ($lines[4].Length -eq $width - 1) 'Separator could wrap or has incorrect width.'
        Assert ($lines[4] -match '^─+$') 'Separator corrupted.'
    } else {
        Assert ($lines.Count -eq 4) 'Separator should be omitted when width is unavailable.'
    }
    Assert ($global:LASTEXITCODE -eq $exitCode) 'MOTD changed exit code.'
    Assert ([Globalization.CultureInfo]::CurrentCulture.Name -eq $culture) 'MOTD changed culture.'
    Assert ([Console]::OutputEncoding.CodePage -eq $encoding) 'MOTD changed output encoding.'
    $lines.Clear()
    $global:PsConfigMotd.Enabled = $false
    Show-Motd
    Assert ($lines.Count -eq 0) 'Disabled MOTD produced output.'
}
Write-Host 'PASS: MOTD Unicode, Polish date, hostname, separator width, disabled/silent mode, unchanged culture and encoding.'
