import Foundation
import XCTest
@testable import iTMUX

final class TmuxControlModeParserTests: XCTestCase {
    func testParseOutputDecodesEscapedPayload() async throws {
        let parser = TmuxControlModeParser()
        let data = Data("%output %0 hello\\040world\\012\n".utf8)

        let messages = await parser.parse(data)

        guard case let .output(paneId, payload)? = messages.first else {
            return XCTFail("Expected output control message")
        }

        XCTAssertEqual(paneId, "%0")
        XCTAssertEqual(String(data: payload, encoding: .utf8), "hello world\n")
    }

    func testParseSessionChangedMessage() async throws {
        let parser = TmuxControlModeParser()
        let data = Data("%session-changed $1 itmux\n".utf8)

        let messages = await parser.parse(data)

        guard case let .sessionChanged(sessionId, sessionName)? = messages.first else {
            return XCTFail("Expected session-changed control message")
        }

        XCTAssertEqual(sessionId, "$1")
        XCTAssertEqual(sessionName, "itmux")
    }
}
