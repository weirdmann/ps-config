#requires -Version 7.2
# Scoop persists fonts in HKCU. Register them for the current Windows session too.
$ErrorActionPreference = 'Stop'
if (-not ('PsConfig.FontApi' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PsConfig {
    public static class FontApi {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int AddFontResourceW(string path);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeoutW(IntPtr window, uint message,
            UIntPtr wparam, IntPtr lparam, uint flags, uint timeout, out UIntPtr result);
    }
}
'@
}
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
$fontFiles = @(Get-ChildItem -LiteralPath $fontDir -Filter 'AtkynsonMonoNerdFont-*.otf')
if (-not $fontFiles.Count) { throw 'AtkynsonMono font files not found.' }
foreach ($font in $fontFiles) {
    if ([PsConfig.FontApi]::AddFontResourceW($font.FullName) -eq 0) {
        throw "Windows could not register font $($font.Name)."
    }
}
$result = [UIntPtr]::Zero
[void][PsConfig.FontApi]::SendMessageTimeoutW([IntPtr]0xffff, 0x001D,
    [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result)
Write-Host "Registered $($fontFiles.Count) font faces in this Windows session."
