import Foundation

extension Request {
    public enum Method: String, CaseIterable {
        case DELETE
        case GET
        case HEAD
        case OPTIONS
        case PATCH
        case POST
        case PUT
    }
}
