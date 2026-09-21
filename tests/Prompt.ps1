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
    $options = Get-PSReadLineOption
    if ($options.EditMode -ne 'Windows' -or $options.PredictionSource -ne 'History' -or $options.PredictionViewStyle -ne 'ListView') {
        throw "Unexpected PSReadLine options after profile load $attempt."
    }
    $expectedHandlers = @{
        Enter = 'OhMyPoshEnterKeyHandler'
        'Ctrl+c' = 'OhMyPoshCtrlCKeyHandler'
        F1 = 'ShowKeyBindings'
        'Ctrl+Alt+k' = 'WhatIsKey'
        UpArrow = 'HistorySearchBackward'
        DownArrow = 'HistorySearchForward'
    }
    foreach ($chord in $expectedHandlers.Keys) {
        if ((Get-PSReadLineKeyHandler -Chord $chord).Function -ne $expectedHandlers[$chord]) {
            throw "Unexpected $chord binding after profile load $attempt."
        }
    }
    if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module PSFzf)) {
        if ((Get-PSReadLineKeyHandler -Chord Tab).Function -ne 'FzfTabCompletion') {
            throw "Fzf Tab completion lost after profile load $attempt."
        }
    } elseif ((Get-PSReadLineKeyHandler -Chord Tab).Function -ne 'MenuComplete') {
        throw "Default Tab completion lost after profile load $attempt."
    }
    if ((Get-Command eza.exe -ErrorAction SilentlyContinue) -and (Get-Alias ls).Definition -ne 'Show-EzaList') {
        throw "Eza alias lost after profile load $attempt."
    }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        if ((Get-Alias Set-PoshContext).Definition -ne 'Update-PsConfigDirectory') {
            throw "Zoxide hook lost after profile load $attempt."
        }
    }
}
Write-Host 'PASS: transient, single prompt module, PSReadLine options, shortcuts, eza and zoxide across three profile loads.'
