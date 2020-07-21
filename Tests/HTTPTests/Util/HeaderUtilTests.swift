@testable import HTTP
import XCTest

final class HeaderUtilTests: XCTestCase {
    var nameKey: String!
    var nameValue: String!
    var filenameKey: String!
    var filenameValue: String!
    var headerLine: String!

    override func setUp() {
        super.setUp()

        // Arrange
        nameKey = "name"
        nameValue = "profilePhoto"
        filenameKey = "filename"
        filenameValue = "profilePhoto.png"
        headerLine = """
        Content-Disposition: form-data; \(nameKey!)=\"\(nameValue!)\"; \(filenameKey!)=\"\(filenameValue!)\"
        """
    }

    func testGetParameterValue() {
        // Act/Assert
        XCTAssertEqual(nameValue, HeaderUtil.getParameterValue(named: nameKey, in: headerLine))
        XCTAssertEqual(filenameValue, HeaderUtil.getParameterValue(named: filenameKey, in: headerLine))
        XCTAssertNil(HeaderUtil.getParameterValue(named: "invalidKey", in: headerLine))
    }

    func testSetParameterValue() {
        // Act
        HeaderUtil.setParameterValue(nameValue, named: "", in: &headerLine)

        // Assert
        XCTAssertEqual(
            headerLine,
            """
            Content-Disposition: form-data; \
            \(nameKey!)=\"\(self.nameValue!)\"; \
            \(filenameKey!)=\"\(self.filenameValue!)\"
            """
        )

        // Act
        HeaderUtil.setParameterValue(nameValue, named: "invalidKey=", in: &headerLine)

        // Assert
        XCTAssertEqual(
            headerLine,
            """
            Content-Disposition: form-data; \
            \(nameKey!)=\"\(self.nameValue!)\"; \
            \(filenameKey!)=\"\(self.filenameValue!)\"
            """
        )

        // Arrange
        let nameValue = "coverPhoto"
        let filenameValue = "coverPhoto.jpeg"

        // Act
        HeaderUtil.setParameterValue(nameValue, named: nameKey, enclosingInQuotes: true, in: &headerLine)

        // Assert
        XCTAssertEqual(
            headerLine,
            "Content-Disposition: form-data; \(nameKey!)=\"\(nameValue)\"; \(filenameKey!)=\"\(self.filenameValue!)\""
        )

        // Act
        HeaderUtil.setParameterValue(filenameValue, named: filenameKey, enclosingInQuotes: true, in: &headerLine)

        // Assert
        XCTAssertEqual(
            headerLine,
            "Content-Disposition: form-data; \(nameKey!)=\"\(nameValue)\"; \(filenameKey!)=\"\(filenameValue)\""
        )

        // Arrange
        let customKey = "customKey"
        let customValue = "customValue"

        // Act
        HeaderUtil.setParameterValue(customValue, named: customKey, enclosingInQuotes: true, in: &headerLine)

        // Assert
        XCTAssertEqual(
            headerLine,
            """
            Content-Disposition: form-data; \
            \(nameKey!)=\"\(nameValue)\"; \
            \(filenameKey!)=\"\(filenameValue)\"; \
            \(customKey)=\"\(customValue)\"
            """
        )

        // Arrange
        let anotherCustomKey = "anotherCustomKey"
        let anotherCustomValue = "anotherCustomValue"

        // Act
        headerLine += "; "
        HeaderUtil.setParameterValue(
            anotherCustomValue,
            named: anotherCustomKey,
            enclosingInQuotes: true,
            in: &headerLine
        )

        // Assert
        XCTAssertEqual(
            headerLine,
            """
            Content-Disposition: form-data; \
            \(nameKey!)=\"\(nameValue)\"; \
            \(filenameKey!)=\"\(filenameValue)\"; \
            \(customKey)=\"\(customValue)\"; \
            \(anotherCustomKey)=\"\(anotherCustomValue)\"
            """
        )

        // Act
        headerLine = ""
        HeaderUtil.setParameterValue(anotherCustomValue, named: anotherCustomKey, in: &headerLine)

        // Assert
        XCTAssertEqual(headerLine, "\(anotherCustomKey)=\(anotherCustomValue)")
    }
}
