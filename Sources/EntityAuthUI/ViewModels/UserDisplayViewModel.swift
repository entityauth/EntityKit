import Foundation
import Combine
import SwiftUI

@MainActor
public final class UserDisplayViewModel: ObservableObject {
    public struct Output: Equatable {
        public var name: String?
        public var email: String?
        public var isLoading: Bool
    }

    @Published public private(set) var output: Output

    private let provider: AnyEntityAuthProvider
    private var task: Task<Void, Never>?

    public init(provider: AnyEntityAuthProvider) {
        self.provider = provider
        self.output = .init(name: nil, email: nil, isLoading: true)
        subscribe()
    }

    deinit { task?.cancel() }

    private func subscribe() {
        task = Task { [weak self] in
            guard let self else { return }
            self.output.isLoading = true
            print("[UserDisplayVM] Subscribing to snapshot stream...")
            let stream = await provider.snapshotStream()
            for await snap in stream {
                print("[UserDisplayVM] Snapshot userId=\(snap.userId ?? "nil") username=\(snap.username ?? "nil") email=\(snap.email ?? "nil")")
                self.output = .init(
                    name: snap.username,
                    email: snap.email,
                    isLoading: false
                )
            }
        }
    }
}


