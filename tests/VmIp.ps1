#requires -Version 7.2
# Test transportu w prawdziwym procesie potomnym, bez UAC i bez dostępu do Hyper-V.
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'functions.ps1')
function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$definition = (Get-Command gvmip).Definition
$script:fixture = @'
function Get-VM {
    [CmdletBinding()] param()
    [pscustomobject]@{ Name = 'żółta-vm'; State = 'Running' }
    [pscustomobject]@{ Name = 'stopped-vm'; State = 'Off' }
}
function Get-VMNetworkAdapter {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$VM)
    process {
        [pscustomobject]@{
            VMName = $VM.Name; SwitchName = 'test-switch'; MacAddress = '001122334455'
            IPAddresses = @('192.0.2.10', '169.254.1.2', 'fe80::1', '198.51.100.20')
        }
    }
}
'@
function Start-Process {
    param($FilePath, $Verb, $WindowStyle, [switch]$Wait, [switch]$PassThru, $ErrorAction, $ArgumentList)
    Assert ($Verb -eq 'RunAs' -and $WindowStyle -eq 'Hidden' -and $Wait -and $PassThru) 'Wrong launch options.'
    Assert ($ArgumentList -notcontains '-NoExit') 'Worker would remain open.'
    Assert ($ArgumentList -contains '-NoProfile' -and $ArgumentList -contains '-NonInteractive') 'Worker loads an interactive profile.'
    $code = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($ArgumentList[-1]))
    Assert ($code -match "-ResultPath '((?:''|[^'])*)' -Query") 'Missing result path.'
    $script:resultPath = $Matches[1].Replace("''", "'")
    if ($script:mode -eq 'cancel') { throw [ComponentModel.Win32Exception]::new(1223) }
    $exitCode = 9
    if ($script:mode -ne 'missing') {
        $setup = switch ($script:mode) {
            'failure' { "function Get-VM { throw 'test Hyper-V failure' }" }
            'empty' { 'function Get-VM { }' }
            default { $script:fixture }
        }
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("$setup`n$code"))
        & $FilePath -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded
        $exitCode = $LASTEXITCODE
    }
    $process = [pscustomobject]@{ ExitCode = $exitCode }
    $process | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    return $process
}

# Wymuś gałąź nieadministracyjną niezależnie od uprawnień runnera CI.
$Function:gvmip = [scriptblock]::Create($definition.Replace(
    '$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
    '$isAdmin = $false'
))
foreach ($script:mode in @('success', 'empty', 'failure', 'cancel', 'missing')) {
    $warningText = @()
    $errorText = @()
    $output = gvmip -ErrorAction SilentlyContinue -ErrorVariable errorText -WarningAction SilentlyContinue -WarningVariable warningText | Out-String
    Assert (-not (Test-Path -LiteralPath (Split-Path -Parent $script:resultPath))) "Temporary data remains: $script:mode $script:resultPath; errors: $($errorText | Out-String)"
    switch ($script:mode) {
        'success' {
            Assert ($output.Contains('żółta-vm') -and $output.Contains('192.0.2.10, 198.51.100.20')) 'Result did not reach parent intact.'
            Assert ($output -notmatch 'stopped-vm|169\.254|fe80') 'Filtering failed.'
        }
        'empty' { Assert ([string]::IsNullOrWhiteSpace($output)) 'Empty result produced a table.' }
        'failure' { Assert (($errorText | Out-String).Contains('test Hyper-V failure')) 'Child error lost.' }
        'cancel' { Assert (($warningText | Out-String).Contains('Anulowano zgodę UAC')) 'Cancellation not handled.' }
        'missing' { Assert (($errorText | Out-String).Contains('nie zwrócił wyniku')) 'Missing result not handled.' }
    }
}

# W oknie administratora nie uruchamiaj drugiego procesu.
$Function:gvmip = [scriptblock]::Create($definition.Replace(
    '$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
    '$isAdmin = $true'
))
Invoke-Expression $script:fixture
function Start-Process { throw 'Unexpected elevation in admin branch.' }
$output = gvmip | Out-String
Assert ($output.Contains('żółta-vm')) 'Direct admin execution failed.'
Write-Host 'PASS: child transport, Unicode, filtering, empty result, errors, UAC cancellation, cleanup, direct admin branch.'
