# Installation Guide

## Option A: Download Prebuilt App (Recommended)

1. Go to the repository Releases page
2. Download `AIConsumptionWidget-macOS.zip`
3. Extract `AIConsumptionWidget.app`
4. Double click `AIConsumptionWidget.app` to open it

Optional: move it to `/Applications`.

If macOS blocks first launch, right click the app -> `Open`.

## Option B: Build Locally

## Prerequisites

- macOS 14+
- Xcode 15+
- Xcode Command Line Tools
- XcodeGen (`brew install xcodegen`)

## 1) Clone And Enter The Repository

```bash
git clone <your-repo-url>
cd ai-consumption-widget
```

## 2) Generate Xcode Project

```bash
xcodegen generate
```

## 3) Build

```bash
xcodebuild -project AIConsumptionWidget.xcodeproj -scheme AIConsumptionWidget -configuration Debug build
```

## 4) Run

From Xcode:

- Open `AIConsumptionWidget.xcodeproj`
- Press `Cmd + R`

From terminal:

```bash
open ~/Library/Developer/Xcode/DerivedData/AIConsumptionWidget-*/Build/Products/Debug/AIConsumptionWidget.app
```

## Provider Authentication Setup

The widget shows a card only when a valid token is available.

### Claude

Expected source:

- Keychain service: `Claude Code-credentials`
- JSON keys: `claudeAiOauth.accessToken`, `claudeAiOauth.refreshToken`

### GitHub Copilot

Expected source:

- Keychain service: `copilot-cli`

### Codex

Expected source:

- File: `~/.codex/auth.json`
- JSON key: `tokens.access_token`

## Create Release Package (Zip)

The repository includes a packaging script:

```bash
./scripts/package_release.sh
```

Output:

- `dist/AIConsumptionWidget-macOS.zip`

## Notes

- If you change `project.yml`, rerun `xcodegen generate`.
- If a card does not appear, verify provider authentication and restart the app.
