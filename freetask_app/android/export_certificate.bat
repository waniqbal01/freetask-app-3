@echo off
cd app
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -keystore upload-keystore.jks -alias upload -storepass iqbal1 -file upload_certificate.pem
cd ..
echo.
echo [OK] Certificate exported to: app\upload_certificate.pem
echo.
pause
