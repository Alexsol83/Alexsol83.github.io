@echo off
setlocal
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo .NET Framework C# compiler was not found.
  pause
  exit /b 1
)
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /out:"%~dp0Steam Big Picture by Kovrov Team.exe" /resource:"%~dp0Configurator.ps1",Configurator.ps1 /reference:System.Windows.Forms.dll /reference:System.dll /reference:System.Core.dll "%~dp0SteamBigPictureLauncher.cs"
if errorlevel 1 exit /b 1
echo Built: Steam Big Picture by Kovrov Team.exe
