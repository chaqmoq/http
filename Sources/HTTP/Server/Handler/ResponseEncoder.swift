import NIO
import NIOHTTP1

final class ResponseEncoder: ChannelOutboundHandler, RemovableChannelHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = unwrapOutboundIn(data)
        let version = HTTPVersion(major: response.version.major, minor: response.version.minor)
        let status = HTTPResponseStatus(statusCode: response.status.code)
        var headers = HTTPHeaders()

        for header in response.headers {
            headers.add(name: header.name, value: header.value)
        }

        // Safety net for HTTP/1.1: a client cannot determine the body boundary
        // without either Content-Length or Transfer-Encoding: chunked. If a handler
        // removed (or never set) Content-Length and there is a body to send, add it
        // here so the wire format is always self-delimiting. We do not override a
        // value that is already present (e.g. HEAD responses carry a hypothetical
        // Content-Length that intentionally differs from the actual empty body).
        if version.major == 1,
           !headers.contains(name: "content-length"),
           !headers.contains(name: "transfer-encoding"),
           !response.body.isEmpty {
            headers.add(name: "content-length", value: String(response.body.count))
        }

        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        if !response.body.isEmpty {
            // Write the body's ByteBuffer directly — Body._buffer is already a pooled
            // NIO buffer, so this avoids the [UInt8] → ByteBuffer copy that the old
            // `buffer.writeBytes(response.body.bytes)` path required.
            context.write(wrapOutboundOut(.body(.byteBuffer(response.body._buffer))), promise: nil)
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: promise)
    }
}
