import Foundation

actor ClaudeWebService {
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"
    private var bearerToken: String? { KeychainService.loadClaudeAccessToken() }
    func fetchUsage() async throws -> ClaudeUsageSnapshot {
        let response = try await fetchOAuthUsage()
        return parseSnapshot(from: response)
    }

    private func fetchOAuthUsage() async throws -> AnthropicOAuthUsageResponse {
        guard let url = URL(string: baseURL) else {
            throw AppError.networkError("Invalid URL")
        }

        guard let token = bearerToken else {
            throw AppError.unauthorized
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("[ClaudeWebService] Fetching from: \(baseURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("[ClaudeWebService] Got response")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("No HTTP response")
        }

        print("[ClaudeWebService] Status: \(httpResponse.statusCode)")
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
            let decoded = try JSONDecoder().decode(AnthropicOAuthUsageResponse.self, from: data)
            print("[ClaudeWebService] Successfully decoded response")
            return decoded
        } catch {
            if let raw = String(data: data, encoding: .utf8) {
                print("[ClaudeWebService] Raw response: \(raw)")
            }
            print("[ClaudeWebService] Decode error: \(error)")
            throw AppError.decodingError
        }
    }

    private func parseSnapshot(from response: AnthropicOAuthUsageResponse) -> ClaudeUsageSnapshot {
        let fiveHourUtil = response.five_hour?.utilization ?? 0.0
        let fiveHourReset = response.five_hour?.resets_at
        let sevenDayUtil = response.seven_day?.utilization ?? 0.0
        let sevenDayReset = response.seven_day?.resets_at

        return ClaudeUsageSnapshot(
            fiveHourUtilization: fiveHourUtil,
            fiveHourResetAt: fiveHourReset,
            sevenDayUtilization: sevenDayUtil,
            sevenDayResetAt: sevenDayReset,
            extraUsageEnabled: response.extra_usage?.is_enabled ?? false
        )
    }
}
