import Foundation
import Combine

public final class AuthState: Sendable {
    public struct Tokens: Equatable, Sendable {
        public var accessToken: String?
        public var refreshToken: String?

        public init(accessToken: String?, refreshToken: String?) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    private let tokenStore: TokenStoring
    private let queue = DispatchQueue(label: "com.entityauth.AuthState", qos: .userInitiated)
    private let subject: CurrentValueSubject<Tokens, Never>

    public var tokensPublisher: AnyPublisher<Tokens, Never> {
        subject.eraseToAnyPublisher()
    }

    public var currentTokens: Tokens {
        subject.value
    }

    public init(tokenStore: TokenStoring) {
        self.tokenStore = tokenStore
        let tokens: Tokens = {
            let access = try? tokenStore.loadAccessToken()
            let refresh = try? tokenStore.loadRefreshToken()
            return Tokens(accessToken: access, refreshToken: refresh)
        }()
        self.subject = CurrentValueSubject(tokens)
    }

    public func update(accessToken: String?, refreshToken: String?) throws {
        try queue.sync {
            try tokenStore.save(accessToken: accessToken)
            try tokenStore.save(refreshToken: refreshToken)
            subject.send(Tokens(accessToken: accessToken, refreshToken: refreshToken))
        }
    }

    public func update(accessToken: String?) throws {
        try queue.sync {
            try tokenStore.save(accessToken: accessToken)
            let refresh = try tokenStore.loadRefreshToken()
            subject.send(Tokens(accessToken: accessToken, refreshToken: refresh))
        }
    }

    public func clear() throws {
        try queue.sync {
            try tokenStore.clear()
            subject.send(Tokens(accessToken: nil, refreshToken: nil))
        }
    }
}
