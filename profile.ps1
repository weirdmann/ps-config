# PowerShell 7 user profile. Loaded from a local installed copy of ps-config.
$psConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'functions.ps1')

if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# Redirected shells (CI, scripts, agents) do not have an interactive console.
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows -PredictionSource History -PredictionViewStyle InlineView
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    $poshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    if (-not $poshCommand) {
        $poshPath = Join-Path $scoopRoot 'apps/oh-my-posh/current/oh-my-posh.exe'
        if (Test-Path -LiteralPath $poshPath) { $poshCommand = Get-Command $poshPath }
    }
    $themeRoots = @((Join-Path $PSScriptRoot 'themes'), $env:POSH_THEMES_PATH, (Join-Path $scoopRoot 'apps/oh-my-posh/current/themes'))
    $themePath = $themeRoots | Where-Object { $_ } | ForEach-Object {
        Join-Path $_ ($psConfig.promptTheme + '.omp.json')
    } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($poshCommand -and $themePath) {
        & $poshCommand.Source init pwsh --config $themePath | Invoke-Expression
    }
}
Remove-Variable psConfig -ErrorAction SilentlyContinue
