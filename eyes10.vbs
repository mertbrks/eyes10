' Konsol penceresi a??madan tepsi ikonunu ba??lat??r
Set sh = CreateObject("WScript.Shell")
d = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\eyes10.ps1""", 0, False
