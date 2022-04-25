import NIOSSL

public struct TLS {
    public let certificateFiles: [String]
    public let privateKeyFile: String
    public let encoding: Encoding
    let configuration: TLSConfiguration

    public init?(certificateFiles: [String], privateKeyFile: String, encoding: Encoding) {
        guard !certificateFiles.isEmpty && !privateKeyFile.isEmpty else { return nil }
        self.certificateFiles = certificateFiles
        self.privateKeyFile = privateKeyFile
        self.encoding = encoding

        var certificateChain: [NIOSSLCertificateSource] = []

        for certificateFile in certificateFiles {
            let format: NIOSSLSerializationFormats

            switch encoding {
            case .pem:
                format = .pem
            case .der:
                format = .der
            }

            if let certificate = try? NIOSSLCertificate(file: certificateFile, format: format) {
                certificateChain.append(.certificate(certificate))
            } else {
                return nil
            }
        }

        configuration = TLSConfiguration.makeServerConfiguration(
            certificateChain: certificateChain,
            privateKey: .file(privateKeyFile)
        )
    }
}

extension TLS {
    public enum Encoding: String {
        case pem
        case der
    }
}

extension TLS: Equatable {
    public static func == (lhs: TLS, rhs: TLS) -> Bool {
        lhs.certificateFiles == rhs.certificateFiles && lhs.privateKeyFile == rhs.privateKeyFile
    }
}
