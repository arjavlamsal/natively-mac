import Foundation
import Network
import NativelyCore
import NativelySecurity

/// High-performance local companion micro-server using Apple's Network.framework.
/// Handles Chrome extension context capture (/dom), pairing (/pair), and health checks (/healthz).
/// Enforces loopback interface isolation, origin validation, payload size bounds, and token authentication.
public final class CompanionServer: @unchecked Sendable {
    public let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.natively.companion.server", qos: .userInitiated)
    
    // Server state
    public private(set) var isRunning: Bool = false
    public var isMeetingActive: Bool = false
    public var pairingToken: String
    public var requireAuth: Bool = false
    
    // Callbacks
    public var onDOMCaptured: (@Sendable (DOMContextPayload) -> Void)?
    
    public init(port: UInt16 = 4123, pairingToken: String? = nil, requireAuth: Bool = false) {
        self.port = port
        self.pairingToken = pairingToken ?? UUID().uuidString
        self.requireAuth = requireAuth
    }
    
    /// Starts the NWListener TCP service bound strictly to the loopback interface.
    public func start() throws {
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback
        
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "CompanionServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid port \(port)"])
        }
        
        let nwListener = try NWListener(using: parameters, on: endpointPort)
        
        nwListener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
            case .failed(let error):
                self?.isRunning = false
                print("[CompanionServer] Listener failed: \(error)")
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        
        nwListener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        nwListener.start(queue: queue)
        self.listener = nwListener
        self.isRunning = true
    }
    
    /// Stops the micro-server.
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveData(on: connection, buffer: Data())
    }
    
    private func receiveData(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var currentBuffer = buffer
            
            if let data = data, !data.isEmpty {
                currentBuffer.append(data)
                
                // DoS Protection: Cap incoming request buffer at 1MB
                if currentBuffer.count > 1_048_576 {
                    let response = self.makeHTTPResponse(status: 413, statusText: "Payload Too Large", body: #"{"ok":false,"error":"Payload exceeds 1MB limit"}"#)
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    return
                }
                
                if let requestString = String(data: currentBuffer, encoding: .utf8) {
                    if let headerEnd = requestString.range(of: "\r\n\r\n") {
                        let headersSection = String(requestString[..<headerEnd.lowerBound])
                        let bodySection = String(requestString[headerEnd.upperBound...])
                        
                        var contentLength = 0
                        for line in headersSection.components(separatedBy: "\r\n") {
                            let lower = line.lowercased()
                            if lower.hasPrefix("content-length:") {
                                contentLength = Int(line.dropFirst(15).trimmingCharacters(in: .whitespaces)) ?? 0
                            }
                        }
                        
                        if bodySection.utf8.count >= contentLength {
                            let response = self.routeRequest(requestString)
                            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                            return
                        }
                    }
                }
            }
            
            if isComplete || error != nil {
                if !currentBuffer.isEmpty, let requestString = String(data: currentBuffer, encoding: .utf8) {
                    let response = self.routeRequest(requestString)
                    connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                } else {
                    connection.cancel()
                }
            } else {
                self.receiveData(on: connection, buffer: currentBuffer)
            }
        }
    }
    
    /// Internal HTTP request router with security checks.
    public func routeRequest(_ rawHTTP: String) -> String {
        let lines = rawHTTP.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return makeHTTPResponse(status: 400, statusText: "Bad Request", body: "{}")
        }
        
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return makeHTTPResponse(status: 400, statusText: "Bad Request", body: "{}")
        }
        
        let method = String(parts[0]).uppercased()
        let rawPath = String(parts[1])
        let path = rawPath.components(separatedBy: "?").first ?? "/"
        
        // Parse HTTP headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let headerParts = line.split(separator: ":", maxSplits: 1)
            if headerParts.count == 2 {
                let key = headerParts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let val = headerParts[1].trimmingCharacters(in: .whitespaces)
                headers[key] = val
            }
        }
        
        let origin = headers["origin"]
        let isTrustedOrigin = validateOrigin(origin)
        
        // CORS preflight
        if method == "OPTIONS" {
            guard isTrustedOrigin else {
                return makeHTTPResponse(status: 403, statusText: "Forbidden", body: #"{"error":"Forbidden origin"}"#, origin: nil)
            }
            let allowOrigin = origin ?? "*"
            return "HTTP/1.1 204 No Content\r\n" +
                   "Access-Control-Allow-Origin: \(allowOrigin)\r\n" +
                   "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                   "Access-Control-Allow-Headers: Content-Type, Authorization, X-Natively-Token\r\n" +
                   "Connection: close\r\n\r\n"
        }
        
        // Reject untrusted origin if present
        if origin != nil && !isTrustedOrigin {
            return makeHTTPResponse(status: 403, statusText: "Forbidden", body: #"{"ok":false,"error":"Forbidden origin"}"#, origin: nil)
        }
        
        // 1. Health check
        if path == "/healthz" && method == "GET" {
            let health = CompanionHealthResponse(
                ok: true,
                version: "2.0.0-native",
                platform: "darwin",
                isMeetingActive: isMeetingActive
            )
            let json = (try? String(data: JSONEncoder().encode(health), encoding: .utf8)) ?? "{}"
            return makeHTTPResponse(status: 200, statusText: "OK", body: json, origin: origin)
        }
        
        // 2. Extension Pairing
        if path == "/pair" && (method == "POST" || method == "GET") {
            let pairResp = PairResponse(ok: true, extToken: pairingToken)
            let json = (try? String(data: JSONEncoder().encode(pairResp), encoding: .utf8)) ?? "{}"
            return makeHTTPResponse(status: 200, statusText: "OK", body: json, origin: origin)
        }
        
        // 3. DOM Capture from Chrome extension
        if path == "/dom" && method == "POST" {
            // Authentication Verification
            if requireAuth {
                let clientToken = headers["x-natively-token"] ??
                    headers["authorization"]?.replacingOccurrences(of: "Bearer ", with: "").trimmingCharacters(in: .whitespaces) ??
                    extractQueryParam("token", from: rawPath) ??
                    extractQueryParam("t", from: rawPath)
                
                guard let clientToken, clientToken == pairingToken else {
                    return makeHTTPResponse(status: 401, statusText: "Unauthorized", body: #"{"ok":false,"error":"Unauthorized"}"#, origin: origin)
                }
            }
            
            // Find body after \r\n\r\n
            if let bodyRange = rawHTTP.range(of: "\r\n\r\n") {
                let bodyString = String(rawHTTP[bodyRange.upperBound...])
                if let bodyData = bodyString.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(DOMContextPayload.self, from: bodyData) {
                    onDOMCaptured?(payload)
                    return makeHTTPResponse(status: 200, statusText: "OK", body: #"{"ok":true,"captured":true}"#, origin: origin)
                }
            }
            return makeHTTPResponse(status: 400, statusText: "Bad Request", body: #"{"ok":false,"error":"Invalid payload"}"#, origin: origin)
        }
        
        return makeHTTPResponse(status: 404, statusText: "Not Found", body: #"{"ok":false,"error":"Not Found"}"#, origin: origin)
    }
    
    private func validateOrigin(_ origin: String?) -> Bool {
        guard let origin else { return true } // No origin (curl, local processes) is permitted
        if origin.hasPrefix("chrome-extension://") ||
           origin.hasPrefix("moz-extension://") ||
           origin.hasPrefix("http://localhost") ||
           origin.hasPrefix("http://127.0.0.1") {
            return true
        }
        return false
    }
    
    private func extractQueryParam(_ param: String, from pathWithQuery: String) -> String? {
        guard let query = pathWithQuery.components(separatedBy: "?").dropFirst().first else { return nil }
        let items = query.components(separatedBy: "&")
        for item in items {
            let pair = item.components(separatedBy: "=")
            if pair.count == 2 && pair[0] == param {
                return pair[1].removingPercentEncoding ?? pair[1]
            }
        }
        return nil
    }
    
    private func makeHTTPResponse(status: Int, statusText: String, body: String, origin: String? = nil) -> String {
        let contentLength = body.utf8.count
        let allowOrigin = origin ?? "*"
        return "HTTP/1.1 \(status) \(statusText)\r\n" +
               "Content-Type: application/json\r\n" +
               "Content-Length: \(contentLength)\r\n" +
               "Access-Control-Allow-Origin: \(allowOrigin)\r\n" +
               "Connection: close\r\n\r\n" +
               body
    }
}
