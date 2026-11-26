# Coffee Time

**English** | [한국어](README.ko.md)

Coffee Time is a small menu bar app that keeps your Mac awake for as long as you need. Keep the display on, or let it sleep while downloads and other work continue.

Requires an Apple Silicon Mac running macOS 13 or later. Intel Macs are not supported. The app interface is currently in Korean.

## Install

Download the DMG from the [latest release](https://github.com/henrychoi7/coffee-time/releases/latest), open it, and drag Coffee Time into Applications.

The current release is not signed with an Apple Developer ID or notarized. macOS may block it on first launch. After confirming that you downloaded it from this repository, you can allow it to open in **System Settings → Privacy & Security**.

## Automatic updates

Starting with version 1.1.0, Coffee Time checks GitHub for stable releases at launch and every hour. When an update is available, it downloads the update, verifies its signature, installs it, and relaunches. Your active mode and timer carry over.

Choose **업데이트 확인…** (Check for Updates) from the menu bar to check immediately. Turn off **새 버전을 자동으로 받아 설치** in Settings if you prefer to check and install updates manually.

The update feed and archives are signed with Sparkle's Ed25519 signatures. Updates with invalid signatures are rejected. Update checks connect to GitHub; the app does not send usage records or a system profile.

**Versions 1.0.4 and earlier do not have an updater.** Install the latest DMG once to receive future updates automatically.

## Use Coffee Time

Click the coffee cup in the menu bar to choose a mode or set a timer.

| Mode | What it does |
| --- | --- |
| Buzz | Keeps your Mac and display awake |
| Doze | Keeps your Mac awake while allowing the display to sleep |
| Off | Uses your normal macOS sleep settings |

Right-click the coffee cup to cycle through Off → Buzz → Doze. You can turn this shortcut off in Settings.

A timer keeps the current mode active until the chosen time, then switches to the mode you selected. Timers can run from one minute to seven days, and you can reuse your three most recent timers. The mini window stays above other windows.

- **⌘W** closes the window and leaves the app running in the menu bar
- **⌘Q** quits the app and releases its sleep prevention

Quitting releases all sleep prevention set by Coffee Time. The app does not prevent sleep when you close the lid or choose Sleep from the Apple menu. It does not change screen lock settings or security policies.

## Automatic rules

Rules can switch modes when:

- The power adapter is connected or disconnected
- The battery falls to a chosen level
- Another app launches or quits
- The system starts

Set the delay to zero minutes for an immediate switch. If several rules match the same event, the last one in the list takes priority. A new rule action or a manual mode change replaces or cancels the current timer.

Coffee Time listens for macOS power change notifications. It falls back to checking once a second only if it cannot register for those notifications. Battery rules do not run while charging. They can run again after the battery rises above the threshold and drops back down.

### System startup rules

A startup rule runs once, when Coffee Time first launches after a reboot. Enable **로그인 시 자동 실행** (Launch at Login) to run it automatically after you log in.

Relaunching the app, logging out and back in, or waking from sleep does not run the rule again during the same boot. A startup rule added while the app is running takes effect after the next reboot. Coffee Time does not run before login.

## Notifications and display protection

When the mode changes, a notification shows the new mode and what triggered the change. Notifications require macOS permission. Focus modes and screen sharing settings may hide banners.

By default, Coffee Time switches from Buzz to Doze after 120 minutes without input. You can use elapsed time in Buzz instead of idle time, or choose a duration from 15 minutes to eight hours. This safety switch also cancels any active timer.

## Build from source

You need Xcode or Command Line Tools with the macOS SDK, plus Python 3. The first build downloads Sparkle 2.10.1 from its official release and verifies its SHA-256 checksum.

```sh
./scripts/build.sh
./scripts/test.sh
open 'dist/Coffee Time.app'
```

The app is built at `dist/Coffee Time.app`. Settings and rules are stored locally in UserDefaults. On a normal launch, the app starts in Off unless a startup rule applies. Relaunching after an automatic update restores the previous mode and timer.

See the [changelog](CHANGELOG.md), [testing guide](docs/TESTING.md), and [release guide](docs/RELEASING.md) for more details. These documents are currently in Korean.

## About the project

Coffee Time was built for Apple Silicon after Coffee Buzz became unavailable to download. It was written from scratch using publicly available feature descriptions, without copying the original app's code, icons, or resources. The original executable was not available for comparison, so some behavior may differ.

Automatic updates use [Sparkle](https://sparkle-project.org).

## License

Coffee Time is available under the [MIT License](LICENSE). You may use, modify, and redistribute it, including commercially, as long as you retain the copyright and license notices.

Sparkle and its bundled dependencies retain their own licenses. Their notices are included in [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).
