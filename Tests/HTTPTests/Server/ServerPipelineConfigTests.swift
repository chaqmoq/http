import AsyncHTTPClient
@testable import HTTP
import NIO
import XCTest

/// Integration tests that exercise Server.swift branches that are skipped by the default
/// configuration: HTTP pipelining, and all three decompression-limit variants.
final class ServerPipelineConfigTests: XCTestCase {
    var client: HTTPClient!
    var server: Server!

    // MARK: - Pipelining enabled (exercises HTTPServerPipelineHandler branch)

    func testServerWithPipeliningEnabled() {
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(
            port: 8082,
            supportsPipelining: true,
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

    // MARK: - Decompression limit: .none

    func testDecompressionLimitNone() {
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(
            port: 8083,
            numberOfThreads: 1,
            requestDecompression: .init(limit: .none, isEnabled: true)
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

    // MARK: - Decompression limit: .size (exercises the `.size(size)` switch branch)

    func testDecompressionLimitSize() {
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(
            port: 8084,
            numberOfThreads: 1,
            requestDecompression: .init(limit: .size(1_048_576), isEnabled: true)
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

    // MARK: - Decompression limit: .ratio (exercises the `.ratio(ratio)` switch branch)

    func testDecompressionLimitRatio() {
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(
            port: 8085,
            numberOfThreads: 1,
            requestDecompression: .init(limit: .ratio(20), isEnabled: true)
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

    // MARK: - Compression disabled, decompression disabled

    func testBothCompressionAndDecompressionDisabled() {
        client = HTTPClient(eventLoopGroupProvider: .singleton)
        server = Server(configuration: .init(
            port: 8086,
            numberOfThreads: 1,
            requestDecompression: .init(isEnabled: false),
            responseCompression: .init(isEnabled: false)
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

    // MARK: - onStop callback is invoked after stop()

    func testOnStopCallbackIsInvoked() {
        var stopCalled = false
        let localServer = Server(configuration: .init(numberOfThreads: 1))
        localServer.onStop = { stopCalled = true }
        try? localServer.stop()
        XCTAssertTrue(stopCalled)
    }
}

// MARK: - Helper

extension ServerPipelineConfigTests {
    func execute(responseHandler: @escaping (Result<Response, Error>) -> Void) {
        let uri = URI(server.configuration.socketAddress)!

        server.onStart = { [weak self] _ in
            guard let self else { return }

            let request = try! HTTPClient.Request(url: uri.string!, method: .GET)

            client.execute(request: request).whenComplete { [weak self] result in
                switch result {
                case .failure(let error):
                    responseHandler(.failure(error))
                case .success(let httpResponse):
                    let status = Response.Status(rawValue: Int(httpResponse.status.code)) ?? .ok
                    responseHandler(.success(Response(status: status)))
                }

                DispatchQueue.global().asyncAfter(deadline: .now()) { [weak self] in
                    try! self?.client.syncShutdown()
                    try! self?.server.stop()
                }
            }
        }

        server.onReceive = { _ in Response() }
        try! server.start()
    }
}
