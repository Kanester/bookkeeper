#!/bin/bash

set -e

# ========================
# CONFIGURATION (DEBUG ONLY)
# ========================
APP_NAME="BookKeeper"
PACKAGE_NAME="com.xiov.bookkeeper"
ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
APK_NAME="app.apk"

# Debug keystore config
KEYSTORE_FILE="debug.keystore"
KEY_ALIAS="debug"
KS_PASS="android"
KEY_PASS="android"

# Colors
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}==> Building in DEBUG mode!${RESET}"

# ========================
# TOOL CHECKS
# ========================
for tool in aapt2 d8 apksigner zipalign pnpm javac keytool; do
  command -v $tool >/dev/null || { echo -e "${RED}Missing $tool${RESET}"; exit 1; }
done

# ========================
# Build web assets
# ========================
echo -e "${GREEN}==> Building web assets...${RESET}"
cd ./web || { echo -e "${RED}Web folder not found!${RESET}"; exit 1; }
rm -rf dist
pnpm build
mkdir -p ../android/assets/www
rm -rf ../android/assets/www/*
cp -r ./dist/* ../android/assets/www/
cd ../android || { echo -e "${RED}Android folder not found!${RESET}"; exit 1; }

# ========================
# Clean old builds
# ========================
rm -rf build gen classes compiled
mkdir -p build gen classes compiled

# ========================
# AAPT2 compile
# ========================
echo -e "${GREEN}==> Compiling XML resources...${RESET}"
find res -name '*.xml' | while read -r file; do
  aapt2 compile -o compiled/ "$file"
done

# ========================
# AAPT2 link
# ========================
echo -e "${GREEN}==> Linking resources...${RESET}"
aapt2 link \
  -I "$ANDROID_JAR" \
  --manifest AndroidManifest.xml \
  -o build/base.apk \
  -R compiled/*.flat \
  --java gen \
  --min-sdk-version 21 \
  --target-sdk-version 34 \
  -A assets \
  --auto-add-overlay

# ========================
# Compile Java
# ========================
echo -e "${GREEN}==> Compiling Java sources...${RESET}"
javac \
  --release 11 \
  -classpath "$ANDROID_JAR" \
  -d classes \
  src/com/xiov/bookkeeper/*.java gen/com/xiov/bookkeeper/R.java

# ========================
# Create classes.dex
# ========================
echo -e "${GREEN}==> Creating classes.dex...${RESET}"
cd classes
jar cf ../build/classes.jar .
cd ..
d8 \
  --lib "$ANDROID_JAR" \
  --min-api 21 \
  --output build \
  build/classes.jar

# ========================
# Merge into APK
# ========================
echo -e "${GREEN}==> Merging classes.dex into APK...${RESET}"
cd build
zip -u base.apk classes.dex
cd ..

# ========================
# Zipalign
# ========================
echo -e "${GREEN}==> Aligning APK...${RESET}"
zipalign -f 4 build/base.apk build/app.unaligned.apk

# ========================
# Keystore (Debug)
# ========================
if [ ! -f "$KEYSTORE_FILE" ]; then
  echo -e "${GREEN}==> Generating debug keystore...${RESET}"
  keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass $KS_PASS -keypass $KEY_PASS \
    -dname "CN=$APP_NAME, OU=., O=XiovCom, L=., S=., C=."
fi

# ========================
# Sign APK (Debug)
# ========================
echo -e "${GREEN}==> Signing APK (DEBUG)...${RESET}"
apksigner sign \
  --ks "$KEYSTORE_FILE" \
  --ks-pass pass:$KS_PASS \
  --key-pass pass:$KEY_PASS \
  --out "build/$APK_NAME" \
  build/app.unaligned.apk

echo -e "${GREEN}Build complete! Final APK: build/$APK_NAME${RESET}"