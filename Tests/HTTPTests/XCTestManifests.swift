import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BodyTests.allTests),
        testCase(ProtocolVersionTests.allTests),
        testCase(RequestTests.allTests),
        testCase(ResponseTests.allTests),
        testCase(ServerTests.allTests)
    ]
}
#endif
