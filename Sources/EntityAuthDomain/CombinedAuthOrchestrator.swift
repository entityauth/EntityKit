import Foundation
import Combine

public enum CombinedAuthStage: Sendable, Equatable {
    case initializing
    case eaReady
    case convexAuthenticated
    case contextReady
    case error(String)
}

/// Orchestrates EA tokens → Convex auth → post-SSO bootstrap → context readiness.
/// The Convex integration is injected via closures so SDK stays decoupled.
public actor CombinedAuthOrchestrator {
    private let facade: EntityAuthFacade
    private let subject: CurrentValueSubject<CombinedAuthStage, Never>
    private var task: Task<Void, Never>?

    public init(facade: EntityAuthFacade) {
        self.facade = facade
        self.subject = CurrentValueSubject<CombinedAuthStage, Never>(.initializing)
    }

    public func publisher() -> AnyPublisher<CombinedAuthStage, Never> {
        subject.eraseToAnyPublisher()
    }

    public func start(
        fetchConvexAuthenticated: @escaping @Sendable () async -> Bool,
        ensureUser: @escaping @Sendable () async throws -> Void,
        ensureOrganization: @escaping @Sendable (_ eaOrgId: String?) async throws -> Void,
        waitForContext: @escaping @Sendable () async -> Bool
    ) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            await self.run(
                fetchConvexAuthenticated: fetchConvexAuthenticated,
                ensureUser: ensureUser,
                ensureOrganization: ensureOrganization,
                waitForContext: waitForContext
            )
        }
    }

    private func emit(_ stage: CombinedAuthStage) {
        subject.send(stage)
    }

    private func run(
        fetchConvexAuthenticated: @escaping @Sendable () async -> Bool,
        ensureUser: @escaping @Sendable () async throws -> Void,
        ensureOrganization: @escaping @Sendable (_ eaOrgId: String?) async throws -> Void,
        waitForContext: @escaping @Sendable () async -> Bool
    ) async {
        emit(.initializing)
        // 1) Wait for EA token
        do {
            try await waitForEAToken(timeoutSeconds: 30)
        } catch {
            emit(.error("EA token timeout"))
            return
        }
        emit(.eaReady)

        // 2) Authenticate Convex (caller retries/handles restart internally)
        let ok = await fetchConvexAuthenticated()
        guard ok else {
            emit(.error("Convex auth failed"))
            return
        }
        emit(.convexAuthenticated)

        // 3) Bootstrap: ensure user/org using SDK helper for EA org selection
        do {
            try await facade.bootstrapAfterSSO(
                options: .init(createEAOrgIfMissing: true, defaultOrgName: nil),
                ensureUser: ensureUser,
                ensureOrganization: ensureOrganization
            )
        } catch {
            emit(.error("Bootstrap failed: \(error.localizedDescription)"))
            return
        }

        // 4) Wait for server context to be ready
        let ready = await waitForContext()
        if ready {
            emit(.contextReady)
        } else {
            emit(.error("Context not ready"))
        }
    }

    private func waitForEAToken(timeoutSeconds: Int) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) <= Double(timeoutSeconds) {
            let snapshot = await facade.currentSnapshot()
            if let token = snapshot.accessToken, !token.isEmpty { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        throw NSError(domain: "CombinedAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "EA token wait timed out"])
    }
}


