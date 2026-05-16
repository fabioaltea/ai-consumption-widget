import Foundation

actor CodexWebService {
    private let baseURL = "https://chatgpt.com/backend-api/wham/usage"

    func fetchUsage(bearerToken: String) async throws -> CodexUsageSnapshot {
        guard let url = URL(string: baseURL) else {
            throw AppError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
            let decoded = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
            let primaryWindow = decoded.rate_limit.primary_window
            return CodexUsageSnapshot(
                usedPercent: primaryWindow.used_percent,
                resetAt: primaryWindow.resetAtDateString,
                planType: decoded.plan_type
            )
        } catch {
            throw AppError.decodingError
        }
    }
}
