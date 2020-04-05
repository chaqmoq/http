import NIO
import NIOSSL

extension Server {
    func configure(tls: inout TLSConfiguration, for channel: Channel) -> EventLoopFuture<Void> {
        if configuration.supportsVersions.contains(.two) {
            tls.applicationProtocols.append("h2")
        }

        if configuration.supportsVersions.contains(.one) {
            tls.applicationProtocols.append("http/1.1")
        }

        let sslContext: NIOSSLContext
        let sslHandler: NIOSSLServerHandler

        do {
            sslContext = try NIOSSLContext(configuration: tls)
            sslHandler = try NIOSSLServerHandler(context: sslContext)
        } catch {
            logger.error("Failed to configure TLS: \(error)")
            return channel.close()
        }

        return channel.pipeline.addHandler(sslHandler)
    }
}
