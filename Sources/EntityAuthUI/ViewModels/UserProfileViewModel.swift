import Foundation
import Combine

public struct UserProfileData: Equatable, Sendable {
    public var displayName: String
    public var email: String

    public init(displayName: String, email: String) {
        self.displayName = displayName
        self.email = email
    }
}

@MainActor
public final class UserProfileViewModel: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var profile: UserProfileData?
    @Published public private(set) var errorMessage: String?

    public init() {}

    public func load() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.isLoading = false
            self?.profile = UserProfileData(displayName: "Entity User", email: "user@example.com")
        }
    }
}


