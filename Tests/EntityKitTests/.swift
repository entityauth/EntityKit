import XCTest
@testable import EntityAuthDomain

final class DTODecodingTests: XCTestCase {
    func testLoginResponseMissingFieldFails() throws {
        let json = Data("{}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(LoginResponse.self, from: json))
    }

    func testSessionListResponseDecodes() throws {
        let jsonString = "{" +
        "\"sessions\":[{" +
        "\"id\":\"s1\",\"status\":\"active\",\"createdAt\":0.0,\"revokedAt\":null}]}"
        let json = jsonString.data(using: .utf8)!
        _ = try JSONDecoder().decode(SessionListResponse.self, from: json)
    }
}


