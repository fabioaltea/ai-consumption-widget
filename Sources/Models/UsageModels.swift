import Foundation

struct ServiceUsage: Identifiable, Equatable {
    let id: UUID
    var serviceName: String
    var iconName: String
    var inputTokens: Int
    var outputTokens: Int
    var monthlyTokenLimit: Int
    var costUSD: Double
    var currency: String = "USD"
    var lastUpdated: Date
    var resetDate: String? = nil
    var secondaryResetDate: String? = nil
    var usageRatioOverride: Double? = nil
    var primaryMetricLabel: String = "Used"
    var primaryMetricValue: String? = nil
    var secondaryMetricLabel: String = "Limit"
    var secondaryMetricValue: String? = nil
    var detailText: String? = nil
    var isLoading: Bool = false
    var error: String? = nil

    var totalTokens: Int { inputTokens + outputTokens }

    var usageRatio: Double {
        if let usageRatioOverride {
            return min(max(usageRatioOverride, 0), 1.0)
        }
        guard monthlyTokenLimit > 0 else { return 0 }
        return min(Double(totalTokens) / Double(monthlyTokenLimit), 1.0)
    }
}

struct AnthropicOAuthUsageResponse: Codable {
    let five_hour: UsagePeriod?
    let seven_day: UsagePeriod?
    let seven_day_oauth_apps: UsagePeriod?
    let seven_day_opus: UsagePeriod?
    let seven_day_sonnet: UsagePeriod?
    let seven_day_cowork: UsagePeriod?
    let seven_day_omelette: UsagePeriod?
    let tangelo: UsagePeriod?
    let iguana_necktie: UsagePeriod?
    let omelette_promotional: UsagePeriod?
    let extra_usage: ExtraUsage?
}

struct UsagePeriod: Codable {
    let utilization: Double
    let resets_at: String?
}

struct ExtraUsage: Codable {
    let is_enabled: Bool
    let monthly_limit: Int?
    let used_credits: Double?
    let utilization: Double?
    let currency: String?
}

struct ClaudeUsageSnapshot {
    let fiveHourUtilization: Double
    let fiveHourResetAt: String?
    let sevenDayUtilization: Double
    let sevenDayResetAt: String?
    let extraUsageEnabled: Bool
}

// Anthropic API responses

struct AnthropicUsageResponse: Codable {
    let data: [AnthropicUsageEntry]
}

struct AnthropicUsageEntry: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct AnthropicModel: Codable, Identifiable {
    let id: String
    let displayName: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

enum AppError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(String)
    case decodingError
    case rateLimited
    case unauthorized
    case unknownEndpoint
    case cliUnavailable
    case cliNotAuthenticated
    case usageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid API key"
        case .networkError(let msg): return "Network error: \(msg)"
        case .decodingError: return "Failed to parse response"
        case .rateLimited: return "Rate limited, retry later"
        case .unauthorized: return "Unauthorized — check Claude authentication"
        case .unknownEndpoint: return "Usage endpoint unavailable"
        case .cliUnavailable: return "Claude CLI not found. Install Claude Code and ensure the `claude` command is available."
        case .cliNotAuthenticated: return "Claude CLI is not authenticated. Open a terminal and log into `claude`, then retry."
        case .usageUnavailable: return "Unable to read Claude usage from `/usage`."
        }
    }
}
