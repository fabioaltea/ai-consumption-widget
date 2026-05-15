import Foundation

actor GitHubCopilotWebService {
    private let baseURL = "https://api.github.com/copilot_internal/user"

    func fetchUsage(bearerToken: String) async throws -> GitHubCopilotUsageSnapshot {
        guard let url = URL(string: baseURL) else {
            throw AppError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("No HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AppError.unauthorized
        case 429:
            throw AppError.rateLimited
        default:
            throw AppError.networkError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(GitHubCopilotUserResponse.self, from: data)
            let premium = decoded.quota_snapshots?.premium_interactions
            let remaining = premium?.percent_remaining ?? 0
            let quotaRemaining = premium?.remaining ?? 0
            let quotaEntitlement = premium?.entitlement ?? 0

            return GitHubCopilotUsageSnapshot(
                percentRemaining: remaining,
                remaining: quotaRemaining,
                entitlement: quotaEntitlement,
                quotaResetDate: decoded.quota_reset_date
            )
        } catch {
            throw AppError.decodingError
        }
    }
}
