import Foundation
import Combine
import EntityAuthDomain

public final class AuthViewModel: ObservableObject {
    private let authService: AuthService
    private var cancellables: Set<AnyCancellable> = []

    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isSignedIn: Bool = false

    public init(authService: AuthService) {
        self.authService = authService
        // TODO: wire to real auth state when available
    }

    public func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        // Placeholder: integrate with authService when API is ready
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


