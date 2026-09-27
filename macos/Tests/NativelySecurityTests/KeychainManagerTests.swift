import Testing
import Foundation
@testable import NativelySecurity

@Suite("KeychainManager Tests")
struct KeychainManagerTests {
    @Test("Keychain save, retrieve, update, and delete")
    func testKeychainLifecycle() async throws {
        let testService = "software.natively.mac.test.\(UUID().uuidString)"
        let keychain = KeychainManager(service: testService)
        let key = "test_anthropic_api_key"
        let secretValue = "sk-ant-test-secret-value-12345"

        // 1. Initial read should be nil
        let initial = try await keychain.get(key: key)
        #expect(initial == nil)

        // 2. Save
        try await keychain.save(key: key, value: secretValue)
        let saved = try await keychain.get(key: key)
        #expect(saved == secretValue)

        // 3. Update existing
        let updatedValue = "sk-ant-updated-secret-value-67890"
        try await keychain.save(key: key, value: updatedValue)
        let updated = try await keychain.get(key: key)
        #expect(updated == updatedValue)

        // 4. Delete
        try await keychain.delete(key: key)
        let afterDelete = try await keychain.get(key: key)
        #expect(afterDelete == nil)
    }
}
