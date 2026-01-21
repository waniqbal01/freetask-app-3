@echo off
cd app
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass iqbal1 -keypass iqbal1 -dname "CN=freetask, OU=freetask, O=freetask, L=KL, S=Selangor, C=MY"
cd ..
echo.
echo [OK] Upload keystore created!
echo.
pause
