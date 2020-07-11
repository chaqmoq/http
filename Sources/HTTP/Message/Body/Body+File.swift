import Foundation

extension Body {
    public struct File {
        public var filename: String
        public var data: Data

        public init(filename: String, data: Data) {
            self.filename = filename
            self.data = data
        }
    }
}
