$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

$AgentLog =
    'C:\Program Files\Positive Technologies\EDR Agent\agent.log'

$DownloadsDirectory =
    'C:\Users\Public\Downloads'

$ExecutablePath = Join-Path `
    $DownloadsDirectory `
    'EdTech_Network_Diagnostics.exe'

$RequiredModules = @(
    'core'
    'sysmon'
    'wineventlog'
    'etw_collector'
    'normalizer'
    'correlator'
    'proc_terminator'
)

# ============================================================
# Wait for all required EDR modules
# ============================================================

while ($true) {
    $InitializedModules = @()

    if (Test-Path -LiteralPath $AgentLog -PathType Leaf) {
        try {
            $InitializedModules = @(
                Get-Content -LiteralPath $AgentLog |
                    ForEach-Object {
                        if (
                            $_ -match 'msg="initialized successfully"' -and
                            $_ -match 'module_name=([^\s]+)'
                        ) {
                            $Matches[1]
                        }
                    } |
                    Sort-Object -Unique
            )
        }
        catch {
            $InitializedModules = @()
        }
    }

    $MissingModules = @(
        $RequiredModules |
            Where-Object {
                $_ -notin $InitializedModules
            }
    )

    if ($MissingModules.Count -eq 0) {
        break
    }

    Start-Sleep -Seconds 10
}

# ============================================================
# Start the previously downloaded training file
# ============================================================

if (
    -not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf) -or
    (Get-Item -LiteralPath $ExecutablePath).Length -le 0
) {
    throw "Training executable is missing or empty: $ExecutablePath"
}

Start-Process `
    -FilePath $ExecutablePath `
    -WorkingDirectory $DownloadsDirectory

exit 0