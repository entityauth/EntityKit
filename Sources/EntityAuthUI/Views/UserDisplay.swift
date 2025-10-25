import SwiftUI

public struct UserDisplay: View {
    @Environment(\.entityAuthProvider) private var provider
    @State private var viewModel: UserDisplayViewModel? = nil

    public init() {}

    public var body: some View {
        let out = viewModel?.output
        VStack(alignment: .leading, spacing: 6) {
            if out == nil || out!.isLoading {
                RoundedRectangle(cornerRadius: 6).fill(.tertiary).frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(width: 160, height: 12)
            } else {
                Text(out!.name ?? "User").font(.headline)
                Text(out!.email ?? "").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = UserDisplayViewModel(provider: provider)
            }
        }
    }
}


