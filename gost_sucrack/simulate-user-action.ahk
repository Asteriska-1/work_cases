#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
CoordMode("Mouse", "Screen")

subjectHeader := "Subject: IT-48217: Workstation network diagnostics required"

thunderbirdExe :=
    EnvGet("ProgramFiles") "\Mozilla Thunderbird\thunderbird.exe"

profileDirectory :=
    EnvGet("APPDATA") "\Thunderbird\Profiles\mail-template"

archiveName := "IT-48217_Network_Diagnostics.zip"
folderName := "IT-48217_Network_Diagnostics"
executableName := "EdTech_Network_Diagnostics.exe"

downloadsDirectory := EnvGet("USERPROFILE") "\Downloads"
archivePath := downloadsDirectory "\" archiveName
extractDirectory := downloadsDirectory "\" folderName
executablePath := extractDirectory "\" executableName

; ============================================================
; Helper functions
; ============================================================

FindThunderbirdWindow(timeoutSeconds) {
    deadline := A_TickCount + timeoutSeconds * 1000

    while A_TickCount < deadline {
        for windowId in WinGetList("ahk_exe thunderbird.exe") {
            title := WinGetTitle("ahk_id " windowId)

            if InStr(title, "Mozilla Thunderbird")
                return windowId
        }

        Sleep(500)
    }

    return 0
}

WaitForMessage(profileDirectory, subjectHeader, timeoutSeconds) {
    deadline := A_TickCount + timeoutSeconds * 1000
    mailDirectory := profileDirectory "\Mail"

    while A_TickCount < deadline {
        Loop Files, mailDirectory "\*", "FR" {
            if A_LoopFileName != "Inbox"
                continue

            try {
                inboxContent := FileRead(A_LoopFileFullPath)

                if InStr(inboxContent, subjectHeader)
                    return true
            }
            catch {
                continue
            }
        }

        Sleep(1000)
    }

    return false
}

; ============================================================
; Initial checks
; ============================================================

if !FileExist(thunderbirdExe)
    throw Error("Thunderbird executable was not found")

if !DirExist(profileDirectory)
    throw Error("Thunderbird profile was not found")

if FileExist(archivePath)
    throw Error("Archive already exists in Downloads")

if DirExist(extractDirectory)
    throw Error("Extraction directory already exists")

; ============================================================
; Start Thunderbird
; ============================================================

if !ProcessExist("thunderbird.exe")
    Run('"' . thunderbirdExe . '"')

thunderbirdWindow := FindThunderbirdWindow(30)

if !thunderbirdWindow
    throw Error("Thunderbird main window was not found")

WinActivate("ahk_id " thunderbirdWindow)
WinMaximize("ahk_id " thunderbirdWindow)

if !WinWaitActive("ahk_id " thunderbirdWindow, , 5)
    throw Error("Thunderbird window was not activated")

; ============================================================
; Wait until Thunderbird downloads the message
; ============================================================

if !WaitForMessage(profileDirectory, subjectHeader, 600)
    throw Error("Training message was not received")

Sleep(2000)

WinGetPos(
    &windowX,
    &windowY,
    &windowWidth,
    &windowHeight,
    "ahk_id " thunderbirdWindow
)

; ============================================================
; Select the first message
; ============================================================

Click(
    windowX + Round(windowWidth * 0.4),
    windowY + 220
)

Sleep(2000)

; ============================================================
; Save attachment
; ============================================================

Click(
    windowX + windowWidth - 95,
    windowY + windowHeight - 50
)

if !WinWaitActive("Save Attachment", , 8)
    throw Error("Save Attachment window was not opened")

Sleep(500)

; Явно указываем полный путь в поле File name
Send("!n")
Sleep(200)
Send("^a")
SendText(archivePath)
Sleep(200)
Send("{Enter}")

if !WinWaitClose("Save Attachment", , 10)
    throw Error("Save Attachment window did not close")

if WinWaitActive("Confirm Save As", , 2)
    Send("!y")

Loop 100 {
    if FileExist(archivePath)
        break

    Sleep(100)
}

if !FileExist(archivePath)
    throw Error("Saved archive was not found")

psCommand := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Unblock-File -LiteralPath \"' . archivePath . '\""'
RunWait(psCommand, , "Hide")
Sleep(500)

; ============================================================
; Extract attachment
; ============================================================

DirCreate(extractDirectory)

shell := ComObject("Shell.Application")
archiveFolder := shell.NameSpace(archivePath)
destinationFolder := shell.NameSpace(extractDirectory)

if !IsObject(archiveFolder)
    throw Error("Archive could not be opened")

if !IsObject(destinationFolder)
    throw Error("Extraction directory could not be opened")

destinationFolder.CopyHere(
    archiveFolder.Items(),
    20
)

Loop 100 {
    if FileExist(executablePath)
        break

    Sleep(100)
}

if !FileExist(executablePath)
    throw Error("Extracted executable was not found")

; ============================================================
; Launch through Windows Explorer
; ============================================================

Run('explorer.exe /select,"' . executablePath . '"')

explorerWindow := WinWait(
    folderName . " ahk_exe explorer.exe",
    ,
    10
)

if !explorerWindow
    throw Error("Extraction directory was not opened")

WinActivate("ahk_id " explorerWindow)

if !WinWaitActive("ahk_id " explorerWindow, , 5)
    throw Error("Windows Explorer was not activated")

Sleep(1500)

WinGetPos(
    &explorerX,
    &explorerY,
    &explorerWidth,
    &explorerHeight,
    "ahk_id " explorerWindow
)

Click(
    explorerX + Round(explorerWidth * 0.4),
    explorerY + 205,
    2
)