import Foundation
import HTTP

let server = Server()

do {
    try server.start()
} catch {
    fatalError("Failed to start server: \(error)")
}
