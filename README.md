# EntityKit

Swift package for integrating Entity authentication in iOS and macOS apps.

## Requirements
- iOS 15+ / macOS 13+
- Xcode 15+

## Installation (SPM)
Add the package via URL:

```
https://github.com/entityauth/EntityKit.git
```

Use version from `0.1.0`.

## Quickstart

```swift
import EntityKit

let facade = EntityAuthFacade(
    config: EntityAuthConfig(
        environment: .custom(URL(string: "https://api.your-app.com")!),
        workspaceTenantId: "tenant_123"
    )
)

Task {
    do {
        try await facade.login(request: LoginRequest(
            email: "alice@example.com",
            password: "P@ssw0rd!",
            workspaceTenantId: "tenant_123"
        ))

        let snapshot = facade.currentSnapshot()
        print("user", snapshot.userId ?? "-")
    } catch {
        print("Login failed", error)
    }
}
```

### SwiftUI integration

`EntityKit` ships composable building blocks. If you want a single observable object for SwiftUI, mirror the sample app’s `EntityAuthViewModel` (see `entity/Entity/Shared/EntityAuthViewModel.swift`). It wraps `EntityAuthFacade`, publishes the live snapshot, and exposes helpers such as `login`, `logout`, `createOrganization`, and `setUsername`.

```swift
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var snapshot: EntityAuthFacade.Snapshot
    private let facade: EntityAuthFacade

    init() {
        let config = EntityAuthConfig(workspaceTenantId: "tenant_123")
        self.facade = EntityAuthFacade(config: config)
        self.snapshot = facade.currentSnapshot()

        Task {
            for await value in facade.snapshotStream() {
                await MainActor.run { self.snapshot = value }
            }
        }
    }

    func login(email: String, password: String) async throws {
        try await facade.login(request: .init(email: email, password: password, workspaceTenantId: "tenant_123"))
    }
}
```

Use `snapshotStream()` (or the exposed Combine publisher) to bind authentication state throughout your app.

### Organizations & Sessions

```swift
let orgs = try await facade.organizations()
let active = try await facade.activeOrganization()

try await facade.createOrganization(name: "Acme", slug: "acme", ownerId: userId)
try await facade.switchOrg(orgId: "org_123")

try await facade.refreshTokens()
try await facade.logout()
```

### Configuration

The facade keeps base URL, client identifier, and user defaults persistence inside `EntityAuthConfig`. To persist a user-selected base URL, swap in `UserDefaultsBaseURLStore` as shown in the sample app’s `EntityAuthViewModel`.

## License
MIT
