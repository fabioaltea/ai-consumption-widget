import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var services: [ServiceUsage] = []
    @Published var lastRefresh: Date? = nil
    @Published var loginError: String? = nil

    private let claudeService = ClaudeWebService()
    private let codexService = CodexWebService()
    private let copilotService = GitHubCopilotWebService()
    private var refreshTask: Task<Void, Never>? = nil

    private let autoRefreshInterval: TimeInterval = 300

    init() {
        Task { await refresh() }
        startAutoRefresh()
    }

    func disconnect() {
        services = []
        loginError = nil
        refreshTask?.cancel()
    }

    // MARK: - Usage fetching

    func refresh() async {
        print("[UsageStore] Starting refresh...")

        let availableProviders = discoverAvailableProviders()
        guard !availableProviders.isEmpty else {
            services = []
            loginError = "No configured providers were found on this system."
            lastRefresh = Date()
            return
        }

        applyLoadingState(for: availableProviders.map { $0.config.provider })
        loginError = nil

        for entry in availableProviders {
            await refreshProvider(config: entry.config, token: entry.token)
        }

        if services.allSatisfy({ $0.error != nil }) {
            loginError = "Found configured providers, but failed to fetch usage data."
        }

        lastRefresh = Date()
    }

    // MARK: - Helpers

    private func discoverAvailableProviders() -> [(config: ProviderConfig, token: String)] {
        ProviderRegistry.configuredProviders
            .filter { $0.isEnabled }
            .compactMap { config in
                guard let token = KeychainService.resolveToken(using: config.tokenLookupMethods) else {
                    return nil
                }
                return (config: config, token: token)
            }
    }

    private func applyLoadingState(for providers: [ProviderKind]) {
        services = providers.map { provider in
            ServiceUsage(
                id: UUID(),
                serviceName: provider.displayName,
                iconName: provider.iconName,
                inputTokens: 0,
                outputTokens: 0,
                monthlyTokenLimit: 100,
                costUSD: 0,
                lastUpdated: Date(),
                primaryMetricLabel: "7-Day Usage",
                primaryMetricValue: "0%",
                secondaryMetricLabel: "5-Hour Usage",
                secondaryMetricValue: "0%",
                isLoading: true
            )
        }
    }

    private func refreshProvider(config: ProviderConfig, token: String) async {
        switch config.provider {
        case .claude:
            do {
                let snapshot = try await claudeService.fetchUsage(bearerToken: token)
                updateClaudeUsage(from: snapshot)
            } catch {
                setProviderError(name: config.provider.displayName, message: error.localizedDescription)
            }
        case .githubCopilot:
            do {
                let snapshot = try await copilotService.fetchUsage(bearerToken: token)
                updateGitHubCopilotUsage(from: snapshot)
            } catch {
                setProviderError(name: config.provider.displayName, message: error.localizedDescription)
            }
        case .codex:
            do {
                let snapshot = try await codexService.fetchUsage(bearerToken: token)
                updateCodexUsage(from: snapshot)
            } catch {
                setProviderError(name: config.provider.displayName, message: error.localizedDescription)
            }
        }
    }

    private func setProviderError(name: String, message: String) {
        if let idx = services.firstIndex(where: { $0.serviceName == name }) {
            services[idx].isLoading = false
            services[idx].error = message
        }
    }

    private func updateClaudeUsage(from snapshot: ClaudeUsageSnapshot) {
        let now = Date()
        let sevenDayPercent = snapshot.sevenDayUtilization
        let fiveHourPercent = snapshot.fiveHourUtilization

        if let idx = services.firstIndex(where: { $0.serviceName == "Claude" }) {
            services[idx].inputTokens = Int(sevenDayPercent)
            services[idx].outputTokens = Int(fiveHourPercent)
            services[idx].monthlyTokenLimit = 100
            services[idx].lastUpdated = now
            services[idx].isLoading = false
            services[idx].error = nil
            services[idx].resetDate = snapshot.sevenDayResetAt
            services[idx].secondaryResetDate = snapshot.fiveHourResetAt
            services[idx].usageRatioOverride = sevenDayPercent / 100
            services[idx].primaryMetricLabel = "7-Day Usage"
            services[idx].primaryMetricValue = "\(Int(sevenDayPercent.rounded()))%"
            services[idx].secondaryMetricLabel = "5-Hour Usage"
            services[idx].secondaryMetricValue = "\(Int(fiveHourPercent.rounded()))%"
            services[idx].detailText = nil
        } else {
            services.append(ServiceUsage(
                id: UUID(),
                serviceName: "Claude",
                iconName: "brain",
                inputTokens: Int(sevenDayPercent),
                outputTokens: Int(fiveHourPercent),
                monthlyTokenLimit: 100,
                costUSD: 0,
                lastUpdated: now,
                resetDate: snapshot.sevenDayResetAt,
                secondaryResetDate: snapshot.fiveHourResetAt,
                usageRatioOverride: sevenDayPercent / 100,
                primaryMetricLabel: "7-Day Usage",
                primaryMetricValue: "\(Int(sevenDayPercent.rounded()))%",
                secondaryMetricLabel: "5-Hour Usage",
                secondaryMetricValue: "\(Int(fiveHourPercent.rounded()))%",
                detailText: nil
            ))
        }
    }

    private func updateGitHubCopilotUsage(from snapshot: GitHubCopilotUsageSnapshot) {
        let now = Date()
        let remainingPercent = min(max(snapshot.percentRemaining, 0), 100)
        let consumedPercent = 100 - remainingPercent
        let consumedRequests = max(snapshot.entitlement - snapshot.remaining, 0)
        let entitlement = max(snapshot.entitlement, 1)

        if let idx = services.firstIndex(where: { $0.serviceName == "GitHub Copilot" }) {
            services[idx].inputTokens = consumedRequests
            services[idx].outputTokens = 0
            services[idx].monthlyTokenLimit = entitlement
            services[idx].lastUpdated = now
            services[idx].isLoading = false
            services[idx].error = nil
            services[idx].resetDate = snapshot.quotaResetDate
            services[idx].secondaryResetDate = nil
            services[idx].usageRatioOverride = consumedPercent / 100
            services[idx].primaryMetricLabel = "Percentage"
            services[idx].primaryMetricValue = String(format: "%.1f%%", consumedPercent)
            services[idx].secondaryMetricLabel = "Requests"
            services[idx].secondaryMetricValue = "\(consumedRequests)/\(entitlement)"
            services[idx].detailText = "Premium quota consumption"
        }
    }

    private func updateCodexUsage(from snapshot: CodexUsageSnapshot) {
        let now = Date()
        let usedPercent = min(max(snapshot.usedPercent, 0), 100)
        let planText = snapshot.planType.map { "\($0.capitalized) plan" } ?? "Codex usage"

        if let idx = services.firstIndex(where: { $0.serviceName == "Codex" }) {
            services[idx].inputTokens = Int(usedPercent.rounded())
            services[idx].outputTokens = 0
            services[idx].monthlyTokenLimit = 100
            services[idx].lastUpdated = now
            services[idx].isLoading = false
            services[idx].error = nil
            services[idx].resetDate = snapshot.resetAt
            services[idx].secondaryResetDate = nil
            services[idx].usageRatioOverride = usedPercent / 100
            services[idx].primaryMetricLabel = "Weekly Usage"
            services[idx].primaryMetricValue = "\(Int(usedPercent.rounded()))%"
            services[idx].secondaryMetricLabel = "Plan"
            services[idx].secondaryMetricValue = planText
            services[idx].detailText = "ChatGPT Codex usage"
        }
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.autoRefreshInterval ?? 300) * 1_000_000_000))
                if !Task.isCancelled {
                    await self?.refresh()
                }
            }
        }
    }
}
