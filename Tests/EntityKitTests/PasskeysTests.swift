import XCTest
@testable import EntityAuthDomain

final class PasskeysTests: XCTestCase {
    struct MockAPIClient: APIClientType {
        var currentConfig: EntityAuthCore.EntityAuthConfig { .init(baseURL: URL(string: "https://api.test")!, workspaceTenantId: "default", clientIdentifier: "test", userDefaultsSuiteName: nil) }
        var workspaceTenantId: String? { "default" }
        func send<T>(_ request: EntityAuthNetworking.APIRequest, decode: T.Type) async throws -> T where T : Decodable { throw NSError(domain: "", code: -1) }
        func send(_ request: EntityAuthNetworking.APIRequest) async throws -> Data { Data() }
        func updateConfiguration(_ update: (inout EntityAuthCore.EntityAuthConfig) -> Void) {}
    }

    actor DummyRefresh: RefreshService { func refresh() async throws -> RefreshResponse { throw EntityAuthError.refreshFailed } }

    func testDTOEncodingForWebAuthnRegistrationCredential() throws {
        let cred = WebAuthnRegistrationCredential(id: "id", rawId: "raw", response: .init(attestationObject: "ao", clientDataJSON: "cdj"))
        let data = try JSONEncoder().encode(cred)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"id\":"))
        XCTAssertTrue(json.contains("attestationObject"))
    }

    func testDTOEncodingForWebAuthnAuthenticationCredential() throws {
        let cred = WebAuthnAuthenticationCredential(id: "id", rawId: "raw", response: .init(authenticatorData: "ad", clientDataJSON: "cdj", signature: "sig", userHandle: nil))
        let data = try JSONEncoder().encode(cred)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("signature"))
        XCTAssertTrue(json.contains("clientDataJSON"))
    }
}


