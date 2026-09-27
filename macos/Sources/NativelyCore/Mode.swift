import Foundation

public struct Mode: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var prompt: String
    public var isCustom: Bool
    public var isActive: Bool
    public var description: String?
    public var createdAt: String?
    public var updatedAt: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        prompt: String,
        isCustom: Bool = false,
        isActive: Bool = false,
        description: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.isCustom = isCustom
        self.isActive = isActive
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AppStateItem: Codable, Sendable, Equatable {
    public let key: String
    public var value: String?

    public init(key: String, value: String? = nil) {
        self.key = key
        self.value = value
    }
}
