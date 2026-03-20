import Foundation
@testable import HTTP
import XCTest

// PEM fixtures and temp-file helpers live in Tests/HTTPTests/Util/TLSTestFixtures.swift
// and are visible to all files in the HTTPTests target.

final class TLSTests: XCTestCase {

    // MARK: - nil-returning guard paths

    func testInitWithEmptyCertificateFilesReturnsNil() {
        let tls = TLS(certificateFiles: [], privateKeyFile: "key.pem", encoding: .pem)
        XCTAssertNil(tls)
    }

    func testInitWithEmptyPrivateKeyFileReturnsNil() {
        let tls = TLS(certificateFiles: ["cert.pem"], privateKeyFile: "", encoding: .pem)
        XCTAssertNil(tls)
    }

    func testInitWithNonExistentPEMCertFileReturnsNil() {
        let tls = TLS(
            certificateFiles: ["/nonexistent/cert.pem"],
            privateKeyFile: "/nonexistent/key.pem",
            encoding: .pem
        )
        XCTAssertNil(tls)
    }

    /// Exercises the `case .der:` branch when the file cannot be read.
    func testInitWithNonExistentDERCertFileReturnsNil() {
        let tls = TLS(
            certificateFiles: ["/nonexistent/cert.der"],
            privateKeyFile: "/nonexistent/key.der",
            encoding: .der
        )
        XCTAssertNil(tls)
    }

    // MARK: - PEM success path

    func testInitWithPEMEncodingSucceeds() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "tls_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "tls_key.pem")
        let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem)

        XCTAssertNotNil(tls)
        XCTAssertEqual(tls?.certificateFiles, [certPath])
        XCTAssertEqual(tls?.privateKeyFile, keyPath)
        XCTAssertEqual(tls?.encoding, .pem)
    }

    func testInitWithValidCertsMissingPrivateKeyReturnsNil() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "tls_cert_nokey.pem")
        let tls = TLS(
            certificateFiles: [certPath],
            privateKeyFile: "/nonexistent/missing_key.pem",
            encoding: .pem
        )
        XCTAssertNil(tls)
    }

    // MARK: - DER success path (exercises `case .der:` in the certificate-loading switch)

    func testInitWithDEREncodingSucceeds() throws {
        // Derive DER bytes directly from the embedded PEM (strip headers → base64-decode).
        let certPath = try writeDERTempFile(fromPEM: testCertPEM, name: "tls_cert.der")
        let keyPath = try writeDERTempFile(fromPEM: testKeyPEM, name: "tls_key.der")
        let tls = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .der)

        XCTAssertNotNil(tls)
        XCTAssertEqual(tls?.certificateFiles, [certPath])
        XCTAssertEqual(tls?.privateKeyFile, keyPath)
        XCTAssertEqual(tls?.encoding, .der)
    }

    // MARK: - Encoding enum raw values

    func testEncodingRawValues() {
        XCTAssertEqual(TLS.Encoding.pem.rawValue, "pem")
        XCTAssertEqual(TLS.Encoding.der.rawValue, "der")
    }

    // MARK: - Equatable

    func testEquatableSameFilesAreEqual() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "eq_cert.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "eq_key.pem")
        let tls1 = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem)
        let tls2 = TLS(certificateFiles: [certPath], privateKeyFile: keyPath, encoding: .pem)

        XCTAssertNotNil(tls1)
        XCTAssertNotNil(tls2)
        XCTAssertEqual(tls1, tls2)
    }

    func testEquatableDifferentCertFilesNotEqual() throws {
        // Two copies of the same bytes at different paths → paths differ → not equal.
        let certPath1 = try writeTempFile(string: testCertPEM, name: "eq2_cert_a.pem")
        let certPath2 = try writeTempFile(string: testCertPEM, name: "eq2_cert_b.pem")
        let keyPath = try writeTempFile(string: testKeyPEM, name: "eq2_key.pem")
        let tls1 = TLS(certificateFiles: [certPath1], privateKeyFile: keyPath, encoding: .pem)
        let tls2 = TLS(certificateFiles: [certPath2], privateKeyFile: keyPath, encoding: .pem)

        XCTAssertNotNil(tls1)
        XCTAssertNotNil(tls2)
        XCTAssertNotEqual(tls1, tls2)
    }

    func testEquatableDifferentKeyFilesNotEqual() throws {
        let certPath = try writeTempFile(string: testCertPEM, name: "eq3_cert.pem")
        let keyPath1 = try writeTempFile(string: testKeyPEM, name: "eq3_key_a.pem")
        let keyPath2 = try writeTempFile(string: testKeyPEM, name: "eq3_key_b.pem")
        let tls1 = TLS(certificateFiles: [certPath], privateKeyFile: keyPath1, encoding: .pem)
        let tls2 = TLS(certificateFiles: [certPath], privateKeyFile: keyPath2, encoding: .pem)

        XCTAssertNotNil(tls1)
        XCTAssertNotNil(tls2)
        XCTAssertNotEqual(tls1, tls2)
    }
}
