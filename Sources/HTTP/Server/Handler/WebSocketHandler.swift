import NIO
import NIOWebSocket

/// Bridges NIO ``WebSocketFrame`` channel events to a ``WebSocket`` actor.
///
/// Responsibilities:
/// - Text and binary frames → yields ``WebSocket/Message`` to the actor's `AsyncStream`
/// - Ping frames → automatically echoes a Pong frame (RFC 6455 §5.5.3)
/// - Connection-close frames → echoes the close frame then closes the channel (RFC 6455 §5.5.1)
/// - `channelInactive` → finishes the `AsyncStream` so awaiting consumers unblock
/// - `errorCaught` → finishes the `AsyncStream` and closes the channel
///
/// This handler is added to the pipeline by ``Server`` inside the
/// `NIOWebSocketServerUpgrader.upgradePipelineHandler` closure.
final class WebSocketHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn  = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let webSocket: WebSocket
    /// Guards against sending a second close frame if `channelInactive` fires after
    /// we already echoed a close frame in response to the peer's close frame.
    private var awaitingClose = false

    init(webSocket: WebSocket) {
        self.webSocket = webSocket
    }

    // MARK: - ChannelInboundHandler

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)

        switch frame.opcode {
        case .text:
            var unmasked = frame.unmaskedData
            let text = unmasked.readString(length: unmasked.readableBytes) ?? ""
            webSocket.yield(.text(text))

        case .binary:
            webSocket.yield(.binary(frame.unmaskedData))

        case .ping:
            // RFC 6455 §5.5.2: a Pong must be sent in response to every Ping.
            guard frame.fin else { return } // fragmented ping is illegal; ignore
            sendPong(context: context, data: frame.unmaskedData)

        case .connectionClose:
            guard !awaitingClose else { return }
            awaitingClose = true
            // Echo the close frame back, then close the channel.
            var echo = frame.unmaskedData
            let closeFrame = WebSocketFrame(
                fin: true,
                opcode: .connectionClose,
                data: echo
            )
            context.writeAndFlush(wrapOutboundOut(closeFrame)).whenComplete { _ in
                context.close(promise: nil)
            }

        case .continuation, .pong:
            // Continuation frames require reassembly (not implemented here);
            // pong frames are unsolicited acks and can be discarded.
            break

        default:
            // Unknown opcode — close with protocol-error (RFC 6455 §5.2).
            closeWithProtocolError(context: context)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        webSocket.finish()
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        webSocket.finish()
        context.close(promise: nil)
    }

    // MARK: - Helpers

    private func sendPong(context: ChannelHandlerContext, data: ByteBuffer) {
        let pong = WebSocketFrame(fin: true, opcode: .pong, data: data)
        context.writeAndFlush(wrapOutboundOut(pong), promise: nil)
    }

    private func closeWithProtocolError(context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: 2)
        buffer.write(webSocketErrorCode: .protocolError)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: buffer)
        context.writeAndFlush(wrapOutboundOut(frame)).whenComplete { _ in
            context.close(mode: .output, promise: nil)
        }
    }
}
