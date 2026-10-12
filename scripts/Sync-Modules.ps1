#requires -Version 7.2
[CmdletBinding()]
param([string]$ConfigHome = (Join-Path $env:USERPROFILE '.config/ps-config'))
$ErrorActionPreference = 'Stop'
$moduleRoot = Join-Path $ConfigHome 'modules'
New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
$index = [ordered]@{}
# Wyszukiwanie wersji odbywa się przy instalacji/aktualizacji, nie przy każdym starcie.
$available = @(Get-Module -ListAvailable -Name PSReadLine, Terminal-Icons, posh-git, PSFzf)
foreach ($name in @('PSReadLine', 'Terminal-Icons', 'posh-git', 'PSFzf')) {
    $module = $available | Where-Object Name -EQ $name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) { continue }
    $versionRoot = Join-Path $moduleRoot "$name/$($module.Version)"
    New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
    if ([IO.Path]::GetFullPath($module.ModuleBase) -ne [IO.Path]::GetFullPath($versionRoot)) {
        Get-ChildItem -LiteralPath $module.ModuleBase -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $versionRoot -Recurse -Force
        }
    }
    $manifest = Join-Path $versionRoot "$name.psd1"
    if (-not (Test-Path -LiteralPath $manifest)) { throw "Manifest module $name not found: $manifest" }
    $index[$name] = "modules/$name/$($module.Version)/$name.psd1"
}
$index | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ConfigHome 'modules.json') -Encoding utf8

# Standardowy proxy zachowuje parametry, dynamiczne parametry i potoki cmdletu.
# Usuwa się przy pierwszym użyciu, zanim zaimportuje Terminal-Icons.
$metadata = [Management.Automation.CommandMetadata]::new((Get-Command Microsoft.PowerShell.Management\Get-ChildItem))
$proxy = [Management.Automation.ProxyCommand]::Create($metadata)
$proxy = $proxy -replace '(?m)^begin\s*\r?\n\{', @'
begin
{
    Remove-Item -LiteralPath Function:\Get-ChildItem -Force
    if (-not (Get-Module -Name Terminal-Icons)) {
        $null = Import-PsConfigModule -Name Terminal-Icons
    }
'@
"function global:Get-ChildItem {`n$proxy`n}" | Set-Content -LiteralPath (Join-Path $ConfigHome 'lazy-terminal-icons.ps1') -Encoding utf8
Write-Host "Local modules refreshed: $moduleRoot"
