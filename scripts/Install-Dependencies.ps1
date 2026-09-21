#requires -Version 7.2
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$config = Get-Content (Join-Path $PSScriptRoot '../config.json') -Raw | ConvertFrom-Json
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$scoop = Join-Path $scoopRoot 'shims/scoop.ps1'
if (-not (Test-Path -LiteralPath $scoop)) {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $scoop = (Get-Command scoop).Source
    } else {
        if ((Get-ExecutionPolicy) -notin @('RemoteSigned', 'Unrestricted', 'Bypass')) {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        }
        $installer = Join-Path ([IO.Path]::GetTempPath()) ('ps-config-scoop-' + [guid]::NewGuid() + '.ps1')
        Invoke-WebRequest 'https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1' -OutFile $installer
        & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $installer
        if ($LASTEXITCODE -ne 0) { throw 'Scoop installation failed.' }
        if (-not (Test-Path -LiteralPath $scoop)) { throw 'Scoop shim was not created.' }
    }
}
$env:PATH = (Join-Path $scoopRoot 'shims') + ';' + $env:PATH

function Invoke-Scoop {
    param([string[]]$Arguments)
    & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $scoop @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Scoop failed: $($Arguments -join ' ')" }
}
if (-not (Test-Path (Join-Path $scoopRoot 'buckets/nerd-fonts'))) {
    Invoke-Scoop -Arguments @('bucket', 'add', 'nerd-fonts', 'https://github.com/matthewjberger/scoop-nerd-fonts')
}
foreach ($package in @('oh-my-posh', $config.fontPackage)) {
    if (-not (Test-Path (Join-Path $scoopRoot "apps/$package/current"))) {
        Invoke-Scoop -Arguments @('install', $package)
    }
    if (-not (Test-Path (Join-Path $scoopRoot "apps/$package/current"))) {
        throw "Package $package was not installed."
    }
}
# Avoid changing the trust policy for the entire PowerShell Gallery.
foreach ($module in @('PSReadLine', 'Terminal-Icons')) {
    Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
}
Write-Host 'Dependencies installed for the current user.'
