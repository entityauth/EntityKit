import SwiftUI

public struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.entityTheme) private var theme

    public init(viewModel: AuthViewModel = AuthViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("Sign in").font(.title2)
            HStack {
                TextField("Email", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            }
            Button(action: { viewModel.signIn(email: "", password: "") }) {
                if viewModel.isLoading { ProgressView() } else { Text("Continue") }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.primary)
        }
        .padding()
        .background(theme.colors.background)
        .clipShape(RoundedRectangle(cornerRadius: theme.design.cornerRadius))
    }
}


