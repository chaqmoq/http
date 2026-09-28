import NIO
import NIOHTTP1

final class ResponseEncoder: ChannelOutboundHandler, RemovableChannelHandler, @unchecked Sendable {
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

        if let stream = response.stream {
            writeStreamed(
                stream,
                version: version,
                status: status,
                headers: headers,
                context: context,
                promise: promise
            )
            return
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

// MARK: - Streaming

extension ResponseEncoder {
    /// Writes the head immediately, then runs the producer and forwards each chunk as it arrives.
    ///
    /// `promise` — which `RequestResponseHandler` uses to decide when a `Connection: close` socket may
    /// be shut — completes only once the stream has ended, not when the head goes out.
    private func writeStreamed(
        _ stream: ResponseStream,
        version: HTTPVersion,
        status: HTTPResponseStatus,
        headers: HTTPHeaders,
        context: ChannelHandlerContext,
        promise: EventLoopPromise<Void>?
    ) {
        var headers = headers

        // The length of a streamed body is unknown, so it must never carry Content-Length.
        headers.remove(name: "content-length")

        if version.major == 1 {
            if version.minor >= 1 {
                if !headers.contains(name: "transfer-encoding") {
                    headers.add(name: "transfer-encoding", value: "chunked")
                }
            } else {
                // HTTP/1.0 has no chunked encoding; the body ends when the connection does.
                headers.replaceOrAdd(name: "connection", value: "close")
            }
        } else {
            // Transfer-Encoding is a connection-specific header and is forbidden in HTTP/2.
            headers.remove(name: "transfer-encoding")
        }

        let head = HTTPResponseHead(version: version, status: status, headers: headers)
        context.writeAndFlush(wrapOutboundOut(.head(head)), promise: nil)

        let contextBox = ContextBox(context)
        let eventLoop = context.eventLoop
        let channel = context.channel
        let writer = ResponseStreamWriter { [self] buffer in
            try Task.checkCancellation()
            try await eventLoop.flatSubmit { [self] in
                contextBox.context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))))
            }.get()
        }

        let task = Task { [self] in
            // The producer's error, if any, is deliberately not surfaced: the head is already on the
            // wire, so the only thing left to do is end the body cleanly.
            try? await stream.producer(writer)

            eventLoop.execute { [self] in
                guard channel.isActive else {
                    promise?.fail(ChannelError.ioOnClosedChannel)
                    return
                }

                contextBox.context.writeAndFlush(
                    self.wrapOutboundOut(.end(nil)),
                    promise: promise
                )
            }
        }

        // A client that disconnects mid-stream must not leave the producer waiting forever.
        channel.closeFuture.whenComplete { _ in
            task.cancel()
        }
    }
}

/// Carries a `ChannelHandlerContext` across the event-loop hop.
///
/// The context is only ever touched on its own event loop — every use is inside
/// `eventLoop.execute` / `flatSubmit` — which is what makes the unchecked conformance sound.
private final class ContextBox: @unchecked Sendable {
    let context: ChannelHandlerContext

    init(_ context: ChannelHandlerContext) {
        self.context = context
    }
}
