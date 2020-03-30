import XCTest
import HTTPTests

var tests = [XCTestCaseEntry]()
tests += BodyTests.allTests()
XCTMain(tests)
