import SwiftUI

public struct UserDisplay: View {
    @StateObject private var viewModel: UserDisplayViewModel

    /// Explicit provider injection so SwiftUI can observe the view model with @StateObject.
    public init(provider: AnyEntityAuthProvider) {
        _viewModel = StateObject(wrappedValue: UserDisplayViewModel(provider: provider))
    }

    public var body: some View {
        let out = viewModel.output as UserDisplayViewModel.Output?
        VStack(alignment: .leading, spacing: 6) {
            if out == nil || out!.isLoading {
                RoundedRectangle(cornerRadius: 6).fill(.tertiary).frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(width: 160, height: 12)
            } else {
                Text(out!.name ?? "User").font(.headline)
                Text(out!.email ?? "").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}


