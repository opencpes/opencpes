import XCTest
@testable import OpenCPE

final class OpenCPETests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(OpenCPE().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
