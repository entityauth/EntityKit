import SwiftUI
import EntityAuthDomain
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

/// An editable user display component for profile editing
/// Shows user avatar, name, and email with editable text fields
public struct UserDisplayEditable: View {
    @StateObject private var viewModel: UserDisplayEditableViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showImagePicker = false
    
    #if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif
    
    private let onSave: ((String, String) -> Void)?
    private let onCancel: (() -> Void)?
    private let onImageSelected: ((Data) -> Void)?
    
    /// Initialize with provider and callbacks
    public init(
        provider: AnyEntityAuthProvider,
        onSave: ((String, String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onImageSelected: ((Data) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: UserDisplayEditableViewModel(provider: provider))
        self.onSave = onSave
        self.onCancel = onCancel
        self.onImageSelected = onImageSelected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Avatar Section
            HStack(spacing: 16) {
                avatarView
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Picture")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Click to upload a new photo")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Editable Fields
            VStack(alignment: .leading, spacing: 16) {
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("", text: $viewModel.editedName, prompt: Text("Enter your name"))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                #if os(iOS)
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                #else
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                                #endif
                            }
                        )
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    TextField("", text: $viewModel.editedEmail, prompt: Text("Enter your email"))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                #if os(iOS)
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5))
                                #else
                                Capsule()
                                    .fill(colorScheme == .dark ? Color(.systemGray).opacity(0.1) : Color(.systemGray).opacity(0.2))
                                #endif
                            }
                        )
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        #endif
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Cancel Button
                Button(action: {
                    viewModel.resetFields()
                    onCancel?()
                }) {
                    Text("Cancel")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                #if os(iOS)
                                if #available(iOS 26.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #elseif os(macOS)
                                if #available(macOS 15.0, *) {
                                    Capsule()
                                        .fill(.regularMaterial)
                                        .glassEffect(.regular.interactive(true), in: .capsule)
                                } else {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                                #else
                                Capsule()
                                    .fill(.quaternary)
                                #endif
                            }
                        )
                }
                .buttonStyle(.plain)
                
                // Save Button
                Button(action: {
                    onSave?(viewModel.editedName, viewModel.editedEmail)
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text("Save Changes")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            #if os(iOS)
                            if #available(iOS 26.0, *) {
                                Capsule()
                                    .fill(.blue.gradient)
                                    .glassEffect(.regular.interactive(true), in: .capsule)
                            } else {
                                Capsule()
                                    .fill(.blue.gradient)
                            }
                            #elseif os(macOS)
                            if #available(macOS 15.0, *) {
                                Capsule()
                                    .fill(.blue.gradient)
                                    .glassEffect(.regular.interactive(true), in: .capsule)
                            } else {
                                Capsule()
                                    .fill(.blue.gradient)
                            }
                            #else
                            Capsule()
                                .fill(.blue.gradient)
                            #endif
                        }
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving || !viewModel.hasChanges)
                .opacity((viewModel.isSaving || !viewModel.hasChanges) ? 0.5 : 1.0)
            }
        }
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        Group {
            #if os(iOS)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                avatarContent
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        onImageSelected?(data)
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
                            onImageSelected?(data)
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
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 80, height: 80)
                
                Text(userInitial(from: viewModel.editedName))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
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
    
    // MARK: - Helpers
    
    private func userInitial(from name: String) -> String {
        guard !name.isEmpty else { return "U" }
        return String(name.prefix(1).uppercased())
    }
}

// MARK: - View Model

@MainActor
private final class UserDisplayEditableViewModel: ObservableObject {
    @Published var editedName: String = ""
    @Published var editedEmail: String = ""
    @Published var isSaving: Bool = false
    
    private var originalName: String = ""
    private var originalEmail: String = ""
    
    private let provider: AnyEntityAuthProvider
    private var task: Task<Void, Never>?
    
    var hasChanges: Bool {
        editedName != originalName || editedEmail != originalEmail
    }
    
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
                
                // Only update if we haven't edited yet
                if self.editedName.isEmpty && self.editedEmail.isEmpty {
                    self.editedName = name
                    self.editedEmail = email
                }
                
                self.originalName = name
                self.originalEmail = email
            }
        }
    }
    
    func resetFields() {
        editedName = originalName
        editedEmail = originalEmail
    }
}

