/// Errors produced by the HTTP server infrastructure.
///
/// These errors are surfaced through the ``Server/onError`` callback and can be
/// pattern-matched by application code to provide tailored responses.
///
/// ```swift
/// server.onError = { error, eventLoop in
///     if case ServerError.bodyTooLarge = error {
///         // log or alert
///     }
/// }
/// ```
public enum ServerError: Error {
    /// The request body exceeded the ``Server/Configuration/maxBodySize`` limit.
    ///
    /// The connection is closed immediately when this error is raised. Configure
    /// the limit via ``Server/Configuration/maxBodySize``.
    case bodyTooLarge

    /// The request target (request-line URI) could not be parsed.
    ///
    /// The server responds with `400 Bad Request` rather than silently treating the
    /// target as `/`, which would route and authorize the request as the root path.
    case invalidURI
}
