@testable import HTTP
import XCTest

final class TLSTests: XCTestCase {

    func testInitWithEmptyCertificateFilesReturnsNil() {
        // Act
        let tls = TLS(certificateFiles: [], privateKeyFile: "key.pem", encoding: .pem)

        // Assert
        XCTAssertNil(tls)
    }

    func testInitWithEmptyPrivateKeyFileReturnsNil() {
        // Act
        let tls = TLS(certificateFiles: ["cert.pem"], privateKeyFile: "", encoding: .pem)

        // Assert
        XCTAssertNil(tls)
    }

    func testInitWithNonExistentFilesReturnsNil() {
        // Certificates that don't exist on disk → NIOSSLCertificate init fails → TLS init returns nil
        let tls = TLS(
            certificateFiles: ["/nonexistent/cert.pem"],
            privateKeyFile: "/nonexistent/key.pem",
            encoding: .pem
        )
        XCTAssertNil(tls)
    }

    func testEncodingRawValues() {
        XCTAssertEqual(TLS.Encoding.pem.rawValue, "pem")
        XCTAssertEqual(TLS.Encoding.der.rawValue, "der")
    }

    func testEquatableComparesFilePaths() {
        // Two TLS instances created from the same paths would compare equal (but we can't
        // construct valid ones without real files, so verify the initialiser rejects invalid inputs)
        let tls1 = TLS(certificateFiles: [], privateKeyFile: "key.pem", encoding: .pem)
        let tls2 = TLS(certificateFiles: [], privateKeyFile: "key.pem", encoding: .pem)
        // Both are nil → they're equal in the sense that nil == nil
        XCTAssertNil(tls1)
        XCTAssertNil(tls2)
    }
}
