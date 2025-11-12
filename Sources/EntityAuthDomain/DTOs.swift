import Foundation

public struct LoginRequest: Encodable, Sendable {
    public let email: String
    public let password: String
    public let workspaceTenantId: String

    public init(email: String, password: String, workspaceTenantId: String) {
        self.email = email
        self.password = password
        self.workspaceTenantId = workspaceTenantId
    }
}

public struct LoginResponse: Decodable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let sessionId: String
    public let userId: String
}

public struct RegisterRequest: Encodable, Sendable {
    public enum WorkspaceRole: String, Encodable, Sendable {
        case owner
        case member
    }
    public let email: String
    public let password: String
    public let workspaceTenantId: String
    public let defaultWorkspaceRole: WorkspaceRole?

    public init(email: String, password: String, workspaceTenantId: String, defaultWorkspaceRole: WorkspaceRole? = nil) {
        self.email = email
        self.password = password
        self.workspaceTenantId = workspaceTenantId
        self.defaultWorkspaceRole = defaultWorkspaceRole
    }
}

public struct RegisterResponse: Decodable, Sendable {
    public let success: Bool
}

// MARK: - Passkeys

public struct BeginRegistrationResponse: Decodable, Sendable {
    public struct Options: Decodable, Sendable {
        public let challenge: String
        public let rpId: String
    }
    public let challengeId: String
    public let options: Options
}

public struct FinishRegistrationResponse: Decodable, Sendable {
    public let ok: Bool
    public let credentialEntityId: String?
}

public struct BeginAuthenticationResponse: Decodable, Sendable {
    public struct Options: Decodable, Sendable {
        public let challenge: String
        public let rpId: String
        public let allowCredentialIds: [String]?
    }
    public let challengeId: String
    public let options: Options
}

// WebAuthn credential payloads for server routes
public struct WebAuthnRegistrationCredential: Encodable, Sendable {
    public struct Response: Encodable, Sendable {
        public let attestationObject: String
        public let clientDataJSON: String
        public init(attestationObject: String, clientDataJSON: String) {
            self.attestationObject = attestationObject
            self.clientDataJSON = clientDataJSON
        }
    }
    public let id: String
    public let rawId: String
    public let type: String
    public let response: Response

    public init(id: String, rawId: String, type: String = "public-key", response: Response) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
    }
}

public struct WebAuthnAuthenticationCredential: Encodable, Sendable {
    public struct Response: Encodable, Sendable {
        public let authenticatorData: String
        public let clientDataJSON: String
        public let signature: String
        public let userHandle: String?
        public init(authenticatorData: String, clientDataJSON: String, signature: String, userHandle: String?) {
            self.authenticatorData = authenticatorData
            self.clientDataJSON = clientDataJSON
            self.signature = signature
            self.userHandle = userHandle
        }
    }
    public let id: String
    public let rawId: String
    public let type: String
    public let response: Response

    public init(id: String, rawId: String, type: String = "public-key", response: Response) {
        self.id = id
        self.rawId = rawId
        self.type = type
        self.response = response
    }
}

public struct PasskeyAttestation: Encodable, Sendable {
    public let credentialId: String
    public let publicKeyCose: String
    public let signCount: Int?
    public let transports: [String]?
    public let aaguid: String?
    public let backupEligible: Bool?
    public let backupState: String?
    public let attestationFmt: String?

    public init(
        credentialId: String,
        publicKeyCose: String,
        signCount: Int? = nil,
        transports: [String]? = nil,
        aaguid: String? = nil,
        backupEligible: Bool? = nil,
        backupState: String? = nil,
        attestationFmt: String? = nil
    ) {
        self.credentialId = credentialId
        self.publicKeyCose = publicKeyCose
        self.signCount = signCount
        self.transports = transports
        self.aaguid = aaguid
        self.backupEligible = backupEligible
        self.backupState = backupState
        self.attestationFmt = attestationFmt
    }
}

public struct OrganizationSummaryDTO: Decodable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
}

public struct ActiveOrganizationDTO: Decodable, Sendable {
    public let orgId: String
    public let name: String?
    public let slug: String?
    public let memberCount: Int?
    public let role: String
    public let joinedAt: Double
    public let workspaceTenantId: String?
    public let description: String?
}

public struct UsernameCheckResponse: Decodable, Sendable {
    public let valid: Bool
    public let available: Bool
}

public struct UsernameSetRequest: Encodable {
    public let username: String
}

public struct SessionSummaryDTO: Decodable, Sendable {
    public let id: String
    public let status: String
    public let createdAt: Double
    public let revokedAt: Double?
}

public struct SessionListResponse: Decodable, Sendable {
    public let sessions: [SessionSummaryDTO]
}

public struct RevokeSessionRequest: Encodable {
    public let sessionId: String
}

public struct RevokeSessionsByUserRequest: Encodable {
    public let userId: String
}

public struct UserResponse: Decodable, Sendable {
    public let id: String
    public let email: String?
    public let username: String?
    public let imageUrl: String?
    public let workspaceTenantId: String?
}

public struct BootstrapResponse: Decodable, Sendable {
    public struct User: Decodable, Sendable {
        public let id: String
        public let email: String?
        public let username: String?
        public let imageUrl: String?
        public let workspaceTenantId: String?
    }
    public struct Organization: Decodable, Sendable {
        public let orgId: String
        public let name: String?
        public let slug: String?
        public let memberCount: Int?
        public let role: String
        public let joinedAt: Double
        public let workspaceTenantId: String?
        public let description: String?
    }
    public let user: User
    public let organizations: [Organization]
    public let activeOrganizationId: String?
}

public struct EntityDTO: Decodable, Sendable {
    public let id: String
    public let kind: String?
    public let workspaceTenantId: String?
    public let properties: [String: AnyCodable]?
    public let metadata: [String: AnyCodable]?
    public let status: String?
    public let createdAt: Double?
    public let updatedAt: Double?
}

public struct ListEntitiesFilter: Encodable, Sendable {
    public var status: String?
    public var email: String?
    public var slug: String?

    public init(status: String? = nil, email: String? = nil, slug: String? = nil) {
        self.status = status
        self.email = email
        self.slug = slug
    }
}

public struct UserByEmailRequest: Encodable {
    public let email: String
}

public struct WorkspaceMemberDTO: Decodable, Sendable {
    public let id: String
    public let username: String?
    public let imageUrl: String?
    public let email: String?
}

public struct GraphQLRequest: Encodable {
    public let query: String
    public let variables: [String: AnyCodable]
}

public struct GraphQLWrapper<T: Decodable>: Decodable {
    public let data: T?
}
