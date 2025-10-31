import XCTest
@testable import EntityAuthDomain
@testable import EntityAuthNetworking
@testable import EntityAuthCore

final class OrganizationServiceTests: XCTestCase {
    actor Recorder {
        private(set) var lastRequest: APIRequest?
        func record(_ req: APIRequest) { lastRequest = req }
        func get() -> APIRequest? { lastRequest }
    }

    struct MockAPIClient: APIClientType {
        let recorder: Recorder
        var currentConfig: EntityAuthConfig { .init(baseURL: URL(string: "https://api.test")!, workspaceTenantId: "w1", clientIdentifier: "ios", userDefaultsSuiteName: nil) }
        var workspaceTenantId: String? { "w1" }
        func updateConfiguration(_ update: (inout EntityAuthConfig) -> Void) {}
        func send(_ request: APIRequest) async throws -> Data {
            await recorder.record(request)
            return Data()
        }
        func send<T>(_ request: APIRequest, decode: T.Type) async throws -> T where T : Decodable {
            await recorder.record(request)
            // Return a minimal valid payload for switch-organization
            let json = "{\"accessToken\":\"new-token\",\"organizationId\":\"o1\"}"
            let data = json.data(using: .utf8)!
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    func testSwitchOrganizationCallsEndpointAndReturnsAccessToken() async throws {
        let recorder = Recorder()
        let client = MockAPIClient(recorder: recorder)
        let svc = OrganizationService(client: client)
        let token = try await svc.switchActive(workspaceTenantId: "w1", orgId: "o1")
        XCTAssertEqual(token, "new-token")
        let req = await recorder.get()
        XCTAssertEqual(req?.path, "/api/auth/switch-organization")
        XCTAssertEqual(req?.method, .post)
        XCTAssertEqual(req?.headers["content-type"], "application/json")
    }
}


