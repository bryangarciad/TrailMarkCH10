#!/bin/zsh
# usage: build.sh <srcdir> <AppName> <bundleid> <sdk> <target-triple> <family>
set -e
SRC=$1 NAME=$2 BID=$3 SDK=$4 TRIPLE=$5 FAM=$6
APP=build/$NAME.app
[ -d $APP ] && trash $APP
mkdir -p $APP
xcrun --sdk $SDK swiftc -parse-as-library -O -target $TRIPLE -sdk $(xcrun --sdk $SDK --show-sdk-path) $SRC/*.swift -o $APP/$NAME
EXTRA=""
if [ "$SDK" = "watchsimulator" ]; then EXTRA="<key>WKApplication</key><true/><key>WKWatchOnly</key><true/>"; fi
cat > $APP/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$NAME</string>
<key>CFBundleIdentifier</key><string>$BID</string>
<key>CFBundleName</key><string>TrailMark</string>
<key>CFBundleDisplayName</key><string>TrailMark</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>26.2</string>
<key>UIDeviceFamily</key><array><integer>$FAM</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/></dict>
$EXTRA
</dict></plist>
PL
codesign -s - --force $APP >/dev/null 2>&1
echo built $APP
