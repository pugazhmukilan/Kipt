param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$AabPath
)

# Reads versionCode / versionName / package from an Android App Bundle's compiled manifest.
# Usage: .\verify-aab.ps1 "path\to\app-release.aab"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolved = (Resolve-Path -LiteralPath $AabPath).Path
$zip = [System.IO.Compression.ZipFile]::OpenRead($resolved)
try {
    $entry = $zip.Entries | Where-Object { $_.FullName -eq "base/manifest/AndroidManifest.xml" }
    if (-not $entry) { throw "Not an App Bundle (no base/manifest/AndroidManifest.xml): $resolved" }
    $stream = $entry.Open()
    $ms = New-Object System.IO.MemoryStream
    $stream.CopyTo($ms)
    $stream.Close()
} finally {
    $zip.Dispose()
}

$bytes = $ms.ToArray()
$ascii = [System.Text.Encoding]::ASCII.GetString($bytes)

# In the compiled manifest protobuf an attribute value is a length-prefixed string:
#   <name> 0x1A <len> <value bytes>
function Get-AttrValue($name) {
    $i = $ascii.IndexOf($name)
    if ($i -lt 0) { return $null }
    $p = $i + $name.Length
    if ($p + 1 -ge $bytes.Length) { return $null }
    if ($bytes[$p] -ne 0x1A) { return $null }
    $len = $bytes[$p + 1]
    if ($p + 2 + $len -gt $bytes.Length) { return $null }
    return [System.Text.Encoding]::ASCII.GetString($bytes, $p + 2, $len)
}

$versionCode = Get-AttrValue "versionCode"
$versionName = Get-AttrValue "versionName"
$package = ([regex]::Match($ascii, 'com\.[A-Za-z0-9_.]+')).Value

Write-Output "File        : $resolved"
Write-Output "Size        : $((Get-Item -LiteralPath $resolved).Length) bytes"
Write-Output "package     : $package"
Write-Output "versionCode : $versionCode"
Write-Output "versionName : $versionName"
Write-Output ""
if ($versionCode -eq "1") {
    Write-Warning "versionCode is 1 - Play Console will reject this with 'Version code 1 has already been used'."
} elseif ($versionCode) {
    Write-Output "OK - upload this file."
} else {
    Write-Warning "Could not parse versionCode."
}
