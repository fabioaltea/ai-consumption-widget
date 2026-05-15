import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var services: [ServiceUsage] = []
    @Published var isOnboarding: Bool = true
    @Published var lastRefresh: Date? = nil
    @Published var loginError: String? = nil

    private let claudeService = ClaudeWebService()
    private var refreshTask: Task<Void, Never>? = nil

    private let autoRefreshInterval: TimeInterval = 300

    init() {
        Task { await refresh() }
        startAutoRefresh()
    }

    func disconnect() {
        services = []
        isOnboarding = true
        loginError = nil
        refreshTask?.cancel()
    }

    // MARK: - Usage fetching

    func refresh() async {
        setClaudeLoading(true)

        do {
            print("[UsageStore] Starting refresh...")
            let snapshot = try await claudeService.fetchUsage()
            print("[UsageStore] Got snapshot: \(snapshot)")
            isOnboarding = false
            loginError = nil
            updateClaudeUsage(from: snapshot)
            print("[UsageStore] Refresh complete, services: \(services.count)")
        } catch {
            print("[UsageStore] Refresh failed: \(error)")
            let hasRealData = services.contains { !$0.isLoading && $0.error == nil }
            if !hasRealData {
                isOnboarding = true
                loginError = error.localizedDescription
                services = []
            } else {
                setClaudeError(error.localizedDescription)
            }
        }

        lastRefresh = Date()
    }

    // MARK: - Helpers

    private func setClaudeLoading(_ loading: Bool) {
        if let idx = services.firstIndex(where: { $0.serviceName == "Claude" }) {
            services[idx].isLoading = loading
            services[idx].error = nil
        } else if loading {
            services.append(ServiceUsage(
                id: UUID(),
                serviceName: "Claude",
                iconName: "brain",
                inputTokens: 0,
                outputTokens: 0,
                monthlyTokenLimit: 0,
                costUSD: 0,
                lastUpdated: Date(),
                primaryMetricValue: "0 in · 0 out",
                secondaryMetricValue: "0 read · 0 write",
                isLoading: true
            ))
        }
    }

    private func setClaudeError(_ message: String) {
        if let idx = services.firstIndex(where: { $0.serviceName == "Claude" }) {
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
