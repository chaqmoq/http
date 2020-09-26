import NIO
import NIOHTTP1

final class ResponseEncoder: ChannelOutboundHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = unwrapOutboundIn(data)
        let version = HTTPVersion(major: response.version.major, minor: response.version.minor)
        let status = HTTPResponseStatus(statusCode: response.status.code)
        var headers = HTTPHeaders()
        for (name, value) in response.headers { headers.add(name: name, value: value)}
        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        if !response.body.isEmpty {
            var buffer = context.channel.allocator.buffer(capacity: response.body.count)
            buffer.writeBytes(response.body.bytes)
            _ = context.write(wrapOutboundOut(.body(.byteBuffer(buffer))))
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
    }
}
