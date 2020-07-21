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
}
