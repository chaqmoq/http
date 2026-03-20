import NIO
import NIOHPACK
import NIOHTTP2

/// Sits at the network-facing end of every HTTP/2 stream channel pipeline and
/// intercepts the first outbound write (which is always the HEADERS frame) to
/// inject any server-push promises queued by the request handler.
///
/// Pipeline position — HTTP/2 stream channels only:
/// ```
/// [network] ← HTTP2PushHandler ← HTTP2FramePayloadToHTTP1ServerCodec ← … ← [app]
/// ```
///
/// `RequestResponseHandler` calls ``enqueue(_:authority:)`` before writing the
/// main response. On the first outbound `HTTP2Frame.FramePayload` the handler:
///
/// 1. Creates a new server-push stream channel via `HTTP2StreamMultiplexer`.
/// 2. Writes a `PUSH_PROMISE` frame on the current (request) stream.
/// 3. Writes the push response on the new stream channel.
/// 4. Forwards the main response frame only after all pushes succeed.
///
/// Push failures are silently swallowed — they must not prevent the main response
/// from reaching the client.
final class HTTP2PushHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTP2Frame.FramePayload
    typealias InboundOut = HTTP2Frame.FramePayload
    typealias OutboundIn = HTTP2Frame.FramePayload
    typealias OutboundOut = HTTP2Frame.FramePayload

    private var pendingPushes: [(uri: URI, response: Response)] = []
    private var authority: String = ""
    /// Guards against sending push promises on the second/third write of the same
    /// response (DATA, END_STREAM frames that follow the initial HEADERS frame).
    private var pushesHandled = false

    // MARK: - API for RequestResponseHandler

    /// Enqueues push promises to be sent before the next response.
    ///
    /// - Parameters:
    ///   - pushes: The (URI, Response) pairs to push.
    ///   - authority: The `:authority` value for the `PUSH_PROMISE` request headers
    ///     (typically the `Host` header of the originating request).
    func enqueue(_ pushes: [(uri: URI, response: Response)], authority: String) {
        pendingPushes = pushes
        self.authority = authority
        pushesHandled = false
    }

    // MARK: - ChannelDuplexHandler

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        context.fireChannelRead(data)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        guard !pendingPushes.isEmpty, !pushesHandled else {
            context.write(data, promise: promise)
            return
        }

        // Only send push promises once — on the very first outbound write, which is
        // always the HEADERS frame. Subsequent DATA/END_STREAM frames pass straight through.
        pushesHandled = true
        let pushes = pendingPushes
        let authority = self.authority
        pendingPushes = []

        sendPushes(pushes, authority: authority, in: context).whenComplete { _ in
            // RFC 7540 §8.2: PUSH_PROMISE must precede the HEADERS on the associated stream.
            context.write(data, promise: promise)
        }
    }

    func flush(context: ChannelHandlerContext) {
        context.flush()
    }

    // MARK: - Push machinery

    private func sendPushes(
        _ pushes: [(uri: URI, response: Response)],
        authority: String,
        in context: ChannelHandlerContext
    ) -> EventLoopFuture<Void> {
        guard let parentPipeline = context.channel.parent?.pipeline else {
            return context.eventLoop.makeSucceededFuture(())
        }

        return parentPipeline
            .handler(type: HTTP2StreamMultiplexer.self)
            .flatMap { multiplexer in
                let futures = pushes.map { push in
                    self.sendOnePush(
                        uri: push.uri,
                        response: push.response,
                        authority: authority,
                        via: multiplexer,
                        in: context
                    )
                }
                return EventLoopFuture.andAllSucceed(futures, on: context.eventLoop)
            }
            .recover { _ in () } // push failures must not abort the main response
    }

    private func sendOnePush(
        uri: URI,
        response: Response,
        authority: String,
        via multiplexer: HTTP2StreamMultiplexer,
        in context: ChannelHandlerContext
    ) -> EventLoopFuture<Void> {
        let channelPromise = context.eventLoop.makePromise(of: Channel.self)

        // Create a server-push stream channel. NIOHTTP2 automatically assigns an
        // even stream ID (server-initiated) to this channel.
        multiplexer.createStreamChannel(promise: channelPromise) { pushChannel in
            let pushResponseEncoder: ChannelHandler = PushResponseEncoder()
            return pushChannel.pipeline.addHandler(pushResponseEncoder)
        }

        return channelPromise.futureResult.flatMap { pushChannel in
            pushChannel.getOption(HTTP2StreamChannelOptions.streamID).flatMap { streamID in
                // Build the PUSH_PROMISE request pseudo-headers.
                var promiseHeaders = HPACKHeaders()
                promiseHeaders.add(name: ":method", value: "GET")
                promiseHeaders.add(name: ":path", value: uri.description)
                promiseHeaders.add(name: ":scheme", value: "https")

                if !authority.isEmpty {
                    promiseHeaders.add(name: ":authority", value: authority)
                }

                // Write the PUSH_PROMISE frame on the *current* (request) stream.
                // Because HTTP2PushHandler is at the network-facing end of the pipeline
                // (before HTTP2FramePayloadToHTTP1ServerCodec), calling context.write here
                // sends HTTP2Frame.FramePayload directly to the stream channel's write
                // mechanism, which routes it through the multiplexer to the connection.
                let pushPromisePayload = HTTP2Frame.FramePayload.pushPromise(
                    .init(pushedStreamID: streamID, headers: promiseHeaders)
                )
                context.write(self.wrapOutboundOut(pushPromisePayload), promise: nil)
                context.flush()

                // Write the push response on the new stream channel.
                // PushResponseEncoder converts Response → HTTP2Frame.FramePayload directly.
                return pushChannel.writeAndFlush(response)
            }
        }
    }
}

// MARK: - PushResponseEncoder

/// Encodes a `Response` as HTTP/2 HEADERS + DATA frames for server-push stream channels.
///
/// Unlike `ResponseEncoder`, this handler writes `HTTP2Frame.FramePayload` directly —
/// push stream channels are created by the multiplexer and do not have
/// `HTTP2FramePayloadToHTTP1ServerCodec` in their pipeline.
final class PushResponseEncoder: ChannelOutboundHandler {
    typealias OutboundIn = Response
    typealias OutboundOut = HTTP2Frame.FramePayload

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = unwrapOutboundIn(data)

        var headers = HPACKHeaders()
        headers.add(name: ":status", value: String(response.status.code))

        for header in response.headers {
            headers.add(name: header.name, value: header.value)
        }

        let hasBody = !response.body.isEmpty
        let headersPayload = HTTP2Frame.FramePayload.headers(
            .init(headers: headers, endStream: !hasBody)
        )
        context.write(wrapOutboundOut(headersPayload), promise: hasBody ? nil : promise)

        if hasBody {
            // Use body._buffer directly — no [UInt8] copy required.
            let dataPayload = HTTP2Frame.FramePayload.data(
                .init(data: .byteBuffer(response.body._buffer), endStream: true)
            )
            context.write(wrapOutboundOut(dataPayload), promise: promise)
        }

        context.flush()
    }
}
