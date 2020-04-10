import NIO
import NIOHTTP1

extension Server {
    final class HTTPHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart

        let server: Server

        var request: Request
        var response: Response

        init(server: Server) {
            self.server = server
            request = Request()
            response = Response(status: .notFound)
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let requestPart = unwrapInboundIn(data)

            switch requestPart {
            case .head(let header):
                handle(header: header)
            case .body(let chunk):
                handle(chunk: chunk)
            case .end(let end):
                handle(end: end, in: context)
            }
        }
    }
}

extension Server.HTTPHandler {
    private func handle(header: HTTPRequestHead) {
        let method = Request.Method(rawValue: header.method.rawValue)!
        let version = ProtocolVersion(major: header.version.major, minor: header.version.minor)
        request = Request(method: method, uri: header.uri, version: version)

        for header in header.headers {
            if let name = Header(rawValue: header.name) {
                response.headers[name] = header.value
            }
        }
    }

    private func handle(chunk: ByteBuffer) {
        if let bytes = chunk.getBytes(at: 0, length: chunk.readableBytes) {
            request.body.append(bytes: bytes)
        }
    }

    private func handle(end: HTTPHeaders?, in context: ChannelHandlerContext) {
        // Parse body
        request.parseBody()

        // Handle request
        if let onReceive = server.onReceive {
            response = onReceive(request)
        }

        // Server header
        response.headers[.server] = server.configuration.serverName

        // Handle connection
        if request.version.major < 2 {
            if let connection = request.headers[.connection] {
                response.headers[.connection] = connection
            } else {
                if request.version.major == 1 && request.version.minor >= 1 {
                    response.headers[.connection] = "keep-alive"
                } else {
                    response.headers[.connection] = "close"
                }
            }
        }

        // Flush headers
        var headers = HTTPHeaders()

        for (name, value) in response.headers {
            headers.add(name: name.rawValue, value: value)
        }

        let version = HTTPVersion(major: request.version.major, minor: request.version.minor)
        let status = HTTPResponseStatus(statusCode: response.status.code)
        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        let responseHeadPart = HTTPServerResponsePart.head(head)
        _ = context.channel.writeAndFlush(responseHeadPart)

        // Flush body and end
        if response.body.isEmpty {
            // Flush end
            let responseEndPart = HTTPServerResponsePart.end(end)
            _ = context.channel.writeAndFlush(responseEndPart).map { context.channel.close() }
        } else {
            // Flush body
            var buffer = context.channel.allocator.buffer(capacity: response.body.count)
            buffer.writeBytes(response.body.bytes)

            let responseBodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = context.channel.writeAndFlush(responseBodyPart).map {
                // Flush end
                let responseEndPart = HTTPServerResponsePart.end(end)
                _ = context.channel.writeAndFlush(responseEndPart).map { context.channel.close() }
            }
        }
    }
}
