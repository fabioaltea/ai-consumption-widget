# Claude Consumption Widget

A macOS menu bar app that shows Claude consumption (7-day and 5-hour) directly from your local Anthropic authentication.

This project started as a small Swift experiment to explore macOS menu bar development.

## Features

- Menu bar app (`LSUIElement`)
- Reads OAuth token from Keychain (`Claude Code-credentials`)
- Calls `https://api.anthropic.com/api/oauth/usage`
- Dashboard with:
  - 7-day usage
  - 5-hour usage
  - reset time
  - UI error state
- Manual refresh + automatic refresh every 5 minutes

## Requirements

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Claude Code authenticated locally (so `Claude Code-credentials` exists in Keychain)

## Quick Start

1. Generate the Xcode project:

```bash
xcodegen generate
```

2. Build:

```bash
xcodebuild -project AIConsumptionWidget.xcodeproj -scheme AIConsumptionWidget -configuration Debug build
```

3. Run from Xcode:
- Open `AIConsumptionWidget.xcodeproj`
- Press `Cmd + R`

Or launch the Debug build directly:

```bash
open ~/Library/Developer/Xcode/DerivedData/AIConsumptionWidget-*/Build/Products/Debug/AIConsumptionWidget.app
```

## Authentication / Token

The app does not require manual token copy. It reads the token directly from macOS Keychain, following the same model used by Anthropic apps/tools.

For this reason, you must already be authenticated on your machine with Anthropic (for example via VS Code extension, desktop app, or CLI). The widget reuses that local authentication state.

Current lookup details:

- Service: `Claude Code-credentials`
- Expected payload shape:

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-..."
  }
}
```

Parsing is handled in `KeychainService.loadClaudeAccessToken()`.

## Roadmap

- Add support for OpenAI Codex usage
- Add support for GitHub Copilot usage

## API Call Location

The request is implemented in `ClaudeWebService.fetchOAuthUsage()`:

- Method: `GET`
- Endpoint: `/api/oauth/usage`
- Header: `Authorization: Bearer <accessToken>`

## Project Structure

```text
Sources/
  Models/
  Services/
  Stores/
  Views/
Resources/
project.yml
```

## Troubleshooting

### I see `Unauthorized`

- Make sure you are logged into Claude Code
- Make sure `Claude Code-credentials` exists in Keychain
- Restart the app after CLI login

### Logo is not visible

- Make sure `Resources/claude-logo.png` exists
- Regenerate project: `xcodegen generate`
- Rebuild the app

### Build warning about resources

Current configuration excludes `Resources/Info.plist` from Copy Bundle Resources to avoid duplicate copy warnings.

## Development

To modify target/build phases, update `project.yml` first, then regenerate the project with `xcodegen generate`.

## License

Add your preferred license here (MIT, Apache-2.0, etc.).
