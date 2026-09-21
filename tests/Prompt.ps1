#requires -Version 7.2
param(
    [string]$ProfilePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'profile.ps1')
)
$ErrorActionPreference = 'Stop'
if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
    throw 'Run this test in an interactive terminal: pwsh -NoProfile -File ./tests/Prompt.ps1'
}

# Run in a disposable child shell, not by dot-sourcing in your current session.
foreach ($attempt in 1..3) {
    . $ProfilePath
    if (-not $global:_ompTransientPrompt) {
        throw "Transient prompt disabled after profile load $attempt."
    }
    if (@(Get-Module -Name oh-my-posh-core).Count -ne 1) {
        throw "Expected exactly one Oh My Posh module after profile load $attempt."
    }
    $expectedHandlers = @{
        Enter = 'OhMyPoshEnterKeyHandler'
        'Ctrl+c' = 'OhMyPoshCtrlCKeyHandler'
        F1 = 'ShowKeyBindings'
        'Ctrl+Alt+k' = 'WhatIsKey'
    }
    foreach ($chord in $expectedHandlers.Keys) {
        if ((Get-PSReadLineKeyHandler -Chord $chord).Function -ne $expectedHandlers[$chord]) {
            throw "Unexpected $chord binding after profile load $attempt."
        }
    }
}
Write-Host 'PASS: transient enabled, single prompt module, key handlers preserved across three profile loads.'
