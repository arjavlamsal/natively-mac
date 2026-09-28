import Foundation

/// Represents a turn in the live meeting overlay chat stream (user questions, quick action pills, and AI responses).
public struct OverlayMessage: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let role: Role
    public var text: String
    public let timestamp: Date
    public var isQuickActionLabel: Bool
    public var actionKind: String?
    public var screenshotPreview: String?
    public var isStreaming: Bool
    public var providerName: String?
    public var modelName: String?
    public var latencyMs: Double?
    
    public enum Role: String, Sendable, Equatable, Codable {
        case user
        case assistant
        case system
    }
    
    public init(
        id: String = UUID().uuidString,
        role: Role,
        text: String,
        timestamp: Date = Date(),
        isQuickActionLabel: Bool = false,
        actionKind: String? = nil,
        screenshotPreview: String? = nil,
        isStreaming: Bool = false,
        providerName: String? = nil,
        modelName: String? = nil,
        latencyMs: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.isQuickActionLabel = isQuickActionLabel
        self.actionKind = actionKind
        self.screenshotPreview = screenshotPreview
        self.isStreaming = isStreaming
        self.providerName = providerName
        self.modelName = modelName
        self.latencyMs = latencyMs
    }
}
