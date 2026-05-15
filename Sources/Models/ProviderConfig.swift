import Foundation

enum ProviderKind: String, CaseIterable {
    case claude
    case codex
    case githubCopilot

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .githubCopilot:
            return "GitHub Copilot"
        }
    }

    var iconName: String {
        switch self {
        case .claude:
            return "brain"
        case .codex:
            return "terminal"
        case .githubCopilot:
            return "bolt"
        }
    }
}

enum TokenLookupMethod {
    case keychainJSON(service: String, account: String?, path: [String])
    case keychainValue(service: String, account: String?)
}

struct ProviderConfig {
    let provider: ProviderKind
    let isEnabled: Bool
    let tokenLookupMethods: [TokenLookupMethod]
}

enum ProviderRegistry {
    static let configuredProviders: [ProviderConfig] = [
        ProviderConfig(
            provider: .claude,
            isEnabled: true,
            tokenLookupMethods: [
                .keychainJSON(
                    service: "Claude Code-credentials",
                    account: nil,
                    path: ["claudeAiOauth", "accessToken"]
                )
            ]
        ),
        ProviderConfig(
            provider: .codex,
            isEnabled: false,
            tokenLookupMethods: [
                .keychainValue(service: "OpenAI Codex-credentials", account: nil)
            ]
        ),
        ProviderConfig(
            provider: .githubCopilot,
            isEnabled: true,
            tokenLookupMethods: [
                .keychainValue(service: "copilot-cli", account: nil)
            ]
        )
    ]
}
