@testable import HTTP
import XCTest

final class BodyDecodingTests: XCTestCase {

    // MARK: - JSON

    func testJSONDecoding() {
        // Arrange
        let body = Body(string: "{\"title\":\"New post\",\"views\":42}")

        // Act
        let json = body.json

        // Assert
        XCTAssertEqual(json.count, 2)
        XCTAssertEqual(json["title"] as? String, "New post")
        XCTAssertEqual(json["views"] as? Int, 42)
    }

    func testJSONDecodingEmptyBody() {
        // Arrange
        let body = Body()

        // Act
        let json = body.json

        // Assert
        XCTAssertTrue(json.isEmpty)
    }

    func testJSONDecodingInvalidJSON() {
        // Arrange
        let body = Body(string: "not json at all")

        // Act
        let json = body.json

        // Assert
        XCTAssertTrue(json.isEmpty)
    }

    func testJSONDecodingArray() {
        // Arrange – JSONSerialization on an array returns nil when cast to [String: Any]
        let body = Body(string: "[1, 2, 3]")

        // Act
        let json = body.json

        // Assert
        XCTAssertTrue(json.isEmpty)
    }

    // MARK: - URL Encoded

    func testURLEncodedDecoding() {
        // Arrange
        let body = Body(string: "title=New+post&likesCount=100")

        // Act
        let params = body.urlEncoded

        // Assert
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params["title"], "New post")
        XCTAssertEqual(params["likesCount"], "100")
    }

    func testURLEncodedDecodingEmpty() {
        // Act
        let params = Body().urlEncoded

        // Assert
        XCTAssertTrue(params.isEmpty)
    }

    func testURLEncodedDecodingPercentEncoded() {
        // Arrange
        let body = Body(string: "email=user%40example.com&name=John+Doe")

        // Act
        let params = body.urlEncoded

        // Assert
        XCTAssertEqual(params["email"], "user@example.com")
        XCTAssertEqual(params["name"], "John Doe")
    }

    // MARK: - Multipart

    func testMultipartDecoding() {
        // Arrange
        let boundary = "----WebKitFormBoundaryABC123"
        let multipartBody = """
        ------WebKitFormBoundaryABC123\r\n\
        Content-Disposition: form-data; name="username"\r\n\
        \r\n\
        johndoe\r\n\
        ------WebKitFormBoundaryABC123--\r\n
        """
        let body = Body(string: multipartBody)

        // Act
        let (params, files) = body.multipart(boundary: boundary)

        // Assert
        XCTAssertFalse(params.isEmpty, "Expected at least one parameter from multipart body")
        XCTAssertTrue(files.isEmpty)
    }

    func testMultipartDecodingEmptyBody() {
        // Arrange
        let body = Body()

        // Act
        let (params, files) = body.multipart(boundary: "boundary")

        // Assert
        XCTAssertTrue(params.isEmpty)
        XCTAssertTrue(files.isEmpty)
    }

    func testMultipartDecodingMixedFieldsAndFiles() {
        // A single multipart body that contains both a plain text field AND a file
        // upload. Exercises the branch where the parameter map and file map are
        // both populated in the same parse run.
        let boundary = "MixedBoundary"
        let multipartBody =
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"username\"\r\n" +
            "\r\n" +
            "alice\r\n" +
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"avatar\"; filename=\"photo.jpg\"\r\n" +
            "Content-Type: image/jpeg\r\n" +
            "\r\n" +
            "JPEGDATA\r\n" +
            "--\(boundary)--\r\n"
        let body = Body(string: multipartBody)

        // Act
        let (params, files) = body.multipart(boundary: boundary)

        // Assert
        XCTAssertFalse(params.isEmpty, "Expected 'username' in parameters")
        XCTAssertFalse(files.isEmpty, "Expected 'avatar' in files")
        XCTAssertEqual(files["avatar"]?.filename, "photo.jpg")
    }

    func testMultipartDecodingWithFileUpload() {
        // Arrange
        let boundary = "TestBoundary"
        let fileContent = "file content here"
        let multipartBody =
            "--\(boundary)\r\n" +
            "Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n" +
            "Content-Type: text/plain\r\n" +
            "\r\n" +
            "\(fileContent)\r\n" +
            "--\(boundary)--\r\n"
        let body = Body(string: multipartBody)

        // Act
        let (params, files) = body.multipart(boundary: boundary)

        // Assert – file uploads are stored separately
        XCTAssertTrue(params.isEmpty)
        XCTAssertFalse(files.isEmpty)
        if let file = files["file"] {
            XCTAssertEqual(file.filename, "test.txt")
        }
    }
}
