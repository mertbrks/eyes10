# eyes10

A tiny Windows tray tool that keeps the computer awake, even with the laptop lid closed. Similar to Insomnia / Caffeine, in one PowerShell file.

- **Left click** the eye icon: on / off (the eye opens and closes).
- **Right click**: choose a duration or quit.
- While on, it blocks sleep (`SetThreadExecutionState`) and sets the lid-close action to "do nothing". When turned off it restores your original lid setting.
- Turns itself off when the battery drops below 20% and the laptop is not charging.

## Usage

Double-click `eyes10.vbs` (starts it without a console window), or:

```
powershell -STA -ExecutionPolicy Bypass -File eyes10.ps1
powershell -File eyes10.ps1 -Test   # self-test: changes the lid setting and restores it
```
