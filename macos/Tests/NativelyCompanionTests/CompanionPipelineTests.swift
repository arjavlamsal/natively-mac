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
        let request = "OPTIONS /dom HTTP/1.1\r\nHost: localhost:4123\r\n\r\n"
        let response = server.routeRequest(request)
        
        #expect(response.contains("HTTP/1.1 204 No Content"))
        #expect(response.contains("Access-Control-Allow-Origin: *"))
    }
}
