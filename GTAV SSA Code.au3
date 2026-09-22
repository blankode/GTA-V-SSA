#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.5
 Author:         blankode

 Script Function:
    GTAV SSA
    - F9  = Toggle AFK mode
    - F10 = Create solo session by suspending GTA
    - F11 = Exit GTAV SSA
    - F12 = Forcefully terminate GTA, then clear GTA V Enhanced Profiles
    - X   = Exit GTAV SSA

#ce ----------------------------------------------------------------------------

#RequireAdmin

#include <AutoItConstants.au3>
#include <InetConstants.au3>
#include <MsgBoxConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIFiles.au3>
#include <Misc.au3>
#include <StaticConstants.au3>

; -----------------------------------------------------------------------------
; SETTINGS
; -----------------------------------------------------------------------------

Global Const $GTA_PROCESS = "GTA5_Enhanced.exe"
Global Const $SUSPEND_TIME = 8

; Per-user configuration.
; The detected/custom Profiles path is persisted here.
Global Const $CONFIG_DIR = @LocalAppDataDir & "\GTAV SSA"
Global Const $CONFIG_FILE = $CONFIG_DIR & "\config.ini"
Global Const $CONFIG_SECTION = "Paths"
Global Const $CONFIG_KEY_PROFILES = "ProfilesPath"

DirCreate($CONFIG_DIR)

; Resolve the GTA V Enhanced Profiles folder at startup.
; First tries the saved config, then the current user's Documents folder.
; If neither is valid, the user is asked to select it once.
Global $ProfilesPath = ResolveProfilesPath()

; -----------------------------------------------------------------------------
; GLOBAL STATE
; -----------------------------------------------------------------------------

Global $AFK = False
Global $AFKTimer = TimerInit()
Global $AFKStep = 0

Global $SoloActive = False
Global $SoloPID = 0
Global $SoloTimer = 0
Global $LastCountdown = -1

Global $KillingGTA = False

; Used for physical F12 detection
Global $F12WasPressed = False

; Used to periodically reinforce always-on-top
Global $TopMostTimer = TimerInit()

; -----------------------------------------------------------------------------
; GUI
; -----------------------------------------------------------------------------

Global Const $GUI_WIDTH = 285
Global Const $GUI_HEIGHT = 20

Local $x = @DesktopWidth - $GUI_WIDTH

HotKeySet("{F9}", "ToggleAFK")
HotKeySet("{F10}", "goSolo")
HotKeySet("{F11}", "terminate")

; F12 is intentionally NOT registered using HotKeySet.
; It is detected directly using _IsPressed().

; WS_EX_TOOLWINDOW:
; Prevents the utility from appearing as a normal taskbar application.
;
; WS_EX_TOPMOST:
; Keeps the utility above normal windows.

Global $hGUI = GUICreate( _
    "GTAV SSA", _
    $GUI_WIDTH, _
    $GUI_HEIGHT, _
    $x, _
    0, _
    $WS_POPUP, _
    BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW) _
)

GUISetBkColor(0x000000)
GUISetFont(11, 400, -1, "Tahoma")

; -----------------------------------------------------------------------------
; STATUS TEXT
; -----------------------------------------------------------------------------

Global $context = GUICtrlCreateLabel( _
    "F9 = AFK | F10 = SOLO | F12 = KILL", _
    5, _
    0, _
    240, _
    20 _
)

GUICtrlSetColor($context, 0xFFFFFF)

; -----------------------------------------------------------------------------
; F11 DISPLAY
; -----------------------------------------------------------------------------

Global $closeKey = GUICtrlCreateLabel( _
    "| F11", _
    232, _
    0, _
    43, _
    20 _
)

GUICtrlSetColor($closeKey, 0xFF0000)

; -----------------------------------------------------------------------------
; CLICKABLE X BUTTON
; -----------------------------------------------------------------------------

Global $closeButton = GUICtrlCreateLabel( _
    "X", _
    265, _
    0, _
    20, _
    20, _
    $SS_CENTER _
)

GUICtrlSetColor($closeButton, 0xFF0000)
GUICtrlSetBkColor($closeButton, 0x000000)

; Show GUI without activating it unnecessarily
GUISetState(@SW_SHOW, $hGUI)

; Explicitly force always-on-top
WinSetOnTop($hGUI, "", 1)

; -----------------------------------------------------------------------------
; MAIN LOOP
; -----------------------------------------------------------------------------

While 1

    ; -------------------------------------------------------------------------
    ; GUI EVENTS
    ; -------------------------------------------------------------------------

    Local $msg = GUIGetMsg()

    Switch $msg

        Case $GUI_EVENT_CLOSE
            terminate()

        Case $closeButton
            terminate()

    EndSwitch

    ; -------------------------------------------------------------------------
    ; GTA / HOTKEY PROCESSING
    ; -------------------------------------------------------------------------

    CheckF12()
    ProcessAFK()
    ProcessSolo()

    ; -------------------------------------------------------------------------
    ; REINFORCE ALWAYS-ON-TOP
    ;
    ; WS_EX_TOPMOST normally handles this already.
    ; This periodically reinforces it in case another application changes
    ; the window's Z-order.
    ; -------------------------------------------------------------------------

    If TimerDiff($TopMostTimer) >= 2000 Then

        WinSetOnTop($hGUI, "", 1)
        $TopMostTimer = TimerInit()

    EndIf

    Sleep(25)

WEnd

; -----------------------------------------------------------------------------
; DEFAULT / IDLE STATUS
; -----------------------------------------------------------------------------

Func ResetStatus()

    If $AFK Then

        GUICtrlSetData($context, "F9 = AFK [ON]")
        GUICtrlSetColor($context, 0x8CDD57)

    Else

        GUICtrlSetData($context, "F9 = AFK | F10 = SOLO | F12 = KILL")
        GUICtrlSetColor($context, 0xFFFFFF)

    EndIf

EndFunc

; -----------------------------------------------------------------------------
; F12 PHYSICAL KEY DETECTION
; -----------------------------------------------------------------------------

Func CheckF12()

    ; F12 virtual-key code = 0x7B
    Local $Pressed = _IsPressed("7B")

    ; Trigger only once per physical key press
    If $Pressed And Not $F12WasPressed Then

        $F12WasPressed = True
        KillGTA()

    ElseIf Not $Pressed Then

        $F12WasPressed = False

    EndIf

EndFunc

; -----------------------------------------------------------------------------
; AFK MODE TOGGLE
; -----------------------------------------------------------------------------

Func ToggleAFK()

    $AFK = Not $AFK

    If $AFK Then

        $AFKStep = 0
        $AFKTimer = TimerInit()

        GUICtrlSetData($context, "F9 = AFK [ON]")
        GUICtrlSetColor($context, 0x8CDD57)

    Else

        ResetStatus()

    EndIf

EndFunc

; -----------------------------------------------------------------------------
; AFK PROCESSING
; -----------------------------------------------------------------------------

Func ProcessAFK()

    If Not $AFK Then Return

    ; Don't send movement keys while GTA is suspended or being killed
    If $SoloActive Then Return
    If $KillingGTA Then Return

    ; Send a key every 1.5 seconds
    If TimerDiff($AFKTimer) < 1500 Then Return

    Switch $AFKStep

        Case 0
            Send("{w}")

        Case 1
            Send("{a}")

        Case 2
            Send("{s}")

        Case 3
            Send("{d}")

    EndSwitch

    $AFKStep += 1

    If $AFKStep > 3 Then
        $AFKStep = 0
    EndIf

    $AFKTimer = TimerInit()

EndFunc

; -----------------------------------------------------------------------------
; START SOLO SESSION
; -----------------------------------------------------------------------------

Func goSolo()

    ; Prevent starting another solo-session operation
    If $SoloActive Then Return

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

    ; PsSuspend should be in the same folder as the script
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

        GUICtrlSetData($context, "SUSPEND FAILED")
        GUICtrlSetColor($context, 0xFF0000)

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Failed to suspend GTA." & @CRLF & @CRLF & _
            "GTAV SSA is already configured to request Administrator rights." _
        )

        ResetStatus()
        Return

    EndIf

    ; Start non-blocking countdown
    $SoloPID = $PID
    $SoloActive = True
    $SoloTimer = TimerInit()
    $LastCountdown = -1

EndFunc

; -----------------------------------------------------------------------------
; SOLO SESSION PROCESSING
; -----------------------------------------------------------------------------

Func ProcessSolo()

    If Not $SoloActive Then Return

    ; GTA disappeared while suspended
    If Not ProcessExists($SoloPID) Then

        $SoloActive = False
        $SoloPID = 0

        ResetStatus()
        Return

    EndIf

    Local $Elapsed = TimerDiff($SoloTimer)
    Local $Remaining = $SUSPEND_TIME - Int($Elapsed / 1000)

    If $Remaining < 1 Then

        ResumeGTA()
        Return

    EndIf

    ; Only update GUI if countdown number changed
    If $Remaining <> $LastCountdown Then

        $LastCountdown = $Remaining

        GUICtrlSetData($context, "RESUMING IN " & $Remaining)
        GUICtrlSetColor($context, 0xFFFFFF)

    EndIf

EndFunc

; -----------------------------------------------------------------------------
; RESUME GTA
; -----------------------------------------------------------------------------

Func ResumeGTA()

    If Not $SoloActive Then Return

    Local $PID = $SoloPID
    Local $PsSuspendPath = @ScriptDir & "\pssuspend.exe"

    ; GTA could have been killed with F12
    If Not ProcessExists($PID) Then

        $SoloActive = False
        $SoloPID = 0

        ResetStatus()
        Return

    EndIf

    GUICtrlSetData($context, "RESUMING GTA...")
    GUICtrlSetColor($context, 0x8CDD57)

    Local $ResumeResult = RunWait( _
        '"' & $PsSuspendPath & '" -r ' & $PID, _
        @ScriptDir, _
        @SW_HIDE _
    )

    $SoloActive = False
    $SoloPID = 0

    If $ResumeResult <> 0 Then

        GUICtrlSetData($context, "RESUME FAILED")
        GUICtrlSetColor($context, 0xFF0000)

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Failed to resume GTA." _
        )

    EndIf

    ResetStatus()

EndFunc

; -----------------------------------------------------------------------------
; FORCE KILL GTA
; -----------------------------------------------------------------------------

Func KillGTA()

    ; Prevent multiple kill commands simultaneously
    If $KillingGTA Then Return

    $KillingGTA = True

    Local $PID = ProcessExists($GTA_PROCESS)

    If $PID = 0 Then

        GUICtrlSetData($context, "GTA NOT FOUND")
        GUICtrlSetColor($context, 0xFF0000)

        Sleep(500)

        $KillingGTA = False
        ResetStatus()

        Return

    EndIf

    ; Disable AFK immediately
    $AFK = False

    ; Cancel solo-session countdown
    $SoloActive = False
    $SoloPID = 0

    GUICtrlSetData($context, "FORCE KILLING GTA...")
    GUICtrlSetColor($context, 0xFF0000)

    ; -------------------------------------------------------------------------
    ; PRIMARY KILL:
    ; /F = force
    ; /T = terminate child process tree
    ; -------------------------------------------------------------------------

    RunWait( _
        @ComSpec & ' /c taskkill /F /T /PID ' & $PID, _
        @ScriptDir, _
        @SW_HIDE _
    )

    ; -------------------------------------------------------------------------
    ; FALLBACK #1:
    ; Kill by executable name
    ; -------------------------------------------------------------------------

    If ProcessExists($GTA_PROCESS) Then

        RunWait( _
            @ComSpec & ' /c taskkill /F /T /IM "' & $GTA_PROCESS & '"', _
            @ScriptDir, _
            @SW_HIDE _
        )

    EndIf

    ; -------------------------------------------------------------------------
    ; FALLBACK #2:
    ; AutoIt ProcessClose
    ; -------------------------------------------------------------------------

    If ProcessExists($GTA_PROCESS) Then

        Local $FallbackPID = ProcessExists($GTA_PROCESS)

        If $FallbackPID <> 0 Then
            ProcessClose($FallbackPID)
        EndIf

    EndIf

    ; -------------------------------------------------------------------------
    ; Wait briefly for the process to disappear
    ; -------------------------------------------------------------------------

    Local $KillTimer = TimerInit()

    While ProcessExists($GTA_PROCESS)

        Sleep(50)

        If TimerDiff($KillTimer) > 3000 Then
            ExitLoop
        EndIf

    WEnd

    ; -------------------------------------------------------------------------
    ; Result + Profiles cleanup
    ; -------------------------------------------------------------------------

    If ProcessExists($GTA_PROCESS) Then

        ; Do NOT touch the Profiles folder if GTA could not be terminated.
        ; This avoids deleting files while the game may still be using them.
        GUICtrlSetData($context, "FAILED TO KILL GTA")
        GUICtrlSetColor($context, 0xFF0000)

        Sleep(1000)

    Else

        GUICtrlSetData($context, "CLEARING PROFILES...")
        GUICtrlSetColor($context, 0xFFFF00)

        Local $ProfilesCleared = ClearProfilesFolder()

        If $ProfilesCleared Then

            GUICtrlSetData($context, "GTA KILLED + PROFILES CLEARED")
            GUICtrlSetColor($context, 0x8CDD57)

        Else

            GUICtrlSetData($context, "GTA KILLED / PROFILE CLEAR FAILED")
            GUICtrlSetColor($context, 0xFF0000)

        EndIf

        Sleep(1000)

    EndIf

    $KillingGTA = False

    ResetStatus()

EndFunc

; -----------------------------------------------------------------------------
; GTA V ENHANCED PROFILES PATH
; -----------------------------------------------------------------------------

Func ResolveProfilesPath()

    ; -------------------------------------------------------------------------
    ; 1) Try the path saved for this Windows user
    ; -------------------------------------------------------------------------

    Local $SavedPath = IniRead( _
        $CONFIG_FILE, _
        $CONFIG_SECTION, _
        $CONFIG_KEY_PROFILES, _
        "" _
    )

    If IsSafeProfilesPath($SavedPath) Then
        Return NormalizePath($SavedPath)
    EndIf

    ; -------------------------------------------------------------------------
    ; 2) Try the normal/current user's Documents path dynamically
    ;
    ; Example:
    ; C:\Users\<current user>\Documents\Rockstar Games\GTAV Enhanced\Profiles
    ;
    ; @MyDocumentsDir also handles redirected Documents locations better than
    ; hardcoding C:\Users\<username>\Documents.
    ; -------------------------------------------------------------------------

    Local $DefaultPath = _
        @MyDocumentsDir & "\Rockstar Games\GTAV Enhanced\Profiles"

    If IsSafeProfilesPath($DefaultPath) Then

        SaveProfilesPath($DefaultPath)
        Return NormalizePath($DefaultPath)

    EndIf

    ; -------------------------------------------------------------------------
    ; 3) Could not detect it automatically. Ask the user once.
    ; -------------------------------------------------------------------------

    Local $Result = MsgBox( _
        BitOR($MB_ICONINFORMATION, $MB_OKCANCEL), _
        "GTAV SSA - Profiles folder", _
        "The GTA V Enhanced Profiles folder could not be detected automatically." & _
        @CRLF & @CRLF & _
        "Please select this exact folder:" & @CRLF & _
        "...\Rockstar Games\GTAV Enhanced\Profiles" & _
        @CRLF & @CRLF & _
        "The selected path will be saved for this Windows user." _
    )

    If $Result <> $IDOK Then
        Return ""
    EndIf

    While 1

        Local $SelectedPath = FileSelectFolder( _
            "Select the GTA V Enhanced Profiles folder", _
            @MyDocumentsDir, _
            0 _
        )

        If @error Or $SelectedPath = "" Then
            Return ""
        EndIf

        $SelectedPath = NormalizePath($SelectedPath)

        If IsSafeProfilesPath($SelectedPath) Then

            SaveProfilesPath($SelectedPath)
            Return $SelectedPath

        EndIf

        Local $Retry = MsgBox( _
            BitOR($MB_ICONWARNING, $MB_RETRYCANCEL), _
            "GTAV SSA - Invalid folder", _
            "For safety, GTAV SSA will only accept a folder ending in:" & _
            @CRLF & @CRLF & _
            "\Rockstar Games\GTAV Enhanced\Profiles" & _
            @CRLF & @CRLF & _
            "Selected folder:" & @CRLF & _
            $SelectedPath _
        )

        If $Retry <> $IDRETRY Then
            Return ""
        EndIf

    WEnd

EndFunc

; -----------------------------------------------------------------------------
; SAVE PROFILES PATH
; -----------------------------------------------------------------------------

Func SaveProfilesPath($Path)

    If Not IsSafeProfilesPath($Path) Then Return False

    DirCreate($CONFIG_DIR)

    Local $Result = IniWrite( _
        $CONFIG_FILE, _
        $CONFIG_SECTION, _
        $CONFIG_KEY_PROFILES, _
        NormalizePath($Path) _
    )

    Return ($Result <> 0)

EndFunc

; -----------------------------------------------------------------------------
; NORMALIZE PATH
; -----------------------------------------------------------------------------

Func NormalizePath($Path)

    Local $Result = $Path

    ; Remove trailing slash/backslash so suffix validation is deterministic.
    While StringLen($Result) > 3 And _
          (StringRight($Result, 1) = "\" Or StringRight($Result, 1) = "/")

        $Result = StringTrimRight($Result, 1)

    WEnd

    Return $Result

EndFunc

; -----------------------------------------------------------------------------
; SAFETY VALIDATION FOR DESTRUCTIVE PROFILE CLEANUP
; -----------------------------------------------------------------------------

Func IsSafeProfilesPath($Path)

    If $Path = "" Then Return False

    Local $Normalized = NormalizePath($Path)

    ; Folder must actually exist.
    If Not FileExists($Normalized) Then Return False

    ; It must be a directory, not a normal file.
    Local $Attributes = FileGetAttrib($Normalized)

    If @error Then Return False
    If StringInStr($Attributes, "D") = 0 Then Return False

    ; Important safety guard:
    ; Only a Rockstar Games\GTAV Enhanced\Profiles path can be recursively
    ; deleted by this program.
    Local $LowerPath = StringLower($Normalized)
    Local $RequiredSuffix = "\rockstar games\gtav enhanced\profiles"

    If StringLen($LowerPath) <= StringLen($RequiredSuffix) Then Return False

    If StringRight($LowerPath, StringLen($RequiredSuffix)) <> $RequiredSuffix Then
        Return False
    EndIf

    Return True

EndFunc

; -----------------------------------------------------------------------------
; CLEAR CONTENTS OF GTA V ENHANCED PROFILES
; -----------------------------------------------------------------------------

Func ClearProfilesFolder()

    ; Revalidate every single time before doing a recursive delete.
    If Not IsSafeProfilesPath($ProfilesPath) Then

        ; Saved path may have moved/disappeared since startup.
        $ProfilesPath = ResolveProfilesPath()

        If Not IsSafeProfilesPath($ProfilesPath) Then

            MsgBox( _
                $MB_ICONERROR, _
                "GTAV SSA", _
                "Profiles cleanup was skipped because a valid GTA V Enhanced" & _
                " Profiles folder could not be found." _
            )

            Return False

        EndIf

    EndIf

    Local $TargetPath = NormalizePath($ProfilesPath)

    ; -------------------------------------------------------------------------
    ; Delete the Profiles folder recursively, then immediately recreate it.
    ; This guarantees files, profile subfolders, hidden files, etc. are removed
    ; while leaving an empty Profiles directory in place for GTA.
    ; -------------------------------------------------------------------------

    Local $DeleteResult = DirRemove($TargetPath, 1)

    If $DeleteResult = 0 And FileExists($TargetPath) Then

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "Could not completely clear the Profiles folder:" & _
            @CRLF & @CRLF & _
            $TargetPath _
        )

        Return False

    EndIf

    DirCreate($TargetPath)

    If Not FileExists($TargetPath) Then

        MsgBox( _
            $MB_ICONERROR, _
            "GTAV SSA", _
            "The Profiles folder was cleared, but it could not be recreated:" & _
            @CRLF & @CRLF & _
            $TargetPath _
        )

        Return False

    EndIf

    Return True

EndFunc

; -----------------------------------------------------------------------------
; EXIT GTAV SSA
; -----------------------------------------------------------------------------

Func terminate()

    $AFK = False
    $SoloActive = False

    Exit 0

EndFunc
