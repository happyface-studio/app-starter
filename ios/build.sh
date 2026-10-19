#!/bin/zsh
# Dev loop: pull, generate, build for the booted simulator, install and launch.
cd "$(dirname "$0")"
git pull -q --rebase --autostash
tuist generate --no-open > /tmp/spots-gen.log 2>&1 || { tail -20 /tmp/spots-gen.log; exit 1; }
SIM=${SIM:-B49E8BBA-3F4B-4D23-8E5D-A4DA339F511E}
xcodebuild -workspace Spots.xcworkspace -scheme Spots -configuration Debug \
  -destination "id=$SIM" -derivedDataPath build/dd build > /tmp/spots-build.log 2>&1
STATUS=$?
grep -E "error:|warning: .*(deprecated|unused)" /tmp/spots-build.log | grep -v "/SourcePackages/" | sort -u | head -40
if [ $STATUS -ne 0 ]; then echo "BUILD FAILED"; tail -5 /tmp/spots-build.log; exit 1; fi
APP=build/dd/Build/Products/Debug-iphonesimulator/Spots.app
xcrun simctl terminate $SIM studio.happyface.spots 2>/dev/null
xcrun simctl install $SIM $APP && xcrun simctl launch $SIM studio.happyface.spots "$@" && echo LAUNCHED
