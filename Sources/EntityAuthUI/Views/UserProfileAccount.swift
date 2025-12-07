import SwiftUI
import EntityAuthDomain
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

struct AccountSectionView: View {
    let provider: AnyEntityAuthProvider
    let onSave: (String, String) -> Void
    let onImageSelected: (Data) -> Void
    var showsHeader: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: AccountSectionViewModel
    
    init(
        provider: AnyEntityAuthProvider,
        onSave: @escaping (String, String) -> Void,
        onImageSelected: @escaping (Data) -> Void,
        showsHeader: Bool = true
    ) {
        self.provider = provider
        self.onSave = onSave
        self.onImageSelected = onImageSelected
        self.showsHeader = showsHeader
        self._viewModel = StateObject(wrappedValue: AccountSectionViewModel(provider: provider))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current user info pill (read-only)
            currentUserPill
            
            // Editable fields section (no pill)
            editableFieldsSection
        }
    }
    
    // MARK: - Current User Info Pill
    
    private var currentUserPill: some View {
        HStack(spacing: 12) {
            UserDisplay(provider: provider, variant: .plain)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(pillBackground)
        .contentShape(Capsule())
    }
    
    // MARK: - Editable Fields Section
    
    @State private var showImagePicker = false
    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif
    
    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Profile Picture
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Picture")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                editableAvatar
            }
            
            // Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 12) {
                    TextField("", text: $viewModel.editedName, prompt: Text("Enter your name"))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                #if os(iOS)
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray4))
                                #else
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.2) : Color(.systemGray).opacity(0.3))
                                #endif
                            }
                        )
                        .disabled(viewModel.isSavingName)
                    
                    if viewModel.editedName != viewModel.originalName && !viewModel.editedName.isEmpty {
                        Button(action: {
                            Task {
                                await viewModel.saveName()
                                onSave(viewModel.editedName, viewModel.editedEmail)
                            }
                        }) {
                            if viewModel.isSavingName {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSavingName)
                    }
                }
            }
            
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 12) {
                    TextField("", text: $viewModel.editedEmail, prompt: Text("Enter your email"))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                #if os(iOS)
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray4))
                                #else
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.2) : Color(.systemGray).opacity(0.3))
                                #endif
                            }
                        )
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        #endif
                        .disabled(viewModel.isSavingEmail)
                    
                    if viewModel.editedEmail != viewModel.originalEmail && !viewModel.editedEmail.isEmpty {
                        Button(action: {
                            Task {
                                await viewModel.saveEmail()
                                onSave(viewModel.editedName, viewModel.editedEmail)
                            }
                        }) {
                            if viewModel.isSavingEmail {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSavingEmail)
                    }
                }
            }
        }
    }
    
    // MARK: - Editable Avatar
    
    private var editableAvatar: some View {
        Group {
            #if os(iOS)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                avatarContent
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        onImageSelected(data)
                    }
                }
            }
            #else
            Button(action: {
                showImagePicker = true
            }) {
                avatarContent
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showImagePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            onImageSelected(data)
                        }
                    }
                case .failure(let error):
                    print("Image picker error: \(error.localizedDescription)")
                }
            }
            #endif
        }
    }
    
    private var avatarContent: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar Circle
            if let urlString = viewModel.imageUrl, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(.tertiary.opacity(0.5))
                            .frame(width: 80, height: 80)
                            .overlay { ProgressView().scaleEffect(0.7) }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
            
            // Edit Badge
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .offset(x: -4, y: -4)
        }
    }
    
    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(.blue.gradient)
                .frame(width: 80, height: 80)
            
            Text(userInitial(from: viewModel.originalName))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    
    // MARK: - Glass Effect
    
    @ViewBuilder
    private var pillBackground: some View {
        Group {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                Capsule()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            #elseif os(macOS)
            if #available(macOS 15.0, *) {
                Capsule()
                    .fill(.regularMaterial)
                    .glassEffect(.regular.interactive(true), in: .capsule)
            } else {
                Capsule()
                    .fill(.ultraThinMaterial)
            }
            #else
            Capsule()
                .fill(.ultraThinMaterial)
            #endif
        }
    }
    
    // MARK: - Helpers
    
    private func userInitial(from name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "U" }
        return String(name.prefix(1).uppercased())
    }
}

// MARK: - View Model

@MainActor
private final class AccountSectionViewModel: ObservableObject {
    @Published var editedName: String = ""
    @Published var editedEmail: String = ""
    @Published var originalName: String = ""
    @Published var originalEmail: String = ""
    @Published var imageUrl: String?
    @Published var isSavingName: Bool = false
    @Published var isSavingEmail: Bool = false
    
    private let provider: AnyEntityAuthProvider
    private var task: Task<Void, Never>?
    
    init(provider: AnyEntityAuthProvider) {
        self.provider = provider
        subscribe()
    }
    
    deinit { task?.cancel() }
    
    private func subscribe() {
        task = Task { [weak self] in
            guard let self else { return }
            let stream = await provider.snapshotStream()
            for await snapshot in stream {
                let name = snapshot.username ?? ""
                let email = snapshot.email ?? ""
                
                if self.editedName.isEmpty && self.editedEmail.isEmpty {
                    self.editedName = name
                    self.editedEmail = email
                }
                
                self.originalName = name
                self.originalEmail = email
                self.imageUrl = snapshot.imageUrl
            }
        }
    }
    
    func saveName() async {
        guard editedName != originalName, !editedName.isEmpty else { return }
        isSavingName = true
        defer { isSavingName = false }
        
        do {
            try await provider.setUsername(editedName)
            originalName = editedName
        } catch {
            print("[AccountSection] Failed to save name: \(error)")
            editedName = originalName
        }
    }
    
    func saveEmail() async {
        guard editedEmail != originalEmail, !editedEmail.isEmpty else { return }
        isSavingEmail = true
        defer { isSavingEmail = false }
        
        do {
            try await provider.setEmail(editedEmail)
            originalEmail = editedEmail
        } catch {
            print("[AccountSection] Failed to save email: \(error)")
            editedEmail = originalEmail
        }
    }
}
