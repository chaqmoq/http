import NIO
import NIOHTTP1
import NIOHTTP2

extension Server {
    func addHandlers(to channel: Channel, streamID: HTTP2StreamID? = nil) -> EventLoopFuture<Void> {
        if let streamID = streamID {
            return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
                guard let server = self else { return channel.close() }
                let handlers: [ChannelHandler] = [
                    HTTP2ToHTTP1ServerCodec(streamID: streamID),
                    HTTPHandler(server: server)
                ]

                return channel.pipeline.addHandlers(handlers)
            }
        }

        return channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
            guard let server = self else { return channel.close() }
            var handlers: [ChannelHandler] = []

            if server.configuration.supportsPipelining {
                handlers.append(HTTPServerPipelineHandler())
            }

            handlers.append(HTTPHandler(server: server))

            return channel.pipeline.addHandlers(handlers)
        }
    }
}
