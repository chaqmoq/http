extension Request {
    /// Represents a standard HTTP request method (verb).
    public enum Method: String, CaseIterable, Encodable, Sendable {
        /// Removes the specified resource.
        case DELETE
        /// Retrieves a representation of the specified resource.
        case GET
        /// Identical to `GET` but the response body is omitted.
        case HEAD
        /// Describes the communication options for the target resource.
        case OPTIONS
        /// Applies partial modifications to a resource.
        case PATCH
        /// Submits an entity to the specified resource, often causing a state change.
        case POST
        /// Replaces all current representations of the target resource.
        case PUT
        /// Performs a message loop-back test along the path to the target resource.
        case TRACE
        /// Establishes a tunnel to the server identified by the target resource.
        case CONNECT
    }
}
