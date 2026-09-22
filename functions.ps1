# === MOTD: rozpoznawanie sesji i wyświetlanie powitania ===
function Test-PsConfigInteractiveSession {
    param([string[]]$StartupArguments = ([Environment]::GetCommandLineArgs() | Select-Object -Skip 1))
    # Sama obecność konsoli nie wystarcza: -File i -Command mogą uruchamiać automat.
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        return $false
    }
    $noExit = $false
    $runsCommand = $false
    for ($index = 0; $index -lt $StartupArguments.Count; $index++) {
        $argument = $StartupArguments[$index]
        if ($argument.Length -ge 5 -and '-noninteractive'.StartsWith($argument, [StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($argument -match '^-(noe|noex|noexi|noexit)$') { $noExit = $true }
        # Opcje takie jak -ExecutionPolicy i -WorkingDirectory mają własną wartość.
        if ($argument -match '^-(ex\w*|ep|wo\w*|wd|windowstyle|w|configuration\w*|config|settings\w*|custompipe\w*|input\w*|inp|output\w*|o)$') {
            $index++
            continue
        }
        if ($argument -match '^-(c|co|com\w*|cwa|e|ec|en\w*|f|fi\w*)$' -or -not $argument.StartsWith('-')) {
            $runsCommand = $true
            break # Dalej jest treść polecenia lub argumenty skryptu, nie opcje powłoki.
        }
    }
    return (-not $runsCommand -or $noExit)
}

function Show-Motd {
    <# .SYNOPSIS
    Wyświetla powitanie ponownie. Ustawienia są na początku profile.ps1.
    #>
    if (-not (Test-PsConfigInteractiveSession) -or -not $global:PsConfigMotd.Enabled) { return }
    $settings = $global:PsConfigMotd

    # Odczytaj szerokość okna, nie zakładając, że każdy host udostępnia konsolę.
    $width = 0
    try { $width = [Console]::WindowWidth } catch { }
    if ($width -le 0) {
        try { $width = $Host.UI.RawUI.WindowSize.Width } catch { }
    }
    try {
        $bufferWidth = [Console]::BufferWidth
        if ($bufferWidth -gt 0 -and $width -gt 0) { $width = [Math]::Min($width, $bufferWidth) }
    } catch { }

    # Write-Host wyświetla tekst, nie dodając obiektów do zwykłego potoku poleceń.
    # Nie zmieniamy globalnego kodowania ani kultury używanej przez inne programy.
    $date = (Get-Date).ToString($settings.DateFormat, [Globalization.CultureInfo]::GetCultureInfo('pl-PL'))
    Write-Host
    Write-Host "Cześć, $($settings.Name)!  $($settings.Stars)" -ForegroundColor $settings.GreetingColor
    Write-Host "Dzisiaj: $date" -ForegroundColor $settings.DetailColor
    Write-Host "Komputer: $([Environment]::MachineName)" -ForegroundColor $settings.DetailColor

    # Zostaw ostatnią kolumnę wolną, aby linia nie zawinęła się automatycznie.
    # Bez wiarygodnej szerokości pomiń linię, zamiast zgadywać rozmiar terminala.
    if ($width -gt 1) {
        $lineCharacter = [string]$settings.LineCharacter
        if ($lineCharacter -notmatch '^[\x20-\x7E\u2500-\u257F]$') { $lineCharacter = '-' }
        Write-Host ($lineCharacter * ($width - 1)) -ForegroundColor $settings.LineColor
    }
    $global:PsConfigMotdShown = $true
}

# === Pomoc do skrótów klawiszowych ===
function Show-PromptKeys {
    [CmdletBinding()]
    param([Parameter(Position = 0)][ValidateSet('All', 'Ctrl', 'Alt', 'Shift')][string]$Modifier = 'All')
    Get-PSReadLineKeyHandler -Bound | Where-Object {
        $Modifier -eq 'All' -or $_.Key -match "(?i)(^|[+,])$Modifier\+"
    } | Sort-Object Key | Select-Object Key, Function, Description
}

# === Zapamiętywanie katalogów przez zoxide ===
function Update-PsConfigDirectory {
    # Korzystamy z wywołania przez Oh My Posh, aby nie zakłócać transient prompt.
    $savedExitCode = $global:LASTEXITCODE
    try {
        $location = Get-Location
        if ($location.Provider.Name -eq 'FileSystem' -and $global:PsConfigLastDirectory -ne $location.ProviderPath) {
            zoxide add -- $location.ProviderPath
            if ($LASTEXITCODE -eq 0) { $global:PsConfigLastDirectory = $location.ProviderPath }
        }
    } finally {
        # Zapamiętywanie katalogu nie może zmieniać wyniku ostatniego polecenia.
        $global:LASTEXITCODE = $savedExitCode
    }
}

# === Listy plików — tutaj zmienisz opcje ls, la i tr ===
function Show-EzaList {
    # @args przekazuje opcje i ścieżki ze spacjami bez zmian do eza.
    eza.exe --oneline --group-directories-first --icons=auto @args
}

function Show-EzaDetails {
    eza.exe --long --all --header --group --binary --links --classify=auto --group-directories-first --icons=auto @args
}

function Show-EzaTree {
    eza.exe --tree --level=2 --long --binary --group-directories-first --icons=auto @args
}

# === Skróty Git — przed użyciem sprawdź git status ===
function gcom {
    <# .SYNOPSIS
    Dodaje zmiany z bieżącego katalogu i tworzy commit. Błąd przerywa operację.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Message)
    git add -- .
    if ($LASTEXITCODE -ne 0) { throw 'git add failed; commit cancelled.' }
    git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
}

function lazyg {
    <# .SYNOPSIS
    Dodaje zmiany, tworzy commit i wysyła go. Nieudany commit blokuje push.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Message)
    gcom -Message $Message
    git push
    if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
}

# === Wyszukiwanie poleceń i ich lokalizacji ===
function which {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    Get-Command -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty Definition
}

function whichdir {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    $command = Get-Command -Name $Name -ErrorAction Stop | Select-Object -First 1
    while ($command.CommandType -eq 'Alias') { $command = $command.ResolvedCommand }
    if ($command.Path) { Split-Path -Parent $command.Path }
    elseif ($command.Module -and $command.Module.ModuleBase) { $command.Module.ModuleBase }
    else { Write-Error "Command '$Name' has no filesystem location." }
}
