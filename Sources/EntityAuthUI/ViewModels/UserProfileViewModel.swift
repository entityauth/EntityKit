import Foundation
import Combine
import EntityAuthDomain

public struct UserProfile: Equatable, Sendable {
    public var displayName: String
    public var email: String

    public init(displayName: String, email: String) {
        self.displayName = displayName
        self.email = email
    }
}

public final class UserProfileViewModel: ObservableObject {
    private let facade: Facade
    private var cancellables: Set<AnyCancellable> = []

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var profile: UserProfile?
    @Published public private(set) var errorMessage: String?

    public init(facade: Facade) {
        self.facade = facade
    }

    public func load() {
        isLoading = true
        errorMessage = nil
        // Placeholder: replace with facade call when ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.isLoading = false
            self?.profile = UserProfile(displayName: "Entity User", email: "user@example.com")
        }
    }
}


