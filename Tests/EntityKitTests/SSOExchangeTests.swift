import XCTest
@testable import EntityAuthDomain

final class SSOExchangeTests: XCTestCase {
    override class func setUp() {
        URLProtocol.registerClass(URLProtocolMock.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(URLProtocolMock.self)
    }

    func testHandleCallbackStaticExchangesTicket() async throws {
        // Arrange a fake ticket callback
        let base = URL(string: "https://api.test")!
        var components = URLComponents(string: "myapp://callback")!
        components.queryItems = [URLQueryItem(name: "ticket", value: "t123")] 
        let callback = components.url!

        // Intercept the exchange request and return a valid payload
        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/exchange-ticket")
            XCTAssertEqual(request.httpMethod, "POST")
            let json = "{\"accessToken\":\"a\",\"refreshToken\":\"r\",\"sessionId\":\"s\",\"userId\":\"u\"}"
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }

        // Act
        let result = try await EntityAuthSSO.handleCallbackStatic(baseURL: base, url: callback)

        // Assert
        XCTAssertEqual(result.accessToken, "a")
        XCTAssertEqual(result.refreshToken, "r")
        XCTAssertEqual(result.sessionId, "s")
        XCTAssertEqual(result.userId, "u")
    }
}


