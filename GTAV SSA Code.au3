#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         blankode

 Script Function:
    Pauses and resumes GTAV process in order to obtain solo-session
    or fix game stuttering (server issues)

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

Local $x = @DesktopWidth - 218

HotKeySet("{F9}", "ToggleAFK")
HotKeySet("{F10}", "goSolo")
HotKeySet("{F11}", "terminate")

Local $hGUI = GUICreate("GTAV SSA", 218, 20, $x, 0, $WS_POPUP, $WS_EX_TOPMOST)

GUISetBkColor(0x000000)
GUISetFont(11, 400, -1, "Tahoma")

Local $closeKey = GUICtrlCreateLabel("| F11", 180, 0, 38, 20)
GUICtrlSetColor($closeKey, 0xFF0000)

Global $context = GUICtrlCreateLabel("F9 = AFK | F10 = GO SOLO", 5, 0, 175, 20)
GUICtrlSetColor($context, 0xFFFFFF)

GUISetState(@SW_SHOW)

; -----------------------------------------------------------------------------
; MAIN LOOP
; -----------------------------------------------------------------------------

While 1
    Sleep(100)
WEnd

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

    GUICtrlSetData($context, "F9 = AFK | F10 = GO SOLO")
    GUICtrlSetColor($context, 0xFFFFFF)

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

        GUICtrlSetData($context, "F9 = AFK | F10 = GO SOLO")
        GUICtrlSetColor($context, 0xFFFFFF)

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

        GUICtrlSetData($context, "F9 = AFK | F10 = GO SOLO")
        GUICtrlSetColor($context, 0xFFFFFF)

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

    GUICtrlSetData($context, "F9 = AFK | F10 = GO SOLO")
    GUICtrlSetColor($context, 0xFFFFFF)

EndFunc

; -----------------------------------------------------------------------------
; EXIT
; -----------------------------------------------------------------------------

Func terminate()
    Exit 0
EndFunc
