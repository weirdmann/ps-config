#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' | Where-Object FullName -NotMatch '[\\/]\.local[\\/]' | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Assert ($errors.Count -eq 0) "Syntax error in $($_.FullName): $errors"
}
$testRoot = Join-Path $root ('.local/test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$testProfile = Join-Path $testRoot 'Microsoft.PowerShell_profile.ps1'
$testTerminal = Join-Path $testRoot 'settings.json'
Set-Content $testProfile '# existing custom profile'
$original = @{
    copyOnSelect = $true
    profiles = @{
        defaults = @{ font = @{ size = 15 }; opacity = 80 }
        list = @(
            @{ guid = '{test-pwsh}'; source = 'Windows.Terminal.PowershellCore'; background = '#112233'; colorScheme = 'Other'; font = @{ size = 12; face = 'Old'; weight = 400 } },
            @{ guid = '{test-cmd}'; name = 'CMD'; colorScheme = 'Other' },
            @{ guid = '{test-pwsh-empty-font}'; commandline = 'pwsh.exe'; font = @{ face = 'Old'; weight = 400 } }
        )
    }
}
$original | ConvertTo-Json -Depth 10 | Set-Content $testTerminal
$argsForInstall = @{
    SkipDependencies = $true
    ConfigHome = (Join-Path $testRoot 'installed')
    ProfilePath = $testProfile
    TerminalSettingsPath = $testTerminal
}
& (Join-Path $root 'Install.ps1') @argsForInstall
$firstProfile = Get-Content $testProfile -Raw
$firstTerminal = Get-Content $testTerminal -Raw
& (Join-Path $root 'Install.ps1') @argsForInstall
Assert ((Get-Content $testProfile -Raw) -eq $firstProfile) 'Profile install is not idempotent.'
Assert ((Get-Content $testTerminal -Raw) -eq $firstTerminal) 'Terminal install is not idempotent.'
Assert ($firstProfile.Contains('# existing custom profile')) 'Existing profile lost.'
$updated = $firstTerminal | ConvertFrom-Json -AsHashtable
Assert ($updated.copyOnSelect -and $updated.profiles.defaults.opacity -eq 80) 'Unrelated settings changed.'
Assert ($updated.profiles.list[1].colorScheme -eq 'Other') 'Other profile changed.'
Assert ($updated.profiles.list[0].font.size -eq 12) 'Existing font size changed.'
Assert ($updated.profiles.defaults.font.face -eq 'AtkynsonMono NF') 'Wrong default font.'
Assert ($updated.profiles.defaults.font.weight -eq 600) 'Wrong default font weight.'
Assert ($updated.profiles.defaults.colorScheme -eq 'Campbell') 'Wrong default palette.'
Assert (-not $updated.profiles.list[0].font.Contains('face')) 'Redundant font override remains.'
Assert (-not $updated.profiles.list[0].font.Contains('weight')) 'Redundant font weight remains.'
Assert (-not $updated.profiles.list[0].Contains('colorScheme')) 'Redundant palette override remains.'
Assert (-not $updated.profiles.list[0].Contains('background')) 'Color override remains.'
Assert (-not $updated.profiles.list[2].Contains('font')) 'Empty font override remains.'
Assert (@(Get-ChildItem (Join-Path $testRoot 'installed/backups') -Directory).Count -eq 2) 'Backups missing.'
. (Join-Path $root 'functions.ps1')
$script:gitCalls = [Collections.Generic.List[string]]::new()
function git {
    $script:gitCalls.Add($args[0])
    $global:LASTEXITCODE = if ($args[0] -eq 'commit') { 1 } else { 0 }
}
$failed = $false
try { lazyg 'test failure' } catch { $failed = $true }
Assert $failed 'Failed commit did not throw.'
Assert (-not $script:gitCalls.Contains('push')) 'Push ran after failed commit.'
Remove-Item Function:\git
Assert ([bool](whichdir git)) 'whichdir git failed.'
$script:zoxideCalls = 0
function zoxide { $script:zoxideCalls++; $global:LASTEXITCODE = 0 }
$global:PsConfigLastDirectory = $null
$global:LASTEXITCODE = 17
Update-PsConfigDirectory
Assert ($global:LASTEXITCODE -eq 17) 'Directory hook lost the command exit code.'
Update-PsConfigDirectory
Assert ($script:zoxideCalls -eq 1) 'Directory hook records unchanged locations repeatedly.'
Remove-Item Function:\zoxide
Remove-Variable PsConfigLastDirectory -Scope Global
$global:LASTEXITCODE = 0
Write-Host 'PASS: syntax, idempotence, backups, settings preservation, Git failure handling, directory hook.'
