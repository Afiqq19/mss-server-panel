@echo off
echo ===================================================
echo   AUTO-DEPLOY MSS SERVER PANEL FRONTEND
echo ===================================================
echo.

echo [1/3] Membangun Ulang Flutter Web (Release Mode)...
cd mss-frontend
call flutter build web --release
if %errorlevel% neq 0 (
    echo Gagal melakukan build Flutter! Pastikan Anda berada di direktori yang benar.
    pause
    exit /b %errorlevel%
)
cd ..
echo.

echo [2/3] Menyalin file bundle web ke folder mss-backend/public...
xcopy /s /e /y "mss-frontend\build\web\*" "mss-backend\public\"
echo.

echo [3/3] Mengirim (Push) pembaruan ke GitHub...
git add mss-backend/public
git commit -m "deploy(frontend): auto-build dan update UI"
git push
echo.

echo ===================================================
echo SELESAI DAN SUKSES! 🚀
echo ===================================================
echo Sekarang Bapak tinggal klik/hit link rahasia Webhook:
echo https://panel.xie.my.id/api/update-rahasia-panel?key=kunci-rahasia-mepal-2026
echo.
pause
