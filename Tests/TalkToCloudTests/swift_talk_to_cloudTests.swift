import XCTest
@testable import swift_talk_to_cloud

class swift_talk_to_cloudTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(swift_talk_to_cloud().text, "Hello, World!")
    }


    static var allTests : [(String, (swift_talk_to_cloudTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
