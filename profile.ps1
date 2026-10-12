# === 1. Powitanie MOTD — tutaj zmienisz imię i wygląd ===
# Zapisuj ten plik jako UTF-8: polskie litery i emoji nie wymagają dodatkowych modułów.
$global:PsConfigMotd = @{
    Enabled = $true                 # $false wyłącza powitanie.
    Name = 'Hubert'
    Stars = '⭐ 🌟 ✨ 🌠'
    DateFormat = 'dddd, d MMMM yyyy' # Np. wtorek, 22 września 2026.
    GreetingColor = 'Yellow'        # Nazwy kolorów PowerShell, np. Cyan, White.
    DetailColor = 'Gray'
    LineColor = 'DarkGray'
    LineCharacter = '─'             # Pojedynczy znak o szerokości jednej kolumny.
}

# === 2. Funkcje pomocnicze ===
# Kropka wczytuje funkcje do tej sesji: m.in. Show-Motd, keys, gcom i skróty eza.
. (Join-Path $PSScriptRoot 'functions.ps1')

# === 3. Ustawienia terminala — pomijane przy przekierowaniu wejścia/wyjścia ===
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
    # Lokalny indeks modułów odświeżysz skryptem scripts/Sync-Modules.ps1.
    $global:PsConfigModulePaths = @{}
    $moduleIndex = Join-Path $PSScriptRoot 'modules.json'
    if ([IO.File]::Exists($moduleIndex)) {
        $localModules = [IO.File]::ReadAllText($moduleIndex) | ConvertFrom-Json -AsHashtable
        foreach ($moduleName in $localModules.Keys) {
            $global:PsConfigModulePaths[$moduleName] = Join-Path $PSScriptRoot $localModules[$moduleName]
        }
        $localModuleRoot = Join-Path $PSScriptRoot 'modules'
        if (($env:PSModulePath -split ';') -notcontains $localModuleRoot) {
            $env:PSModulePath = $localModuleRoot + ';' + $env:PSModulePath
        }
    }
    # Historia podpowiada polecenia w liście; Windows zachowuje znane skróty edycji.
    $null = Import-PsConfigModule -Name PSReadLine
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -EditMode Windows -HistorySearchCursorMovesToEnd
    # Strzałki szukają po wpisanym początku; F1 i Ctrl+Alt+K pomagają poznać skróty.
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key F1 -Function ShowKeyBindings
    Set-PSReadLineKeyHandler -Key 'Ctrl+Alt+k' -Function WhatIsKey
    Set-Alias -Name keys -Value Show-PromptKeys -Scope Global -Force

    # === 4. Narzędzia i aliasy ===
    $scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    # Udostępnij programy Scoop także w oknie otwartym przed ich instalacją.
    $scoopShims = Join-Path $scoopRoot 'shims'
    if ((Test-Path -LiteralPath $scoopShims) -and ($env:PATH -split ';') -notcontains $scoopShims) {
        $env:PATH = $scoopShims + ';' + $env:PATH
    }
    # ls/la/tr pokazują pliki przez eza; Get-ChildItem/gci nadal zwraca obiekty.
    if (Get-Command eza.exe -ErrorAction SilentlyContinue) {
        Set-Alias -Name ls -Value Show-EzaList -Scope Global -Force
        Set-Alias -Name la -Value Show-EzaDetails -Scope Global -Force
        Set-Alias -Name tr -Value Show-EzaTree -Scope Global -Force
    }
    if (Get-Command lazygit -ErrorAction SilentlyContinue) {
        Set-Alias -Name lg -Value lazygit -Scope Global -Force
    }
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        # Kolorowy podgląd różnic tylko w tej sesji — bez zmiany globalnego Git config.
        $env:GIT_PAGER = 'delta --paging=auto --line-numbers'
        $env:DELTA_PAGER = 'less -R'
    }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        $env:BAT_PAGER = 'less -R'
    }
    # === 5. Ikony i uzupełnianie poleceń ===
    # Posh-git dostarcza propozycje dla poleceń Git. Ikony wczytujemy później.
    $null = Import-PsConfigModule -Name posh-git
    if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Import-PsConfigModule -Name PSFzf)) {
        # Ctrl+R: historia, Ctrl+T: ścieżki, Alt+C: katalog; Tab filtruje uzupełnienia.
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -PSReadlineChordSetLocation 'Alt+c'
        Set-PSReadLineKeyHandler -Key Tab -BriefDescription 'FzfTabCompletion' -Description 'Wybierz uzupelnienie przez fzf' -ScriptBlock { Invoke-FzfTabCompletion }
    } else {
        # Bez fzf działa standardowe menu uzupełniania PowerShell.
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    }

    # === 6. Pasek Oh My Posh i nawigacja zoxide ===
    # Nazwę motywu zmienisz w config.json; jego kolory są w themes/craver.omp.json.
    $psConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
    $poshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if (-not $poshCommand) {
        $poshPath = Join-Path $scoopRoot 'apps/oh-my-posh/current/oh-my-posh.exe'
        if (Test-Path -LiteralPath $poshPath) { $poshCommand = Get-Command $poshPath }
    }
    # Najpierw własny motyw, potem motywy dostarczone z Oh My Posh.
    $themeRoots = @((Join-Path $PSScriptRoot 'themes'), $env:POSH_THEMES_PATH, (Join-Path $scoopRoot 'apps/oh-my-posh/current/themes'))
    $themePath = $themeRoots | Where-Object { $_ } | ForEach-Object {
        Join-Path $_ ($psConfig.promptTheme + '.omp.json')
    } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($poshCommand -and $themePath) {
        # Usuń stary moduł, żeby . $PROFILE nie dublowało obsługi promptu.
        Get-Module -Name oh-my-posh-core | Remove-Module -Force
        # Cache powstaje z --print i odświeża się po zmianie motywu lub programu.
        Get-PsConfigPoshInit -Executable $poshCommand.Source -ThemePath $themePath -CacheDirectory (Join-Path $PSScriptRoot '.cache') | Invoke-Expression
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            # Zoxide uczy się katalogów po narysowaniu paska, bez zastępowania promptu.
            zoxide init powershell --hook none | Out-String | Invoke-Expression
            Set-Alias -Name Set-PoshContext -Value Update-PsConfigDirectory -Scope Global -Force
        }
    }
    # Terminal-Icons potrzebujemy dopiero przy Get-ChildItem/gci. Wrapper zachowuje
    # parametry cmdletu i usuwa się po pierwszym wywołaniu; ls/la/tr nadal używają eza.
    $lazyIconsPath = Join-Path $PSScriptRoot 'lazy-terminal-icons.ps1'
    if (-not (Get-Module -Name Terminal-Icons)) {
        if ([IO.File]::Exists($lazyIconsPath)) { . $lazyIconsPath }
        else { $null = Import-PsConfigModule -Name Terminal-Icons }
    }
    Remove-Variable psConfig, moduleName, moduleIndex, localModules, localModuleRoot, lazyIconsPath, scoopRoot, scoopShims, poshCommand, poshPath, themeRoots, themePath -ErrorAction SilentlyContinue

    # === 7. Powitanie na start ===
    # Tylko raz w sesji; ponownie wyświetlisz je poleceniem Show-Motd.
    if (-not (Get-Variable -Name PsConfigMotdShown -Scope Global -ValueOnly -ErrorAction Ignore)) {
        Show-Motd
    }
}
