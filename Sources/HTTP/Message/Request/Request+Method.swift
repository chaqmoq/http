extension Request {
    public enum Method: String, CaseIterable, Encodable {
        case DELETE
        case GET
        case HEAD
        case OPTIONS
        case PATCH
        case POST
        case PUT
    }
}
