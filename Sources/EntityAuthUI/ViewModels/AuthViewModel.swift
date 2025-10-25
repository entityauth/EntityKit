import Foundation
import Combine

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isSignedIn: Bool = false

    public init() {}

    public func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isLoading = false
            self?.isSignedIn = true
        }
    }

    public func signOut() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.isLoading = false
            self?.isSignedIn = false
        }
    }
}


