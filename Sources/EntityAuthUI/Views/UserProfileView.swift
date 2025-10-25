import SwiftUI

public struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel

    public init(viewModel: UserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if let p = viewModel.profile {
                VStack(alignment: .leading, spacing: 8) {
                    Text(p.displayName).font(.title2)
                    Text(p.email).foregroundStyle(.secondary)
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                Text("No profile")
            }
        }
        .onAppear { viewModel.load() }
        .padding()
    }
}


