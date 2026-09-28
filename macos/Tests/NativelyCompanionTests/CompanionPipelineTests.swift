import Testing
import Foundation
import os
@testable import NativelyCompanion

@Suite("CompanionServer Pipeline Tests")
struct CompanionPipelineTests {
    
    @Test("CompanionServer routes /healthz correctly with JSON response")
    func testHealthCheck() {
        let server = CompanionServer(port: 4123)
        let request = "GET /healthz HTTP/1.1\r\nHost: localhost:4123\r\n\r\n"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 200 OK"))
        #expect(response.contains("\"ok\":true"))
        #expect(response.contains("\"version\":\"2.0.0-native\""))
    }
    
    @Test("CompanionServer returns pairing token on /pair")
    func testPairingEndpoint() {
        let token = "test-token-xyz-123"
        let server = CompanionServer(port: 4123, pairingToken: token)
        let request = "POST /pair HTTP/1.1\r\nHost: localhost:4123\r\n\r\n"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 200 OK"))
        #expect(response.contains(token))
    }
    
    @Test("CompanionServer ingests DOM context and invokes callback")
    func testDOMCapture() {
        let server = CompanionServer(port: 4123)
        let expectation = OSAllocatedUnfairLock(initialState: false)
        
        server.onDOMCaptured = { payload in
            if payload.title == "LeetCode - Two Sum" && payload.url == "https://leetcode.com" {
                expectation.withLock { $0 = true }
            }
        }
        
        let body = #"{"title":"LeetCode - Two Sum","url":"https://leetcode.com","text":"Given an array..."}"#
        let request = "POST /dom HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 200 OK"))
        #expect(expectation.withLock { $0 } == true)
    }
    
    @Test("CompanionServer handles CORS preflight OPTIONS request")
    func testCORSPreflight() {
        let server = CompanionServer(port: 4123)
        let request = "OPTIONS /dom HTTP/1.1\r\nHost: localhost:4123\r\nOrigin: chrome-extension://abcdefghijklmnopqrstuvwxyz123456\r\n\r\n"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 204 No Content"))
        #expect(response.contains("Access-Control-Allow-Origin: chrome-extension://abcdefghijklmnopqrstuvwxyz123456"))
    }
    
    @Test("CompanionServer enforces token authentication when requireAuth is enabled")
    func testTokenAuthentication() {
        let token = "super-secret-token-999"
        let server = CompanionServer(port: 4123, pairingToken: token, requireAuth: true)
        
        let body = #"{"title":"Problem Statement","text":"Code description"}"#
        
        // 1. Missing token -> 401
        let unauthorizedRequest = "POST /dom HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let unauthResponse = server.routeRequest(unauthorizedRequest)
        #expect(unauthResponse.contains("HTTP/1.1 401 Unauthorized"))
        
        // 2. Wrong token -> 401
        let wrongTokenRequest = "POST /dom HTTP/1.1\r\nX-Natively-Token: invalid-token\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let wrongResponse = server.routeRequest(wrongTokenRequest)
        #expect(wrongResponse.contains("HTTP/1.1 401 Unauthorized"))
        
        // 3. Valid token in header -> 200 OK
        let validHeaderRequest = "POST /dom HTTP/1.1\r\nX-Natively-Token: \(token)\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let validResponse = server.routeRequest(validHeaderRequest)
        #expect(validResponse.contains("HTTP/1.1 200 OK"))
        
        // 4. Valid token in query param -> 200 OK
        let validQueryRequest = "POST /dom?token=\(token) HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        let validQueryResponse = server.routeRequest(validQueryRequest)
        #expect(validQueryResponse.contains("HTTP/1.1 200 OK"))
    }
    
    @Test("CompanionServer rejects untrusted web origin")
    func testUntrustedOriginRejection() {
        let server = CompanionServer(port: 4123)
        let request = "POST /dom HTTP/1.1\r\nOrigin: https://malicious-website.com\r\nHost: localhost:4123\r\n\r\n{}"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 403 Forbidden"))
    }
}
