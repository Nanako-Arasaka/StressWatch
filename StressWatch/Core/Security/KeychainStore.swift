import Foundation
import Security

/// Keychain 统一存取入口。用于安全保存用户的 MiniMax API Key，
/// 不落 UserDefaults / 明文文件，避免 key 进入 IPA 可读区域。
enum KeychainKeys {
    static let minimaxService = "com.stresswatch.minimax"
    static let minimaxAccount = "apiKey"
}

enum KeychainStore {
    /// 保存（覆盖式）。失败返回 false。
    @discardableResult
    static func save(
        _ value: String,
        service: String = KeychainKeys.minimaxService,
        account: String = KeychainKeys.minimaxAccount
    ) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        _ = delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// 读取。不存在返回 nil。
    static func read(
        service: String = KeychainKeys.minimaxService,
        account: String = KeychainKeys.minimaxAccount
    ) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// 删除。失败返回 false。
    @discardableResult
    static func delete(
        service: String = KeychainKeys.minimaxService,
        account: String = KeychainKeys.minimaxAccount
    ) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
