import Foundation

/// Health check response model.
public struct CompanionHealthResponse: Codable, Sendable {
    public let ok: Bool
    public let version: String
    public let platform: String
    public let isMeetingActive: Bool
    
    public init(ok: Bool = true, version: String = "2.0.0-native", platform: String = "darwin", isMeetingActive: Bool = false) {
        self.ok = ok
        self.version = version
        self.platform = platform
        self.isMeetingActive = isMeetingActive
    }
}

/// Extension pairing request and response models.
public struct PairResponse: Codable, Sendable {
    public let ok: Bool
    public let extToken: String
    
    public init(ok: Bool = true, extToken: String) {
        self.ok = ok
        self.extToken = extToken
    }
}

/// Incoming DOM context from the Chrome companion extension.
public struct DOMContextPayload: Codable, Sendable {
    public let title: String?
    public let url: String?
    public let text: String?
    public let dom: String?
    
    public init(title: String? = nil, url: String? = nil, text: String? = nil, dom: String? = nil) {
        self.title = title
        self.url = url
        self.text = text
        self.dom = dom
    }
}

/// WebSocket or streaming event payload.
public struct CompanionEvent: Codable, Sendable {
    public let type: String
    public let id: String?
    public let content: String?
    public let token: String?
    
    public init(type: String, id: String? = nil, content: String? = nil, token: String? = nil) {
        self.type = type
        self.id = id
        self.content = content
        self.token = token
    }
}
