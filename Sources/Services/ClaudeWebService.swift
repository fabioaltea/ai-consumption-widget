import Foundation

actor ClaudeWebService {
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"
    private let tokenURL = "https://console.anthropic.com/v1/oauth/token"
    private let credentialsService = "Claude Code-credentials"
    private let oauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let credentialsFilePath = "~/.claude/.credentials.json"

    func fetchUsage(bearerToken: String) async throws -> ClaudeUsageSnapshot {
        do {
            let response = try await fetchOAuthUsage(bearerToken: bearerToken)
            return parseSnapshot(from: response)
        } catch AppError.rateLimited {
            let refreshedToken = try await refreshStoredOAuthToken()
            let response = try await fetchOAuthUsage(bearerToken: refreshedToken)
            return parseSnapshot(from: response)
        }
    }

    private func fetchOAuthUsage(bearerToken: String) async throws -> AnthropicOAuthUsageResponse {
        guard let url = URL(string: baseURL) else {
            throw AppError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

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

    private func refreshStoredOAuthToken() async throws -> String {
        let credentials = try loadStoredCredentials()

        guard let url = URL(string: tokenURL) else {
            throw AppError.networkError("Invalid refresh URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            AnthropicTokenRefreshRequest(
                grantType: "refresh_token",
                refreshToken: credentials.refreshToken,
                clientId: oauthClientId
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("No HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 400, 401:
            throw AppError.unauthorized
        default:
            throw AppError.networkError("Token refresh failed: HTTP \(httpResponse.statusCode)")
        }

        do {
            let refreshed = try JSONDecoder().decode(AnthropicTokenRefreshResponse.self, from: data)
            try persist(credentials: credentials.rawPayload, refreshedTokens: refreshed)
            return refreshed.accessToken
        } catch is DecodingError {
            throw AppError.decodingError
        }
    }

    private func loadStoredCredentials() throws -> ClaudeOAuthCredentials {
        guard let payload = KeychainService.loadJSONDictionary(service: credentialsService, account: nil),
              let oauth = payload["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String,
              !accessToken.isEmpty,
              !refreshToken.isEmpty else {
            throw AppError.unauthorized
        }

        return ClaudeOAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            rawPayload: payload
        )
    }

    private func persist(credentials rawPayload: [String: Any], refreshedTokens: AnthropicTokenRefreshResponse) throws {
        var updatedPayload = rawPayload
        var oauth = updatedPayload["claudeAiOauth"] as? [String: Any] ?? [:]

        oauth["accessToken"] = refreshedTokens.accessToken
        oauth["refreshToken"] = refreshedTokens.refreshToken
        oauth["expiresAt"] = Int64(Date().addingTimeInterval(TimeInterval(refreshedTokens.expiresIn)).timeIntervalSince1970 * 1000)

        updatedPayload["claudeAiOauth"] = oauth

        try KeychainService.saveJSONDictionary(service: credentialsService, account: nil, json: updatedPayload)
        try persistCredentialsFileIfPresent(updatedPayload)
    }

    private func persistCredentialsFileIfPresent(_ payload: [String: Any]) throws {
        let expandedPath = NSString(string: credentialsFilePath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct ClaudeOAuthCredentials {
    let accessToken: String
    let refreshToken: String
    let rawPayload: [String: Any]
}

private struct AnthropicTokenRefreshRequest: Encodable {
    let grantType: String
    let refreshToken: String
    let clientId: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
        case clientId = "client_id"
    }
}

private struct AnthropicTokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
