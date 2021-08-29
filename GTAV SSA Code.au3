#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         blankode

 Script Function:
	Pauses and resumes GTAV process in order to obtain solo-session or fix game stuttering (server issues)

#ce ----------------------------------------------------------------------------
#include <AutoItConstants.au3>
#include <InetConstants.au3>
#include <MsgBoxConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIFiles.au3>
$x = @DesktopWidth - 218
HotKeySet("{F9}", "ToggleAFK")
HotKeySet("{F10}", "goSolo")
HotKeySet("{F11}", "terminate")

Local $hGUI = GUICreate("GTAV SSA", 218, 20, $x, 0, $WS_POPUP, $WS_EX_TOPMOST)
GUISetBkColor(0x000000)
GUISetFont(11, 400, -1, "Tahoma")
Local $closeKey = GUICtrlCreateLabel("| F11", 180, 0, 50, 20)
GUICtrlSetColor(-1, 0xFF0000) ; Red
Global $context = GUICtrlCreateLabel("F9 = AFK | F10 = GO SOLO", 5, 0, 177, 20)
GUICtrlSetColor(-1, 0xFFFFFF) ; White
GUISetState(@SW_SHOW)

Global $AFK = False

While 1
    Sleep(100)
WEnd

Func ToggleAFK()
    $AFK = NOT $AFK
    While $AFK
		$context = GUICtrlCreateLabel("F9 = AFK", 5, 0, 60, 20)
		GUICtrlSetColor(-1, 0x8CDD57) ; Green
		Sleep(1500)
		Send("{w}")
		Sleep(1500)
		Send("{a}")
		Sleep(1500)
		Send("{s}")
		Sleep(1500)
		Send("{d}")
    WEnd
		$context = GUICtrlCreateLabel("F9 = AFK", 5, 0, 60, 20)
		GUICtrlSetColor(-1, 0xFFFFFF) ; White
EndFunc

Func goSolo()
   Run("pssuspend.exe" & " \\" & @COMPUTERNAME & " GTA5")
   For $i = 8 To 1 Step -1
   $context = GUICtrlCreateLabel("RESUMING IN " & $i, 5, 0, 177, 20)
   GUICtrlSetColor(-1, 0xFFFFFF) ; White
	  Sleep (1000)
   Next
   Run("pssuspend.exe" & " \\" & @COMPUTERNAME & " GTA5 -r")
   $context = GUICtrlCreateLabel("F9 = AFK | F10 = GO SOLO", 5, 0, 170, 20)
   GUICtrlSetColor(-1, 0xFFFFFF) ; White
EndFunc

Func terminate()
    Exit 0
EndFunc