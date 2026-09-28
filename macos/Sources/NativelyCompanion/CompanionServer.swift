import Foundation
import Network
import NativelyCore
import NativelySecurity

/// High-performance local companion micro-server using Apple's Network.framework.
/// Handles Chrome extension context capture (/dom), pairing (/pair), and health checks (/healthz).
public final class CompanionServer: @unchecked Sendable {
    public let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.natively.companion.server", qos: .userInitiated)
    
    // Server state
    public private(set) var isRunning: Bool = false
    public var isMeetingActive: Bool = false
    public var pairingToken: String
    
    // Callbacks
    public var onDOMCaptured: (@Sendable (DOMContextPayload) -> Void)?
    
    public init(port: UInt16 = 4123, pairingToken: String? = nil) {
        self.port = port
        self.pairingToken = pairingToken ?? UUID().uuidString
    }
    
    /// Starts the NWListener TCP service.
    public func start() throws {
        guard !isRunning else { return }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
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
        receiveNextChunk(on: connection)
    }
    
    private func receiveNextChunk(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty, let requestString = String(data: data, encoding: .utf8) {
                let response = self.routeRequest(requestString)
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }
            
            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }
    
    /// Internal HTTP request router.
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
        let path = String(parts[1]).components(separatedBy: "?").first ?? "/"
        
        // CORS preflight
        if method == "OPTIONS" {
            return "HTTP/1.1 204 No Content\r\n" +
                   "Access-Control-Allow-Origin: *\r\n" +
                   "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                   "Access-Control-Allow-Headers: Content-Type, Authorization, X-Natively-Token\r\n" +
                   "Connection: close\r\n\r\n"
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
            return makeHTTPResponse(status: 200, statusText: "OK", body: json)
        }
        
        // 2. Extension Pairing
        if path == "/pair" && (method == "POST" || method == "GET") {
            let pairResp = PairResponse(ok: true, extToken: pairingToken)
            let json = (try? String(data: JSONEncoder().encode(pairResp), encoding: .utf8)) ?? "{}"
            return makeHTTPResponse(status: 200, statusText: "OK", body: json)
        }
        
        // 3. DOM Capture from Chrome extension
        if path == "/dom" && method == "POST" {
            // Find body after \r\n\r\n
            if let bodyRange = rawHTTP.range(of: "\r\n\r\n") {
                let bodyString = String(rawHTTP[bodyRange.upperBound...])
                if let bodyData = bodyString.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(DOMContextPayload.self, from: bodyData) {
                    onDOMCaptured?(payload)
                    return makeHTTPResponse(status: 200, statusText: "OK", body: #"{"ok":true,"captured":true}"#)
                }
            }
            return makeHTTPResponse(status: 400, statusText: "Bad Request", body: #"{"ok":false,"error":"Invalid payload"}"#)
        }
        
        return makeHTTPResponse(status: 404, statusText: "Not Found", body: #"{"ok":false,"error":"Not Found"}"#)
    }
    
    private func makeHTTPResponse(status: Int, statusText: String, body: String) -> String {
        let contentLength = body.utf8.count
        return "HTTP/1.1 \(status) \(statusText)\r\n" +
               "Content-Type: application/json\r\n" +
               "Content-Length: \(contentLength)\r\n" +
               "Access-Control-Allow-Origin: *\r\n" +
               "Connection: close\r\n\r\n" +
               body
    }
}
