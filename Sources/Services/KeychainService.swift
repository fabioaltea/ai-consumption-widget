import Foundation
import Security

enum KeychainService {
    private static let legacyService = "Claude Code-credentials"

    static func save(key: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func loadValue(service: String, account: String?) -> String? {
        guard let data = loadData(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func loadJSONValue(service: String, account: String?, path: [String]) -> String? {
        guard let data = loadData(service: service, account: account),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return stringValue(in: json, at: path)
    }

    static func loadJSONFileValue(filePath: String, path: [String]) -> String? {
        let expandedPath = NSString(string: filePath).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath)

        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return stringValue(in: json, at: path)
    }

    private static func loadData(service: String, account: String?) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let account {
            query[kSecAttrAccount as String] = account
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    enum KeychainError: Error {
        case saveFailed(OSStatus)
    }

    private static func stringValue(in json: [String: Any], at path: [String]) -> String? {
        var current: Any = json
        for key in path {
            guard let dict = current as? [String: Any], let next = dict[key] else {
                return nil
            }
            current = next
        }

        return current as? String
    }
}

extension KeychainService {
    static let sessionKey = "claude_session_key"
    static let orgId = "claude_org_id"
    static let deviceId = "claude_device_id"

    static func resolveToken(using methods: [TokenLookupMethod]) -> String? {
        for method in methods {
            switch method {
            case let .keychainJSON(service, account, path):
                let normalized = loadJSONValue(service: service, account: account, path: path)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let token = normalized, !token.isEmpty {
                    return token
                }
            case let .keychainValue(service, account):
                let normalized = loadValue(service: service, account: account)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let token = normalized, !token.isEmpty {
                    return token
                }
            case let .fileJSON(filePath, path):
                let normalized = loadJSONFileValue(filePath: filePath, path: path)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let token = normalized, !token.isEmpty {
                    return token
                }
            }
        }
        return nil
    }
}
