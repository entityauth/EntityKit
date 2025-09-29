import Foundation

public enum EntityAuthError: Error, LocalizedError, Sendable, Equatable {
    case configurationMissingBaseURL
    case configurationMissingWorkspaceTenantId
    case unauthorized
    case network(statusCode: Int, message: String?)
    case decoding(DecodingError)
    case encoding(Error)
    case transport(Error)
    case refreshTokenMissing
    case refreshFailed
    case keychain(OSStatus)
    case storage(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .configurationMissingBaseURL:
            return "EntityAuth configuration missing base URL"
        case .unauthorized:
            return "Unauthorized"
        case .configurationMissingWorkspaceTenantId:
            return "EntityAuth configuration missing workspace tenant identifier"
        case let .network(statusCode, message):
            if let message, !message.isEmpty {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP \(statusCode)"
        case let .decoding(error):
            return "Decoding error: \(error.localizedDescription)"
        case let .encoding(error):
            return "Encoding error: \(error.localizedDescription)"
        case let .transport(error):
            return "Transport error: \(error.localizedDescription)"
        case .refreshTokenMissing:
            return "No refresh token available"
        case .refreshFailed:
            return "Refresh token request failed"
        case let .keychain(status):
            return "Keychain error (status: \(status))"
        case let .storage(message):
            return message
        case .invalidResponse:
            return "Invalid response"
        }
    }
}

extension EntityAuthError {
    public static func == (lhs: EntityAuthError, rhs: EntityAuthError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationMissingBaseURL, .configurationMissingBaseURL):
            return true
        case (.unauthorized, .unauthorized):
            return true
        case (.configurationMissingWorkspaceTenantId, .configurationMissingWorkspaceTenantId):
            return true
        case let (.network(lhsStatus, lhsMessage), .network(rhsStatus, rhsMessage)):
            return lhsStatus == rhsStatus && lhsMessage == rhsMessage
        case let (.decoding(lhsError), .decoding(rhsError)):
            return decodingErrorsEqual(lhsError, rhsError)
        case let (.encoding(lhsError), .encoding(rhsError)):
            return errorsEqual(lhsError, rhsError)
        case let (.transport(lhsError), .transport(rhsError)):
            return errorsEqual(lhsError, rhsError)
        case (.refreshTokenMissing, .refreshTokenMissing):
            return true
        case (.refreshFailed, .refreshFailed):
            return true
        case let (.keychain(lhsStatus), .keychain(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.storage(lhsMessage), .storage(rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidResponse, .invalidResponse):
            return true
        default:
            return false
        }
    }

    private static func decodingErrorsEqual(_ lhs: DecodingError, _ rhs: DecodingError) -> Bool {
        String(reflecting: lhs) == String(reflecting: rhs)
    }

    private static func errorsEqual(_ lhs: Error, _ rhs: Error) -> Bool {
        type(of: lhs) == type(of: rhs) && String(reflecting: lhs) == String(reflecting: rhs)
    }
}
