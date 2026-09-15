$ErrorActionPreference = 'Stop'

$StateDirectory = Join-Path $env:LOCALAPPDATA 'EdTechLab\UserSimulation'
New-Item -Path $StateDirectory -ItemType Directory -Force | Out-Null
$FinishedMarker = Join-Path $StateDirectory 'ahk-finished.flag'

if (Test-Path -LiteralPath $FinishedMarker -PathType Leaf) {
    exit 0
}

try {
    # Correct the inherited profile before starting Thunderbird.
    & (Join-Path $PSScriptRoot 'prepare-simulation-profile.ps1')

    $ThunderbirdExe = Join-Path $env:ProgramFiles 'Mozilla Thunderbird\thunderbird.exe'
    $ThunderbirdProfile = Join-Path $env:APPDATA 'Thunderbird\Profiles\mail-template'
    $InboxFile = Join-Path $ThunderbirdProfile 'Mail\mail.edtechlab.local\Inbox'
    $SubjectHeader = 'Subject: IT-48217: Workstation network diagnostics required'

    if (-not (Test-Path -LiteralPath $InboxFile -PathType Leaf)) {
        throw "Expected Thunderbird Inbox file not found: $InboxFile"
    }

    Start-Process -FilePath $ThunderbirdExe `
        -ArgumentList ('-profile "{0}"' -f $ThunderbirdProfile)

    # Policies may be assigned much later than logon. Wait for the mail locally.
    # This path belongs to the verified POP3/mbox template.
    while ($true) {
        try {
            if ([System.IO.File]::ReadAllText($InboxFile).Contains($SubjectHeader)) {
                break
            }
        }
        catch [System.IO.IOException] {
            # Retry if Thunderbird temporarily holds the mailbox file open.
        }

        Start-Sleep -Seconds 10
    }

    $AutoHotkeyExe = Join-Path $PSScriptRoot 'AutoHotkey64.exe'
    $ActionScript = Join-Path $PSScriptRoot 'simulate-user-action.ahk'
    $AhkErrorLog = Join-Path $StateDirectory 'ahk-syntax-errors.log'

    $AhkProcess = Start-Process -FilePath $AutoHotkeyExe `
        -ArgumentList ('/ErrorStdOut=UTF-8 "{0}"' -f $ActionScript) `
        -WorkingDirectory $PSScriptRoot `
        -RedirectStandardError $AhkErrorLog -PassThru

    # The mail is already downloaded. Detect a stuck UI or an AHK error dialog.
    if (-not $AhkProcess.WaitForExit(300000)) {
        throw 'AutoHotkey did not exit within 5 minutes. Inspect the alice desktop; the process was left running.'
    }
    $AhkProcess.WaitForExit()
    $AhkProcess.Refresh()

    if ($AhkProcess.ExitCode -ne 0) {
        throw "AutoHotkey exited with code $($AhkProcess.ExitCode). Syntax error log: $AhkErrorLog"
    }

    # This records AHK exit code 0; process execution is verified separately in EDR.
    [DateTime]::UtcNow.ToString('o') |
        Set-Content -LiteralPath $FinishedMarker -Encoding ASCII
}
catch {
    $FailureText = '{0}{1}{2}' -f [DateTime]::UtcNow.ToString('o'), `
        [Environment]::NewLine, ($_ | Out-String)
    $FailureText | Set-Content -LiteralPath (Join-Path $StateDirectory 'error.log') -Encoding UTF8
    exit 1
}
