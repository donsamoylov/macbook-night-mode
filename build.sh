#!/bin/zsh
# Сборка Night Mode. Нужны только Command Line Tools.
#   ./build.sh            — собрать build/Night Mode.app
#   ./build.sh --install  — поставить в ~/Applications и в автозапуск (LaunchAgent, после падения поднимается сам)
#   ./build.sh --zip      — упаковать build/NightMode.zip для релиза
set -euo pipefail
cd "${0:A:h}"
APP="build/Night Mode.app"
LABEL=io.github.donsamoylov.nightmode
AGENT=~/Library/LaunchAgents/$LABEL.plist

rm -rf build && mkdir -p "$APP/Contents/MacOS"
swiftc -O -target arm64-apple-macos14 -framework AppKit -framework IOKit -framework SwiftUI Sources/*.swift -o "$APP/Contents/MacOS/NightMode"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --timestamp=none --sign - "$APP"
codesign --verify --strict "$APP"

if [[ ${1:-} == --zip ]]; then
  ditto -c -k --keepParent "$APP" build/NightMode.zip
  echo "Архив: build/NightMode.zip"
fi

if [[ ${1:-} == --install ]]; then
  launchctl bootout gui/$UID/$LABEL 2>/dev/null || true
  # bootout не всегда завершает процесс, а второй экземпляр спорит с новым за экран.
  pkill -x NightMode 2>/dev/null || true
  while pgrep -x NightMode >/dev/null; do sleep 0.1; done
  rm -rf ~/Applications/"Night Mode.app"
  mkdir -p ~/Applications
  cp -R "$APP" ~/Applications/
  cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$HOME/Applications/Night Mode.app/Contents/MacOS/NightMode</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<dict>
		<key>SuccessfulExit</key>
		<false/>
	</dict>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
EOF
  launchctl bootstrap gui/$UID "$AGENT"
  echo "Установлено: ~/Applications/Night Mode.app, автозапуск: $AGENT"
fi
