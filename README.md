# GTAV SSA

A lightweight AutoIt utility for **GTA V Enhanced** that provides quick hotkeys for:

* AFK movement
* Creating a solo session by temporarily suspending GTA
* Force-closing GTA
* Closing the utility itself

The application runs as a small always-on-top bar at the top-right of the screen.

## Preview
<img width="265" height="16" alt="image" src="https://github.com/user-attachments/assets/bc857315-1802-4256-84f6-27ecc5a4528a" />

Example project structure:

```text
GTAV-SSA/
├── GTAV_SSA.au3
├── GTAV_SSA.exe
├── pssuspend.exe
└── README.md
```

## Controls

| Hotkey | Function            |
| ------ | ------------------- |
| `F9`   | Toggle AFK mode     |
| `F10`  | Create Solo Session |
| `F11`  | Exit GTAV SSA       |
| `F12`  | Force-close GTA V   |

## Features

### F9 — AFK Mode

Toggles automatic movement to help prevent the game from detecting the player as inactive.

When enabled, the script periodically sends:

```text
W
A
S
D
```

Press `F9` again to disable AFK mode.

The GUI displays:

```text
F9 = AFK [ON]
```

while AFK mode is active.

### F10 — Solo Session

Temporarily suspends the GTA V process using Microsoft's `PsSuspend`.

The default suspension period is:

```text
8 seconds
```

After the countdown finishes, the process is automatically resumed.

The suspension duration can be changed in the script:

```autoit
Global Const $SUSPEND_TIME = 8
```

The utility expects the GTA V Enhanced executable to be:

```text
GTA5_Enhanced.exe
```

This can also be changed in the script:

```autoit
Global Const $GTA_PROCESS = "GTA5_Enhanced.exe"
```

### F11 — Exit

Immediately closes GTAV SSA.

This does **not** close GTA V.

### F12 — Kill GTA

Force-closes the GTA V process.

A confirmation window is displayed before the process is terminated to prevent accidental shutdowns.

If confirmed, GTAV SSA attempts to terminate:

```text
GTA5_Enhanced.exe
```

## Requirements

* Windows
* GTA V Enhanced
* AutoIt 3, if running the `.au3` source directly
* `pssuspend.exe`
* Administrator privileges may be required

## PsSuspend

The Solo Session function requires Microsoft's **PsSuspend**, which is part of the Sysinternals PsTools package.

Place:

```text
pssuspend.exe
```

in the same directory as GTAV SSA.

Example:

```text
GTAV-SSA/
├── GTAV_SSA.exe
└── pssuspend.exe
```

If `pssuspend.exe` cannot be found, GTAV SSA will display an error.

## Running the Utility

Run:

```text
GTAV_SSA.exe
```

or execute the AutoIt source:

```text
GTAV_SSA.au3
```

For process suspension or termination to work correctly, you may need to run GTAV SSA as Administrator.

Right-click the executable and select:

```text
Run as administrator
```

## GUI

GTAV SSA uses a compact always-on-top status bar.

Default state:

```text
F9 = AFK | F10 = SOLO | F12 = KILL | F11
```

The bar also changes its status text and color depending on the current operation.

Examples include:

```text
F9 = AFK [ON]
SUSPENDING GTA...
RESUMING IN 8
RESUMING GTA...
KILLING GTA...
GTA TERMINATED
GTA NOT FOUND
```

## Configuration

The primary configuration values are located near the beginning of the script.

```autoit
Global Const $GTA_PROCESS = "GTA5_Enhanced.exe"
Global Const $SUSPEND_TIME = 8
```

### Change the GTA executable

For another version of GTA V, change:

```autoit
Global Const $GTA_PROCESS = "GTA5_Enhanced.exe"
```

to the appropriate process name.

### Change the suspension duration

Change:

```autoit
Global Const $SUSPEND_TIME = 8
```

For example:

```autoit
Global Const $SUSPEND_TIME = 10
```

will suspend GTA for 10 seconds.

## Building the EXE

If AutoIt is installed, the `.au3` source can be compiled using **Aut2Exe**.

Alternatively:

1. Right-click the `.au3` file.
2. Select **Compile Script**.
3. AutoIt will generate an `.exe`.

Keep `pssuspend.exe` in the same directory as the compiled executable.

## Notes

The Solo Session function works by temporarily suspending the GTA process and then resuming it.

Because GTA V and GTA Online can change over time, functionality may depend on the current version of the game.

The AFK functionality sends normal keyboard input, meaning its behavior can depend on which application currently has keyboard focus.

## Disclaimer

This project is an independent utility and is not affiliated with, endorsed by, or associated with Rockstar Games or Take-Two Interactive.

Use it at your own discretion.
