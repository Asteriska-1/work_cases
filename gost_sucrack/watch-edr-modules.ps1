Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# Settings
# ============================================================

$AgentLogFile = 'C:\Program Files\Positive Technologies\EDR Agent\agent.log'
$CheckIntervalSeconds = 10

$StateDirectory = 'C:\ProgramData\EdTechLab\MailTrigger'
$CompletedFlag = Join-Path $StateDirectory 'completed.flag'

$SshExe = "$env:SystemRoot\System32\OpenSSH\ssh.exe"
$MailServerHost = 'mail.edtechlab.local'
$TriggerUser = 'mailtrigger'

$PrivateKeyBase64 = '__PRIVATE_KEY_BASE64__'

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
# Initialized modules
# ============================================================

function Get-InitializedModules {
    if (-not (Test-Path -LiteralPath $AgentLogFile)) {
        return @()
    }

    try {
        $modules = foreach ($line in Get-Content -LiteralPath $AgentLogFile) {
            if (
                $line.Contains('msg="initialized successfully"') -and
                $line -match '(?:^|\s)module_name=([^\s]+)'
            ) {
                $Matches[1]
            }
        }

        return @($modules | Sort-Object -Unique)
    }
    catch {
        return @()
    }
}

function Test-RequiredModules {
    $initializedModules = @(Get-InitializedModules)

    foreach ($requiredModule in $RequiredModules) {
        if ($initializedModules -notcontains $requiredModule) {
            return $false
        }
    }

    return $true
}

# ============================================================
# SSH trigger
# ============================================================

function Invoke-MailTrigger {
    if (-not (Test-Path -LiteralPath $SshExe)) {
        throw "OpenSSH client not found: $SshExe"
    }

    if ($PrivateKeyBase64 -eq '__PRIVATE_KEY_BASE64__') {
        throw 'Private key Base64 has not been inserted'
    }

    New-Item `
        -ItemType Directory `
        -Path $StateDirectory `
        -Force |
        Out-Null

    $temporaryKey = Join-Path $StateDirectory 'mail-trigger.key'

    try {
        $keyBytes = [Convert]::FromBase64String(
            $PrivateKeyBase64.Trim()
        )

        [System.IO.File]::WriteAllBytes(
            $temporaryKey,
            $keyBytes
        )

        & "$env:SystemRoot\System32\icacls.exe" `
            $temporaryKey `
            '/inheritance:r' `
            '/grant:r' `
            '*S-1-5-18:(F)' |
            Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to restrict private key permissions'
        }

        & $SshExe `
            -T `
            -i $temporaryKey `
            -o BatchMode=yes `
            -o IdentitiesOnly=yes `
            -o StrictHostKeyChecking=no `
            -o UserKnownHostsFile=NUL `
            -o LogLevel=ERROR `
            -o ConnectTimeout=10 `
            "$TriggerUser@$MailServerHost"

        if ($LASTEXITCODE -ne 0) {
            throw "SSH trigger failed with exit code $LASTEXITCODE"
        }

        [System.IO.File]::WriteAllText(
            $CompletedFlag,
            [DateTimeOffset]::Now.ToString('O')
        )
    }
    finally {
        Remove-Item `
            -LiteralPath $temporaryKey `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Watch loop
# ============================================================

if (Test-Path -LiteralPath $CompletedFlag) {
    exit 0
}

while (-not (Test-RequiredModules)) {
    Start-Sleep -Seconds $CheckIntervalSeconds
}

Invoke-MailTrigger
exit 0