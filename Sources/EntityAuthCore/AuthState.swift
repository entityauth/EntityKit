import Foundation
import Combine

public actor AuthState {
    public struct Tokens: Equatable, Sendable {
        public var accessToken: String?
        public var refreshToken: String?

        public init(accessToken: String?, refreshToken: String?) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
        }
    }

    private let tokenStore: TokenStoring
    private nonisolated(unsafe) let subject: CurrentValueSubject<Tokens, Never>
    private var _currentTokens: Tokens

    public nonisolated var tokensPublisher: AnyPublisher<Tokens, Never> {
        subject.eraseToAnyPublisher()
    }

    public var currentTokens: Tokens {
        _currentTokens
    }

    public init(tokenStore: TokenStoring) {
        self.tokenStore = tokenStore
        let tokens: Tokens = {
            let access = try? tokenStore.loadAccessToken()
            let refresh = try? tokenStore.loadRefreshToken()
            return Tokens(accessToken: access, refreshToken: refresh)
        }()
        self._currentTokens = tokens
        self.subject = CurrentValueSubject(tokens)
    }

    public func update(accessToken: String?, refreshToken: String?) throws {
        try tokenStore.save(accessToken: accessToken)
        try tokenStore.save(refreshToken: refreshToken)
        let newTokens = Tokens(accessToken: accessToken, refreshToken: refreshToken)
        _currentTokens = newTokens
        subject.send(newTokens)
    }

    public func update(accessToken: String?) throws {
        try tokenStore.save(accessToken: accessToken)
        let refresh = try tokenStore.loadRefreshToken()
        let newTokens = Tokens(accessToken: accessToken, refreshToken: refresh)
        _currentTokens = newTokens
        subject.send(newTokens)
    }

    public func clear() throws {
        try tokenStore.clear()
        let clearedTokens = Tokens(accessToken: nil, refreshToken: nil)
        _currentTokens = clearedTokens
        subject.send(clearedTokens)
    }
}
