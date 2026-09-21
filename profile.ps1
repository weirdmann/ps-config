# PowerShell 7 user profile. Loaded from a local installed copy of ps-config.
$psConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'functions.ps1')

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# Redirected shells (CI, scripts, agents) do not have an interactive console.
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key F1 -Function ShowKeyBindings
    Set-PSReadLineKeyHandler -Key 'Ctrl+Alt+k' -Function WhatIsKey
    Set-Alias -Name keys -Value Show-PromptKeys -Scope Global -Force

    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    # An already-open terminal may not yet have Scoop's newly installed shims in PATH.
    $scoopShims = Join-Path $scoopRoot 'shims'
    if ((Test-Path -LiteralPath $scoopShims) -and ($env:PATH -split ';') -notcontains $scoopShims) {
        $env:PATH = $scoopShims + ';' + $env:PATH
    }
    if (Get-Command eza.exe -ErrorAction SilentlyContinue) {
        Set-Alias -Name ls -Value Show-EzaList -Scope Global -Force
        Set-Alias -Name la -Value Show-EzaDetails -Scope Global -Force
        Set-Alias -Name tr -Value Show-EzaTree -Scope Global -Force
    }
    if (Get-Command lazygit -ErrorAction SilentlyContinue) {
        Set-Alias -Name lg -Value lazygit -Scope Global -Force
    }
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        # Applies to Git launched in interactive PowerShell, not the global Git config.
        $env:GIT_PAGER = 'delta --paging=auto --line-numbers'
        $env:DELTA_PAGER = 'less -R'
    }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        $env:BAT_PAGER = 'less -R'
    }
    if (Get-Module -ListAvailable -Name posh-git) {
        Import-Module posh-git
    }
    if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable -Name PSFzf)) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -PSReadlineChordSetLocation 'Alt+c'
        Set-PSReadLineKeyHandler -Key Tab -BriefDescription 'FzfTabCompletion' -Description 'Wybierz uzupelnienie przez fzf' -ScriptBlock { Invoke-FzfTabCompletion }
    }

    $poshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if (-not $poshCommand) {
        $poshPath = Join-Path $scoopRoot 'apps/oh-my-posh/current/oh-my-posh.exe'
        if (Test-Path -LiteralPath $poshPath) { $poshCommand = Get-Command $poshPath }
    }
    $themeRoots = @((Join-Path $PSScriptRoot 'themes'), $env:POSH_THEMES_PATH, (Join-Path $scoopRoot 'apps/oh-my-posh/current/themes'))
    $themePath = $themeRoots | Where-Object { $_ } | ForEach-Object {
        Join-Path $_ ($psConfig.promptTheme + '.omp.json')
    } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($poshCommand -and $themePath) {
        # Clean up the old module before reloading the profile and its key handlers.
        Get-Module -Name oh-my-posh-core | Remove-Module -Force
        # Cached init scripts can retain feature flags from an older theme.
        # --print generates fresh initialization, including transient prompt support.
        & $poshCommand.Source init pwsh --config $themePath --print | Out-String | Invoke-Expression
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            zoxide init powershell --hook none | Out-String | Invoke-Expression
            Set-Alias -Name Set-PoshContext -Value Update-PsConfigDirectory -Scope Global -Force
        }
    }
}
Remove-Variable psConfig -ErrorAction SilentlyContinue
