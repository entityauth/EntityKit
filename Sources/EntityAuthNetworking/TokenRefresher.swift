import Foundation
import EntityAuthCore

public protocol RefreshService: Sendable {
    func refresh() async throws -> RefreshResponse
}

public struct RefreshResponse: Sendable, Decodable {
    public let accessToken: String
    public let refreshToken: String?
    public init(accessToken: String, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public actor TokenRefresher: TokenRefreshHandling {
    public let authState: AuthState
    private var refreshService: RefreshService
    private var inFlightTask: Task<Data, Error>?

    public init(authState: AuthState, refreshService: RefreshService) {
        self.authState = authState
        self.refreshService = refreshService
    }

    public func retryAfterRefreshing(operation: @Sendable @escaping () async throws -> Data) async throws -> Data {
        if let existing = inFlightTask {
            return try await existing.value
        }
        let operationCopy = operation
        let task = Task { () throws -> Data in
            do {
                let response = try await refreshService.refresh()
                try await authState.update(accessToken: response.accessToken, refreshToken: response.refreshToken)
                return try await operationCopy()
            } catch let error as EntityAuthError {
                throw error
            } catch {
                throw EntityAuthError.refreshFailed
            }
        }
        inFlightTask = task
        do {
            let result = try await task.value
            cleanup()
            return result
        } catch {
            cleanup()
            throw error
        }
    }

    private func cleanup() { inFlightTask = nil }

    public func replaceRefreshService(with service: RefreshService) {
        refreshService = service
    }
}
