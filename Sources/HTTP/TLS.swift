import NIOSSL

public struct TLS {
    public let certificateFiles: [String]
    public let privateKeyFile: String
    public let encoding: Encoding
    let configuration: TLSConfiguration

    public init(certificateFiles: [String], privateKeyFile: String, encoding: Encoding) throws {
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

            let certificate = try NIOSSLCertificate(file: certificateFile, format: format)
            certificateChain.append(.certificate(certificate))
        }

        configuration = TLSConfiguration.forServer(
            certificateChain: certificateChain,
            privateKey: .file(privateKeyFile)
        )
    }
}

extension TLS {
    public enum Encoding {
        case pem
        case der
    }
}
