$ErrorActionPreference = 'Stop'

# Use the Thunderbird profile inherited from C:\Users\Default.
# Do not extract a second archive or overwrite profiles.ini / installs.ini.
$ThunderbirdProfile = Join-Path $env:APPDATA 'Thunderbird\Profiles\mail-template'
$PrefsFile = Join-Path $ThunderbirdProfile 'prefs.js'
$Pkcs11File = Join-Path $ThunderbirdProfile 'pkcs11.txt'

if (-not (Test-Path -LiteralPath $PrefsFile -PathType Leaf)) {
    throw "Inherited Thunderbird profile not found: $ThunderbirdProfile"
}

$Pkcs11Content = [System.IO.File]::ReadAllText($Pkcs11File)
$ConfigMatch = [regex]::Match($Pkcs11Content, "configdir='sql:[^']*'")

if (-not $ConfigMatch.Success) {
    throw "Thunderbird key database path not found: $Pkcs11File"
}

$EscapedProfilePath = $ThunderbirdProfile.Replace('\', '\\')
$UpdatedContent = $Pkcs11Content.Replace(
    $ConfigMatch.Value,
    "configdir='sql:$EscapedProfilePath'"
)

if ($UpdatedContent -ceq $Pkcs11Content) {
    return
}

# Do not change the key database path while Thunderbird uses this session.
$CurrentSessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
if (Get-Process thunderbird -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $CurrentSessionId }) {
    throw 'Close Thunderbird in this session before preparing the profile'
}

[System.IO.File]::WriteAllText(
    $Pkcs11File,
    $UpdatedContent,
    [System.Text.UTF8Encoding]::new($false)
)
