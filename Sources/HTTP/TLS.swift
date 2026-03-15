import Foundation
import NIOSSL

/// TLS configuration for an HTTPS server.
///
/// Wraps SwiftNIO SSL's `TLSConfiguration` and provides a simple initialiser that
/// loads certificate chains and a private key from disk. Returns `nil` when any
/// supplied file path is empty or when a certificate cannot be loaded.
///
/// ```swift
/// if let tls = TLS(
///     certificateFiles: ["/etc/ssl/cert.pem"],
///     privateKeyFile: "/etc/ssl/key.pem",
///     encoding: .pem
/// ) {
///     let config = Server.Configuration(tls: tls)
/// }
/// ```
public struct TLS {
    /// The ordered list of PEM or DER certificate files forming the certificate chain.
    public let certificateFiles: [String]

    /// The path to the private key file corresponding to the first certificate.
    public let privateKeyFile: String

    /// The encoding format used to parse the certificate and key files.
    public let encoding: Encoding

    /// The underlying SwiftNIO SSL server TLS configuration.
    let configuration: TLSConfiguration

    /// Initializes a `TLS` value by loading certificates and a private key from disk.
    ///
    /// Returns `nil` when:
    /// - `certificateFiles` is empty.
    /// - `privateKeyFile` is an empty string.
    /// - Any certificate file cannot be read or parsed.
    ///
    /// - Parameters:
    ///   - certificateFiles: Paths to the certificate files (leaf first, then intermediates).
    ///   - privateKeyFile: Path to the private key file.
    ///   - encoding: The encoding format (`.pem` or `.der`).
    public init?(certificateFiles: [String], privateKeyFile: String, encoding: Encoding) {
        guard !certificateFiles.isEmpty && !privateKeyFile.isEmpty else { return nil }
        self.certificateFiles = certificateFiles
        self.privateKeyFile = privateKeyFile
        self.encoding = encoding

        var certificateChain: [NIOSSLCertificateSource] = []

        for certificateFile in certificateFiles {
            do {
                switch encoding {
                case .pem:
                    // fromPEMFile returns all certificates in the chain at once.
                    let certs = try NIOSSLCertificate.fromPEMFile(certificateFile)
                    certificateChain.append(contentsOf: certs.map { .certificate($0) })
                case .der:
                    // DER files hold exactly one certificate.
                    let derBytes = try Array(Data(contentsOf: URL(fileURLWithPath: certificateFile)))
                    let cert = try NIOSSLCertificate(bytes: derBytes, format: .der)
                    certificateChain.append(.certificate(cert))
                }
            } catch {
                return nil
            }
        }

        let privateKeyFormat: NIOSSLSerializationFormats = encoding == .pem ? .pem : .der
        guard let privateKey = try? NIOSSLPrivateKey(file: privateKeyFile, format: privateKeyFormat) else {
            return nil
        }

        configuration = TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain,
            privateKey: .privateKey(privateKey)
        )
    }
}

extension TLS {
    /// The file encoding used for TLS certificates and private keys.
    public enum Encoding: String {
        /// Privacy Enhanced Mail (Base64-encoded DER) format.
        case pem

        /// Distinguished Encoding Rules (binary) format.
        case der
    }
}

extension TLS: Equatable {
    /// Returns `true` when both values reference the same certificate files and private key path.
    ///
    /// The `encoding` field and the derived `TLSConfiguration` are not compared;
    /// identity is based purely on file paths.
    ///
    /// - Parameters:
    ///   - lhs: A `TLS` value.
    ///   - rhs: Another `TLS` value.
    /// - Returns: `true` if `certificateFiles` and `privateKeyFile` are identical.
    public static func == (lhs: TLS, rhs: TLS) -> Bool {
        lhs.certificateFiles == rhs.certificateFiles && lhs.privateKeyFile == rhs.privateKeyFile
    }
}
