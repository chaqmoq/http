import XCTest
import HTTPTests

var tests = [XCTestCaseEntry]()
tests += BodyTests.allTests()
tests += RequestTests.allTests()
tests += ResponseTests.allTests()
tests += ServerTests.allTests()
XCTMain(tests)
