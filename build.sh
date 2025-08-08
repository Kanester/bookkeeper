#!/bin/bash

set -e

# --- CONFIGURATION ---
APP_NAME="BookKeeper"
PACKAGE_NAME="com.xiov.bookkeeper"
ANDROID_JAR="$ANDROID_HOME/platforms/android-34/android.jar"
KEYSTORE_FILE="debug.keystore"
KEY_ALIAS="debug"
APK_NAME="app.apk"

# --- COLORS ---
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}==> 1. Building Svelte web app...${RESET}"
cd ./web || { echo -e "${RED}Web folder not found!${RESET}"; exit 1; }
pnpm build

echo -e "${GREEN}==> 2. Copying built files to assets/www...${RESET}"
mkdir -p ../android/assets/www
rm -rf ../android/assets/www/*
cp -r ./dist/* ../android/assets/www/
cd ../android || { echo -e "${RED}Android folder not found!${RESET}"; exit 1; }

# --- CLEAN & PREP ---
rm -rf build gen classes compiled
mkdir -p build gen classes compiled

# --- AAPT2 COMPILE ---
echo -e "${GREEN}==> 3. Compiling XML resources with AAPT2...${RESET}"
find res -name '*.xml' | while read -r file; do
  aapt2 compile -o compiled/ "$file"
done

# --- AAPT2 LINK ---
echo -e "${GREEN}==> 4. Linking resources and generating R.java...${RESET}"
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

# --- JAVAC ---
echo -e "${GREEN}==> 5. Compiling Java sources...${RESET}"
javac \
  --release 11 \
  -classpath "$ANDROID_JAR" \
  -d classes \
  src/com/xiov/bookkeeper/*.java gen/com/xiov/bookkeeper/R.java

# --- D8 ---
echo -e "${GREEN}==> 6. Creating classes.jar...${RESET}"
cd classes
jar cf ../build/classes.jar .
cd ..

echo -e "${GREEN}==> 7. Generating classes.dex with D8...${RESET}"
d8 \
  --lib "$ANDROID_JAR" \
  --release \
  --min-api 21 \
  --output build \
  build/classes.jar
  
# --- MERGE .DEX INTO APK ---
echo -e "${GREEN}==> 7. Merging classes.dex into APK...${RESET}"
cd build
zip -u base.apk classes.dex
cd ..

# --- ZIPALIGN ---
echo -e "${GREEN}==> 8. Aligning APK...${RESET}"
zipalign -f 4 build/base.apk build/app.unaligned.apk

# --- KEYSTORE ---
if [ ! -f "$KEYSTORE_FILE" ]; then
  echo -e "${GREEN}==> 9. Generating debug keystore...${RESET}"
  keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=BookKeeper, OU=., O=Xiov, L=., S=., C=."
fi

# --- SIGN APK ---
echo -e "${GREEN}==> 10. Signing APK...${RESET}"
apksigner sign \
  --ks "$KEYSTORE_FILE" \
  --ks-pass pass:android \
  --key-pass pass:android \
  --out "build/$APK_NAME" \
  build/app.unaligned.apk

echo -e "${GREEN}✅ Build complete! Final APK: build/$APK_NAME${RESET}"