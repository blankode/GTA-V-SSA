#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         blankode

 Script Function:
    Pauses and resumes GTAV process in order to obtain solo-session,
    fix game stuttering (server issues), AFK mode and process kill.

#ce ----------------------------------------------------------------------------

#include <AutoItConstants.au3>
#include <InetConstants.au3>
#include <MsgBoxConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIFiles.au3>

; -----------------------------------------------------------------------------
; SETTINGS
; -----------------------------------------------------------------------------

Global Const $GTA_PROCESS = "GTA5_Enhanced.exe"
Global Const $SUSPEND_TIME = 8

Global $AFK = False

; -----------------------------------------------------------------------------
; GUI
; -----------------------------------------------------------------------------

Global Const $GUI_WIDTH = 270
Local $x = @DesktopWidth - $GUI_WIDTH

HotKeySet("{F9}", "ToggleAFK")
HotKeySet("{F10}", "goSolo")
HotKeySet("{F11}", "terminate")
HotKeySet("{F12}", "KillGTA")

Local $hGUI = GUICreate("GTAV SSA", $GUI_WIDTH, 20, $x, 0, $WS_POPUP, $WS_EX_TOPMOST)

GUISetBkColor(0x000000)
GUISetFont(11, 400, -1, "Tahoma")

Global $context = GUICtrlCreateLabel( _
    "F9 = AFK | F10 = SOLO | F12 = KILL", _
    5, 0, 275, 20 _
)
GUICtrlSetColor($context, 0xFFFFFF)

Local $closeKey = GUICtrlCreateLabel("| F11", 235, 0, 45, 20)
GUICtrlSetColor($closeKey, 0xFF0000)

GUISetState(@SW_SHOW)

; -----------------------------------------------------------------------------
; MAIN LOOP
; -----------------------------------------------------------------------------

While 1
    Sleep(100)
WEnd

; -----------------------------------------------------------------------------
; RESET GUI TEXT
; -----------------------------------------------------------------------------

Func ResetStatus()

    GUICtrlSetData($context, "F9 = AFK | F10 = SOLO | F12 = KILL")
    GUICtrlSetColor($context, 0xFFFFFF)

EndFunc

; -----------------------------------------------------------------------------
; AFK MODE
; -----------------------------------------------------------------------------

Func ToggleAFK()

    $AFK = Not $AFK

    If $AFK Then

        GUICtrlSetData($context, "F9 = AFK [ON]")
        GUICtrlSetColor($context, 0x8CDD57)

        While $AFK

            Sleep(1500)
            If Not $AFK Then ExitLoop
            Send("{w}")

            Sleep(1500)
            If Not $AFK Then ExitLoop
            Send("{a}")

            Sleep(1500)
            If Not $AFK Then ExitLoop
            Send("{s}")

            Sleep(1500)
            If Not $AFK Then ExitLoop
            Send("{d}")

        WEnd

    EndIf

    ResetStatus()

EndFunc

; -----------------------------------------------------------------------------
; SOLO SESSION
; -----------------------------------------------------------------------------

Func goSolo()

    ; Check whether GTA is running
    Local $PID = ProcessExists($GTA_PROCESS)

    If $PID = 0 Then

        GUICtrlSetData($context, "GTA NOT FOUND")
        GUICtrlSetColor($context, 0xFF0000)

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            $GTA_PROCESS & " was not found." & @CRLF & @CRLF & _
            "Make sure GTA V Enhanced is running." _
        )

        ResetStatus()
        Return

    EndIf

    ; PsSuspend should be in the same folder as this script
    Local $PsSuspendPath = @ScriptDir & "\pssuspend.exe"

    If Not FileExists($PsSuspendPath) Then

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "pssuspend.exe was not found." & @CRLF & @CRLF & _
            "Put pssuspend.exe in:" & @CRLF & _
            @ScriptDir _
        )

        ResetStatus()
        Return

    EndIf

    ; -------------------------------------------------------------------------
    ; Suspend GTA
    ; -------------------------------------------------------------------------

    GUICtrlSetData($context, "SUSPENDING GTA...")
    GUICtrlSetColor($context, 0xFFFF00)

    Local $SuspendResult = RunWait( _
        '"' & $PsSuspendPath & '" ' & $PID, _
        @ScriptDir, _
        @SW_HIDE _
    )

    If $SuspendResult <> 0 Then

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Failed to suspend GTA." & @CRLF & @CRLF & _
            "Try running this script as Administrator." _
        )

        ResetStatus()
        Return

    EndIf

    ; -------------------------------------------------------------------------
    ; Countdown
    ; -------------------------------------------------------------------------

    For $i = $SUSPEND_TIME To 1 Step -1

        GUICtrlSetData($context, "RESUMING IN " & $i)
        GUICtrlSetColor($context, 0xFFFFFF)

        Sleep(1000)

    Next

    ; -------------------------------------------------------------------------
    ; Resume GTA
    ; -------------------------------------------------------------------------

    GUICtrlSetData($context, "RESUMING GTA...")
    GUICtrlSetColor($context, 0x8CDD57)

    Local $ResumeResult = RunWait( _
        '"' & $PsSuspendPath & '" -r ' & $PID, _
        @ScriptDir, _
        @SW_HIDE _
    )

    If $ResumeResult <> 0 Then

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Failed to resume GTA." & @CRLF & @CRLF & _
            "Try running this script as Administrator." _
        )

    EndIf

    ResetStatus()

EndFunc

; -----------------------------------------------------------------------------
; KILL GTA PROCESS
; -----------------------------------------------------------------------------

Func KillGTA()

    Local $PID = ProcessExists($GTA_PROCESS)

    If $PID = 0 Then

        GUICtrlSetData($context, "GTA NOT FOUND")
        GUICtrlSetColor($context, 0xFF0000)

        Sleep(1200)

        ResetStatus()
        Return

    EndIf

    ; Confirmation to prevent accidental F12 presses
    Local $Answer = MsgBox( _
        BitOR($MB_YESNO, $MB_ICONWARNING), _
        "GTAV SSA", _
        "Force close GTA V?" & @CRLF & @CRLF & _
        "PID: " & $PID _
    )

    If $Answer <> $IDYES Then
        ResetStatus()
        Return
    EndIf

    ; Disable AFK mode if active
    $AFK = False

    GUICtrlSetData($context, "KILLING GTA...")
    GUICtrlSetColor($context, 0xFF0000)

    ProcessClose($PID)

    ; Wait up to 5 seconds for process to disappear
    Local $Timer = TimerInit()

    While ProcessExists($PID)

        Sleep(100)

        If TimerDiff($Timer) > 5000 Then
            ExitLoop
        EndIf

    WEnd

    If ProcessExists($PID) Then

        GUICtrlSetData($context, "FAILED TO KILL GTA")
        GUICtrlSetColor($context, 0xFF0000)

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Failed to terminate GTA V." & @CRLF & @CRLF & _
            "Try running GTAV SSA as Administrator." _
        )

    Else

        GUICtrlSetData($context, "GTA TERMINATED")
        GUICtrlSetColor($context, 0x8CDD57)

        Sleep(1500)

    EndIf

    ResetStatus()

EndFunc

; -----------------------------------------------------------------------------
; EXIT GTAV SSA
; -----------------------------------------------------------------------------

Func terminate()

    $AFK = False
    Exit 0

EndFunc
