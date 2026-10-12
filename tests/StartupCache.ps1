#requires -Version 7.2
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'functions.ps1')
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$fixture = Join-Path $root ('.local/cache-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fixture | Out-Null
$exe = Join-Path $fixture 'fake-posh.ps1'
$theme = Join-Path $fixture 'theme.json'
$cache = Join-Path $fixture 'cache'
@'
$global:PsConfigFakePoshCalls++
$global:LASTEXITCODE = 0
'$env:POSH_SESSION_ID = "fixed-session"; $global:PsConfigCacheFixture = $true'
'@ | Set-Content -LiteralPath $exe -Encoding utf8
$launcher = Join-Path $fixture 'launcher.ps1'
'& (Join-Path $PSScriptRoot "fake-posh.ps1") @args' | Set-Content -LiteralPath $launcher -Encoding utf8
('path = "' + $exe + '"') | Set-Content -LiteralPath ([IO.Path]::ChangeExtension($launcher, '.shim')) -Encoding utf8
'{"transient_prompt":{"template":"❯ "}}' | Set-Content -LiteralPath $theme -Encoding utf8
$global:PsConfigFakePoshCalls = 0
$first = Get-PsConfigPoshInit -Executable $launcher -ThemePath $theme -CacheDirectory $cache
$second = Get-PsConfigPoshInit -Executable $launcher -ThemePath $theme -CacheDirectory $cache
Assert ($global:PsConfigFakePoshCalls -eq 1) 'Cache hit reran init generation.'
Assert ($first -eq $second) 'Cached script differs from generated initialization.'
Invoke-Expression $first
$firstSession = $env:POSH_SESSION_ID
Invoke-Expression $second
Assert ($env:POSH_SESSION_ID -ne $firstSession) 'Cache reused a session identifier.'
'{"transient_prompt":{"template":"new ❯ "}}' | Set-Content -LiteralPath $theme -Encoding utf8
$null = Get-PsConfigPoshInit -Executable $launcher -ThemePath $theme -CacheDirectory $cache
Assert ($global:PsConfigFakePoshCalls -eq 2) 'Theme change did not invalidate cache.'
Add-Content -LiteralPath $exe -Value '# changed executable'
$null = Get-PsConfigPoshInit -Executable $launcher -ThemePath $theme -CacheDirectory $cache
Assert ($global:PsConfigFakePoshCalls -eq 3) 'Executable change did not invalidate cache.'
Write-Host 'PASS: init cache hit, theme and executable invalidation, unique session identifiers.'
