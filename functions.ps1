function Show-PromptKeys {
    [CmdletBinding()]
    param([Parameter(Position = 0)][ValidateSet('All', 'Ctrl', 'Alt', 'Shift')][string]$Modifier = 'All')
    Get-PSReadLineKeyHandler -Bound | Where-Object {
        $Modifier -eq 'All' -or $_.Key -match "(?i)(^|[+,])$Modifier\+"
    } | Sort-Object Key | Select-Object Key, Function, Description
}

function Update-PsConfigDirectory {
    # Use Oh My Posh's hook rather than wrapping its transient prompt function.
    $savedExitCode = $global:LASTEXITCODE
    try {
        $location = Get-Location
        if ($location.Provider.Name -eq 'FileSystem' -and $global:PsConfigLastDirectory -ne $location.ProviderPath) {
            zoxide add -- $location.ProviderPath
            if ($LASTEXITCODE -eq 0) { $global:PsConfigLastDirectory = $location.ProviderPath }
        }
    } finally {
        $global:LASTEXITCODE = $savedExitCode
    }
}

function Show-EzaList {
    # Forward arguments unchanged, including paths with spaces and native flags.
    eza.exe --oneline --group-directories-first --icons=auto @args
}

function Show-EzaDetails {
    eza.exe --long --all --header --group --binary --links --classify=auto --group-directories-first --icons=auto @args
}

function Show-EzaTree {
    eza.exe --tree --level=2 --long --binary --group-directories-first --icons=auto @args
}

function gcom {
    <# .SYNOPSIS
    Stage changes in the current directory and commit. Stops on any Git error.
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
    Stage, commit, and push to the configured upstream. A failed commit prevents push.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Message)
    gcom -Message $Message
    git push
    if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
}

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
