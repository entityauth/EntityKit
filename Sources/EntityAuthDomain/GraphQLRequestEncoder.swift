import Foundation
import EntityAuthCore

struct GraphQLRequestPayload: Encodable {
    let query: String
    let variables: [String: AnyCodable]
}

enum GraphQLRequestBuilder {
    static func make(query: String, variables: [String: Any]?) throws -> Data {
        let payload = GraphQLRequestPayload(query: query, variables: variables?.mapValues { AnyCodable($0) } ?? [:])
        do {
            return try JSONEncoder().encode(payload)
        } catch {
            throw EntityAuthError.encoding(error)
        }
    }
}
