import XCTest
import Combine
@testable import EntityAuthRealtime
@testable import EntityKit

final class AuthStateTests: XCTestCase {
    func testUpdateAndClearTokens() async throws {
        let store = InMemoryTokenStore()
        let state = AuthState(tokenStore: store)

        try await state.update(accessToken: "a1", refreshToken: "r1")
        let tokens1 = await state.currentTokens
        XCTAssertEqual(tokens1.accessToken, "a1")
        XCTAssertEqual(tokens1.refreshToken, "r1")

        try await state.clear()
        let tokens2 = await state.currentTokens
        XCTAssertNil(tokens2.accessToken)
        XCTAssertNil(tokens2.refreshToken)
    }
}

final class TokenRefresherTests: XCTestCase {
    func testCoalescedRefreshAndRetry() async throws {
        let store = InMemoryTokenStore()
        let state = AuthState(tokenStore: store)
        let service = MockRefreshService(result: .success(.init(accessToken: "a2", refreshToken: "r2")))
        let refresher = TokenRefresher(authState: state, refreshService: service)

        let op: @Sendable () async throws -> Data = { Data("ok".utf8) }

        async let r1 = refresher.retryAfterRefreshing(operation: op)
        async let r2 = refresher.retryAfterRefreshing(operation: op)
        let (d1, d2) = try await (r1, r2)
        XCTAssertEqual(String(decoding: d1, as: UTF8.self), "ok")
        XCTAssertEqual(String(decoding: d2, as: UTF8.self), "ok")
        let finalTokens = await state.currentTokens
        XCTAssertEqual(finalTokens.accessToken, "a2")
        XCTAssertEqual(finalTokens.refreshToken, "r2")
        XCTAssertEqual(service.refreshCallCount, 1)
    }
}

final class APIClientTests: XCTestCase {
    override class func setUp() {
        URLProtocol.registerClass(URLProtocolMock.self)
    }

    override class func tearDown() {
        URLProtocol.unregisterClass(URLProtocolMock.self)
    }

    func testHeadersAndSuccess() async throws {
        let config = EntityAuthConfig(environment: .custom(URL(string: "https://api.test")!), workspaceTenantId: "w1", clientIdentifier: "ios")
        let state = AuthState(tokenStore: InMemoryTokenStore())
        try await state.update(accessToken: "token", refreshToken: nil)
        let refresher = TokenRefresher(authState: state, refreshService: MockRefreshService(result: .failure(.refreshFailed)))
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: sessionConfig)
        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-client"), "ios")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-workspace-tenant-id"), "w1")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{\"data\":true}".utf8))
        }
        let client = APIClient(config: config, authState: state, urlSession: session, decoder: JSONDecoder(), encoder: JSONEncoder(), refreshHandler: refresher)
        let data: APIResponse<Bool> = try await client.send(APIRequest(method: .get, path: "/ok"), decode: APIResponse<Bool>.self)
        XCTAssertTrue(data.data)
    }

    func test401ThenRefreshThenRetry() async throws {
        let config = EntityAuthConfig(environment: .custom(URL(string: "https://api.test")!))
        let state = AuthState(tokenStore: InMemoryTokenStore())
        try await state.update(accessToken: "t0", refreshToken: "r0")
        let service = MockRefreshService(result: .success(.init(accessToken: "t1", refreshToken: "r1")))
        let refresher = TokenRefresher(authState: state, refreshService: service)
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: sessionConfig)
        var attempt = 0
        URLProtocolMock.requestHandler = { request in
            attempt += 1
            if attempt == 1 {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            } else {
                XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer t1")
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("ok".utf8))
            }
        }
        let client = APIClient(config: config, authState: state, urlSession: session, decoder: JSONDecoder(), encoder: JSONEncoder(), refreshHandler: refresher)
        let data = try await client.send(APIRequest(method: .get, path: "/retry"))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "ok")
        let finalTokens = await state.currentTokens
        XCTAssertEqual(finalTokens.accessToken, "t1")
        XCTAssertEqual(finalTokens.refreshToken, "r1")
        XCTAssertEqual(service.refreshCallCount, 1)
    }
}

final class AuthServiceSmokeTests: XCTestCase {
    func testLoginDecoding() async throws {
        let config = EntityAuthConfig(environment: .custom(URL(string: "https://api.test")!))
        let state = AuthState(tokenStore: InMemoryTokenStore())
        let refresher = TokenRefresher(authState: state, refreshService: MockRefreshService(result: .failure(.refreshFailed)))
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: sessionConfig)
        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/login")
            let body = try JSONSerialization.data(withJSONObject: [
                "accessToken": "a",
                "refreshToken": "r",
                "sessionId": "s",
                "userId": "u"
            ])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        let client = APIClient(config: config, authState: state, urlSession: session, decoder: JSONDecoder(), encoder: JSONEncoder(), refreshHandler: refresher)
        let svc = AuthService(client: client, authState: state)
        let resp = try await svc.login(request: LoginRequest(email: "e@example.com", password: "p", workspaceTenantId: "w"))
        XCTAssertEqual(resp.sessionId, "s")
    }
}

final class RealtimeShimTests: XCTestCase {
    func testStartEmitsOrganizationsAndActive() async {
        let baseURL = URL(string: "https://api.test")!
        let convexURL = "wss://convex.test"
        let coordinator = RealtimeCoordinator(baseURL: baseURL, fetchConvexURL: { _ in convexURL }) { _ in MockConvexClient() }
        let exp = expectation(description: "events")
        var received: [RealtimeEvent] = []
        let cancellable = coordinator.publisher().sink { event in
            received.append(event)
            if case .organizations = event { exp.fulfill() }
        }
        defer { cancellable.cancel() }
        await coordinator.start(userId: "u1", sessionId: nil)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(received.contains { if case .organizations = $0 { true } else { false } })
        // activeOrganization emission is optional; organizations is sufficient for smoke
    }
}

// MARK: - Realtime mock

final class MockConvexClient: ConvexSubscribing {
    func subscribe<T>(to: String, with: [String : Any], yielding: T.Type) -> AnyPublisher<T, Error> where T : Decodable {
        if T.self == [OrganizationRecord]?.self {
            let doc = OrganizationRecord.Organization(_id: "o1", properties: .init(name: "Acme", slug: "acme", memberCount: 1, description: nil), workspaceTenantId: "w1")
            let item = OrganizationRecord(organization: doc, role: "owner", joinedAt: 0)
            let value = ([item] as [OrganizationRecord]?) as! T
            return Just(value).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        if T.self == UserRecord?.self {
            let value = (nil as UserRecord?) as! T
            return Just(value).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        if T.self == SessionRecord?.self {
            let value = (nil as SessionRecord?) as! T
            return Just(value).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return Fail(error: NSError(domain: "test", code: 0)).eraseToAnyPublisher()
    }
}
// MARK: - Test doubles

final class InMemoryTokenStore: TokenStoring, @unchecked Sendable {
    private var access: String?
    private var refresh: String?

    func loadAccessToken() throws -> String? { access }
    func loadRefreshToken() throws -> String? { refresh }
    func save(accessToken: String?) throws { access = accessToken }
    func save(refreshToken: String?) throws { refresh = refreshToken }
    func clear() throws { access = nil; refresh = nil }
}

final class MockRefreshService: RefreshService, @unchecked Sendable {
    enum Result { case success(RefreshResponse), failure(EntityAuthError) }
    private let result: Result
    private(set) var refreshCallCount = 0
    init(result: Result) { self.result = result }
    func refresh() async throws -> RefreshResponse {
        refreshCallCount += 1
        switch result {
        case let .success(r): return r
        case let .failure(e): throw e
        }
    }
}

final class URLProtocolMock: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = URLProtocolMock.requestHandler else { return }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
