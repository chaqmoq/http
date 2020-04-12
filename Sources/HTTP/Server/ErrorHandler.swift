import NIO
import NIOHTTP1

final class ErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Never

    let server: Server

    init(server: Server) {
        self.server = server
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        server.logger.error("Server error: \(error)")
        server.onError?(error)
        context.close(mode: .output, promise: nil)
    }
}
