param([string]$ToolsDirectory)
# Steam Big Picture Console Mode configuration wizard
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$KitDir = if ($ToolsDirectory) { $ToolsDirectory } else { Split-Path -LiteralPath $MyInvocation.MyCommand.Path -Parent }
$MMT = Join-Path $KitDir 'MultiMonitorTool.exe'; $SVC = Join-Path $KitDir 'SoundVolumeView.exe'

function Export-ToolCsv([string]$Exe,[string]$Csv,[string]$Columns) {
    if (-not (Test-Path -LiteralPath $Exe)) { throw "Рядом не найден $(Split-Path $Exe -Leaf)." }
    Remove-Item $Csv -Force -ErrorAction SilentlyContinue
    $argsLine='/scomma "' + $Csv + '"'
    if ($Columns) {$argsLine+=' /Columns "' + $Columns + '"'}
    Start-Process -FilePath $Exe -ArgumentList $argsLine -Wait -WindowStyle Hidden | Out-Null
    if (-not (Test-Path $Csv)) {throw "Не удалось получить список из $(Split-Path $Exe -Leaf)."}
    @(Import-Csv -LiteralPath $Csv)
}
function Field($o,[string[]]$names) { foreach($n in $names){if($o.PSObject.Properties.Name -contains $n){return [string]$o.$n}}; '' }

$form=New-Object Windows.Forms.Form
$form.Text='Steam Big Picture by Kovrov Team — v1.0'; $form.Size=New-Object Drawing.Size(850,740); $form.MinimumSize=New-Object Drawing.Size(760,700); $form.StartPosition='CenterScreen'; $form.Font=New-Object Drawing.Font('Segoe UI',9)
$intro=New-Object Windows.Forms.Label; $intro.Text='Выберите мониторы, которые выключать в Big Picture, и аудиовыход для телевизора. Мастер соберёт установочный комплект под вашу конфигурацию.'; $intro.Location=New-Object Drawing.Point(18,14); $intro.Size=New-Object Drawing.Size(800,42); $form.Controls.Add($intro)
$ml=New-Object Windows.Forms.Label; $ml.Text='МОНИТОРЫ  ·  отметьте отключаемые в Big Picture'; $ml.Location=New-Object Drawing.Point(20,66); $ml.Size=New-Object Drawing.Size(790,24); $ml.Font=New-Object Drawing.Font('Segoe UI Semibold',10); $form.Controls.Add($ml)
$monList=New-Object Windows.Forms.CheckedListBox; $monList.Location=New-Object Drawing.Point(20,94); $monList.Size=New-Object Drawing.Size(790,220); $monList.CheckOnClick=$true; $monList.HorizontalScrollbar=$true; $form.Controls.Add($monList)
$al=New-Object Windows.Forms.Label; $al.Text='АУДИО  ·  выберите устройство для каждой системной роли'; $al.Location=New-Object Drawing.Point(20,330); $al.Size=New-Object Drawing.Size(790,24); $al.Font=New-Object Drawing.Font('Segoe UI Semibold',10); $form.Controls.Add($al)
$audioBoxes=@(); $roles=@(@('Console','Основной звук (Console)'),@('Multimedia','Мультимедиа'),@('Communications','Связь'))
for($i=0;$i -lt 3;$i++){ $y=360+($i*54); $lab=New-Object Windows.Forms.Label; $lab.Text=$roles[$i][1]; $lab.Location=New-Object Drawing.Point(20,$y); $lab.Size=New-Object Drawing.Size(210,25); $form.Controls.Add($lab); $box=New-Object Windows.Forms.ComboBox; $box.Location=[Drawing.Point]::new(230,($y-3)); $box.Size=New-Object Drawing.Size(580,30); $box.DropDownStyle='DropDownList'; $form.Controls.Add($box); $audioBoxes+=$box }
$status=New-Object Windows.Forms.Label; $status.Location=New-Object Drawing.Point(20,530); $status.Size=New-Object Drawing.Size(790,55); $status.ForeColor=[Drawing.Color]::DimGray; $form.Controls.Add($status)
$refresh=New-Object Windows.Forms.Button; $refresh.Text='Обновить устройства'; $refresh.Location=New-Object Drawing.Point(20,600); $refresh.Size=New-Object Drawing.Size(160,34); $form.Controls.Add($refresh)
$generate=New-Object Windows.Forms.Button; $generate.Text='Создать установочный комплект'; $generate.Location=New-Object Drawing.Point(500,640); $generate.Size=New-Object Drawing.Size(310,42); $generate.BackColor=[Drawing.Color]::FromArgb(25,105,180); $generate.ForeColor=[Drawing.Color]::White; $generate.FlatStyle='Flat'; $form.Controls.Add($generate)
$close=New-Object Windows.Forms.Button; $close.Text='Закрыть'; $close.Location=New-Object Drawing.Point(390,640); $close.Size=New-Object Drawing.Size(100,42); $close.Add_Click({$form.Close()}); $form.Controls.Add($close)
$script:Monitors=@(); $script:Audio=@()
$refresh.Add_Click({try{
    $status.Text='Сканирование устройств…'; $form.Refresh()
    $rows=Export-ToolCsv $MMT (Join-Path $env:TEMP 'sbp_monitors.csv') $null; $monList.Items.Clear(); $script:Monitors=@()
    foreach($m in $rows){$id=Field $m @('Monitor ID'); $display=Field $m @('Name'); $name=Field $m @('Monitor Name'); $sn=Field $m @('Monitor Serial Number'); $disconnected=Field $m @('Disconnected'); if($disconnected -match '^(Yes|True|1)$'){continue}; if(-not $id -and -not $display){continue}; if(-not $name){$name='Монитор'}; $label="$name · $display"; if($sn){$label+=" · S/N $sn"}; if($id){$label+=" · $id"}; $script:Monitors+=([pscustomobject]@{Label=$label;Id=$id;Display=$display;Name=$name;Serial=$sn}); [void]$monList.Items.Add($label,$false)}
    $rows=Export-ToolCsv $SVC (Join-Path $env:TEMP 'sbp_audio.csv') 'Name,Command-Line Friendly ID,Direction,Device State,Default,Default Multimedia,Default Communications'; foreach($box in $audioBoxes){$box.Items.Clear()}; $script:Audio=@()
    foreach($a in $rows){$id=Field $a @('Command-Line Friendly ID'); $direction=Field $a @('Direction'); if(-not $direction -and $id -match '\\Render$'){$direction='Render'}; if($direction -ne 'Render' -or -not $id -or $id -match '\\Application\\|\\Subunit\\'){continue}; $name=Field $a @('Name'); $c0=(Field $a @('Default')) -eq 'Render'; $c1=(Field $a @('Default Multimedia')) -eq 'Render'; $c2=(Field $a @('Default Communications')) -eq 'Render'; $current=''; if($c0 -or $c1 -or $c2){$current=' · текущее'}; $item=[pscustomobject]@{Label="$name$current · $id";Id=$id;Name=$name;IsConsole=$c0;IsMultimedia=$c1;IsCommunications=$c2}; $index=$script:Audio.Count; $script:Audio+=$item; foreach($box in $audioBoxes){[void]$box.Items.Add($item.Label)}; if($c0){$audioBoxes[0].SelectedIndex=$index};if($c1){$audioBoxes[1].SelectedIndex=$index};if($c2){$audioBoxes[2].SelectedIndex=$index}}
    foreach($box in $audioBoxes){if($box.Items.Count -and $box.SelectedIndex -lt 0){$box.SelectedIndex=0}}; $status.Text="Мониторов: $($script:Monitors.Count). Устройств воспроизведения: $($script:Audio.Count). По умолчанию выбраны текущие аудиоустройства Windows, которые можно изменить. После Big Picture текущие роли автоматически восстановятся. Для физического выключения нужен DDC/CI."
}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Ошибка обнаружения','OK','Error')|Out-Null; $status.Text='Проверьте наличие оригинальных NirSoft EXE рядом с мастером.'}})

$generate.Add_Click({try{
    if(-not $script:Monitors.Count){throw 'Сначала обновите список мониторов.'}; foreach($box in $audioBoxes){if($box.SelectedIndex -lt 0){throw 'Выберите аудиоустройства для всех трёх ролей.'}}
    foreach($f in @($MMT,$SVC)){if(-not(Test-Path $f)){throw "Не найден $(Split-Path $f -Leaf)."}}
    $selected=@(); for($i=0;$i -lt $monList.Items.Count;$i++){if($monList.GetItemChecked($i)){$selected+=$script:Monitors[$i]}}; if(-not $selected.Count){throw 'Отметьте хотя бы один монитор для отключения.'}
    $audio=[ordered]@{Console=$script:Audio[$audioBoxes[0].SelectedIndex];Multimedia=$script:Audio[$audioBoxes[1].SelectedIndex];Communications=$script:Audio[$audioBoxes[2].SelectedIndex]}; $dir=Join-Path $KitDir 'GeneratedSetup'; New-Item -ItemType Directory -Path $dir -Force|Out-Null
    $config=[ordered]@{MonitorsToTurnOff=$selected;BigPictureAudio=$audio;EnterConfirmSeconds=3;ExitConfirmSeconds=5}; Set-Content (Join-Path $dir 'SetupConfig.json') ($config|ConvertTo-Json -Depth 6) -Encoding UTF8
    Set-Content (Join-Path $dir 'SteamBigPicture.ps1') $script:Runtime -Encoding UTF8; Set-Content (Join-Path $dir 'SteamBigPictureMonitor.vbs') $script:Vbs -Encoding ASCII
    Copy-Item $MMT (Join-Path $dir 'MultiMonitorTool.exe') -Force; Copy-Item $SVC (Join-Path $dir 'SoundVolumeView.exe') -Force
    Set-Content (Join-Path $dir 'ApplySetup.cmd') $script:SetupCmd -Encoding ASCII
    $zip=Join-Path $KitDir 'SteamBigPicture-ConfiguredKit.zip'; Compress-Archive -Path (Join-Path $dir '*') -DestinationPath $zip -Force
    [Windows.Forms.MessageBox]::Show("Комплект готов:`r`n$dir`r`n`r`nВ архиве: $zip`r`nЗапустите ApplySetup.cmd для установки.",'Комплект создан','OK','Information')|Out-Null; Start-Process explorer.exe -ArgumentList "`"$dir`""
}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Не удалось создать комплект','OK','Warning')|Out-Null}})

$script:Vbs=@'
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Tools\MultiMonitorTool\SteamBigPicture.ps1""", 0, False
'@
$script:SetupCmd=@'
@echo off
setlocal
title Steam Big Picture - Apply configuration
set "KIT=%~dp0"
set "DEST=C:\Tools\MultiMonitorTool"
set "BACKUP="
if not exist "%KIT%MultiMonitorTool.exe" goto missing
if not exist "%KIT%SoundVolumeView.exe" goto missing
if not exist "%KIT%SteamBigPicture.ps1" goto missing
if not exist "%KIT%SetupConfig.json" goto missing
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=@((Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath,(Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath,(Get-ItemProperty 'HKLM:\SOFTWARE\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath,($env:ProgramFiles+'\Steam'),(${env:ProgramFiles(x86)}+'\Steam')); if(-not ($p|Where-Object {$_ -and (Test-Path (Join-Path $_ 'steam.exe'))})){exit 7}"
if errorlevel 1 (echo Steam was not found. Install and launch Steam once, then retry.& pause & exit /b 1)
if exist "%DEST%" (
  for /f %%i in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%i"
  set "BACKUP=%DEST%\backup-%STAMP%"
  mkdir "%BACKUP%" 2>nul
  robocopy "%DEST%" "%BACKUP%" /E /XD "%DEST%\backup-*" >nul
)
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%KIT%MultiMonitorTool.exe" "%DEST%\" >nul
copy /y "%KIT%SoundVolumeView.exe" "%DEST%\" >nul
copy /y "%KIT%SteamBigPicture.ps1" "%DEST%\" >nul
copy /y "%KIT%SteamBigPictureMonitor.vbs" "%DEST%\" >nul
copy /y "%KIT%SetupConfig.json" "%DEST%\" >nul
set "REGFILE=%TEMP%\SteamBigPictureMonitor-%RANDOM%.reg"
>"%REGFILE%" echo Windows Registry Editor Version 5.00
>>"%REGFILE%" echo.
>>"%REGFILE%" echo [HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run]
>>"%REGFILE%" echo "SteamBigPictureMonitor"="wscript.exe \"C:\\Tools\\MultiMonitorTool\\SteamBigPictureMonitor.vbs\""
reg import "%REGFILE%" >nul
del "%REGFILE%" >nul 2>nul
if errorlevel 1 (echo Could not create Windows autostart entry.& pause & exit /b 1)
start "" wscript.exe "C:\Tools\MultiMonitorTool\SteamBigPictureMonitor.vbs"
timeout /t 3 /nobreak >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if(-not (Get-CimInstance Win32_Process | Where-Object {$_.CommandLine -like '*SteamBigPicture.ps1*'})){exit 1}"
if errorlevel 1 (echo Installed, but monitor service did not start. Check C:\Tools\MultiMonitorTool\SteamBigPicture.log.& pause & exit /b 1)
echo.
echo Setup complete. Press PS to launch Big Picture.
echo Log: C:\Tools\MultiMonitorTool\SteamBigPicture.log
if defined BACKUP echo Previous files backed up to: %BACKUP%
pause
exit /b 0
:missing
echo This setup kit is incomplete. Keep all generated files together.
pause
exit /b 1
'@

$script:Runtime=@'
$ErrorActionPreference='Continue'
$Root='C:\Tools\MultiMonitorTool'; $MMT=Join-Path $Root 'MultiMonitorTool.exe'; $SVC=Join-Path $Root 'SoundVolumeView.exe'; $ConfigPath=Join-Path $Root 'SetupConfig.json'; $LogFile=Join-Path $Root 'SteamBigPicture.log'
$Config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json; $GamingMode=$false; $SavedAudio=@{}
$Mutex=New-Object Threading.Mutex($false,'Local\SteamBigPictureMonitor'); if(-not $Mutex.WaitOne(0,$false)){exit 0}
function Log([string]$Message){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"|Out-File -LiteralPath $LogFile -Append -Encoding UTF8}
function Is-BigPicture{return [bool](Get-Process steamwebhelper -ErrorAction SilentlyContinue|Where-Object{$_.MainWindowTitle -and ($_.MainWindowTitle -like '*Big Picture*' -or $_.MainWindowTitle -like '*Режим Big Picture*')})}
function Save-Audio{$csv=Join-Path $Root 'audio_current.csv'; Remove-Item $csv -Force -ErrorAction SilentlyContinue; & $SVC /scomma $csv /Columns 'Name,Command-Line Friendly ID,Default,Default Multimedia,Default Communications'|Out-Null; if(-not(Test-Path $csv)){return $false}; try{$rows=Import-Csv $csv}catch{return $false}; $script:SavedAudio=@{}; foreach($r in $rows){$id=$r.'Command-Line Friendly ID';if(-not$id){continue};if($r.Default -eq 'Render'){$script:SavedAudio.Console=$id};if($r.'Default Multimedia' -eq 'Render'){$script:SavedAudio.Multimedia=$id};if($r.'Default Communications' -eq 'Render'){$script:SavedAudio.Communications=$id}}; return ($script:SavedAudio.Count -gt 0)}
function Restore-Audio{foreach($role in @('Console','Multimedia','Communications')){if($script:SavedAudio.ContainsKey($role)){$num=@{Console=0;Multimedia=1;Communications=2}[$role];& $SVC /SetDefault $script:SavedAudio[$role] $num|Out-Null;Log "$role audio restored: $($script:SavedAudio[$role])"}}}
function Set-BigPicture-Audio{foreach($role in @('Console','Multimedia','Communications')){$num=@{Console=0;Multimedia=1;Communications=2}[$role];$id=$Config.BigPictureAudio.$role.Id;if($id){& $SVC /SetDefault $id $num|Out-Null;Log "$role Big Picture audio set: $id"}}}
Log 'Monitor service started.'
while($true){
 if(-not$GamingMode -and (Is-BigPicture)){Log 'Big Picture detected; confirming.';Start-Sleep -Seconds ([int]$Config.EnterConfirmSeconds);if(Is-BigPicture){if(Save-Audio){foreach($m in $Config.MonitorsToTurnOff){$selector=if($m.Id){$m.Id}else{$m.Display};if($selector){& $MMT /TurnOff $selector|Out-Null;Log "Turned off $($m.Label)"}};Set-BigPicture-Audio}else{Log 'Could not capture current audio defaults; audio switch skipped.'};$GamingMode=$true}}
 elseif($GamingMode -and -not(Is-BigPicture)){Log 'Big Picture closed; confirming.';Start-Sleep -Seconds ([int]$Config.ExitConfirmSeconds);if(-not(Is-BigPicture)){foreach($m in $Config.MonitorsToTurnOff){$selector=if($m.Id){$m.Id}else{$m.Display};if($selector){& $MMT /TurnOn $selector|Out-Null;Log "Turned on $($m.Label)"}};Start-Sleep -Seconds 1;Restore-Audio;$GamingMode=$false}}
 Start-Sleep -Seconds 1
}
'@
$form.Add_Shown({$refresh.PerformClick()}); [void]$form.ShowDialog()
