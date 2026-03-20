import AsyncHTTPClient
import Foundation
@testable import HTTP
import NIO
import NIOSSL
import XCTest

/// Integration tests for the TLS path in `Server.swift`.
///
/// These tests exercise:
/// - `Server.initializeChild` → `if let tls` branch
/// - `Server.configure(tls:for:)`  (NIOSSLServerHandler installation)
/// - `Server.addHandlers(to:isHTTP2:false)` over a TLS connection
/// - `Server.Configuration.scheme` returning `"https"` when TLS is set
final class TLSServerTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    // MARK: - Configuration scheme reflects TLS

    func testSchemeIsHTTPSWhenTLSIsConfigured() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "scheme_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "scheme_key.pem")
        guard let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem) else {
            return XCTFail("Failed to build TLS configuration from embedded cert/key")
        }

        let config = Server.Configuration(port: 8443, tls: tls)
        XCTAssertEqual(config.scheme, "https")
        XCTAssertEqual(config.socketAddress, "https://127.0.0.1:8443")
    }

    // MARK: - HTTPS server accepts plain HTTP/1.1 connections over TLS

    /// Starts an HTTPS server and makes a GET request using an AsyncHTTPClient whose
    /// TLS configuration has certificate verification disabled (self-signed cert).
    ///
    /// Exercises:
    ///   - `initializeChild` → `if let tls` → `configure(tls:for:)` → `addHandlers(to:isHTTP2:false)`
    ///   - `configure(tls:)` with both `.one` and `.two` in `supportsVersions` (both ALPN values added)
    func testHTTPSServerAcceptsConnections() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "https_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "https_key.pem")
        guard let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem) else {
            return XCTFail("Failed to build TLS configuration from embedded cert/key")
        }

        var clientTLS = TLSConfiguration.makeClientConfiguration()
        clientTLS.certificateVerification = .none

        let clientConfig = HTTPClient.Configuration(tlsConfiguration: clientTLS)
        client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: clientConfig)
        server = Server(configuration: .init(port: 8443, tls: tls, numberOfThreads: 1))

        execute { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error making HTTPS request: \(error)")
            }
        }
    }

    // MARK: - configure(tls:) with HTTP/1 only (no h2 ALPN entry added)

    /// When `supportsVersions` contains only `.one`, `configure(tls:)` adds only
    /// `"http/1.1"` to `applicationProtocols` and skips the `"h2"` entry.
    func testHTTPSServerWithVersionOneOnly() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "v1_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "v1_key.pem")
        guard let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem) else {
            return XCTFail("Failed to build TLS configuration from embedded cert/key")
        }

        var clientTLS = TLSConfiguration.makeClientConfiguration()
        clientTLS.certificateVerification = .none

        let clientConfig = HTTPClient.Configuration(tlsConfiguration: clientTLS)
        client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: clientConfig)
        server = Server(configuration: .init(
            port: 8444,
            tls: tls,
            supportsVersions: [.one],
            numberOfThreads: 1
        ))

        execute { result in
            switch result {
            case .success(let response):
                XCTAssertEqual(response.status, .ok)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - onStart callback is invoked for a TLS server

    func testOnStartCallbackIsInvokedForTLSServer() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "onstart_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "onstart_key.pem")
        guard let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem) else {
            return XCTFail("Failed to build TLS configuration from embedded cert/key")
        }

        var clientTLS = TLSConfiguration.makeClientConfiguration()
        clientTLS.certificateVerification = .none

        let clientConfig = HTTPClient.Configuration(tlsConfiguration: clientTLS)
        client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: clientConfig)
        server = Server(configuration: .init(port: 8445, tls: tls, numberOfThreads: 1))

        var startEventLoop: EventLoop?

        execute(onStart: { eventLoop in
            startEventLoop = eventLoop
        }) { _ in }

        XCTAssertNotNil(startEventLoop)
    }
}

// MARK: - Execute helper

extension TLSServerTests {
    /// Starts the server, fires one GET request, calls `responseHandler` with the result,
    /// then tears everything down synchronously before returning.
    func execute(
        onStart: ((EventLoop) -> Void)? = nil,
        responseHandler: @escaping (Result<Response, Error>) -> Void
    ) {
        server.onStart = { [weak self] eventLoop in
            guard let self else { return }
            onStart?(eventLoop)

            let url = self.server.configuration.socketAddress
            let request = try! HTTPClient.Request(url: url, method: .GET)

            self.client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    let status = Response.Status(rawValue: Int(httpResponse.status.code)) ?? .ok
                    responseHandler(.success(Response(status: status)))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try? self?.client.syncShutdown()
                    try? self?.server.stop()
                }
            }
        }

        server.onReceive = { _ in Response() }
        try! server.start()
    }
}
