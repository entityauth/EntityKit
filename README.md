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

### People Service

The `PeopleService` protocol provides a unified interface for managing invitations, friend requests, and user search. Use `PeopleStore` for SwiftUI integration:

```swift
import EntityKit
import EntityAuthDomain
import EntityAuthUI

// Create PeopleService instance
let peopleService = PeopleService(
    invitationService: facade.invitationService,
    friendService: facade.friendService,
    client: facade.client
)

// Use PeopleStore in SwiftUI
@MainActor
class MyViewModel: ObservableObject {
    @Published private(set) var peopleStore: PeopleStore?
    
    init(facade: EntityAuthFacade, userId: String) {
        let peopleService = PeopleService(
            invitationService: facade.invitationService,
            friendService: facade.friendService,
            client: facade.client
        )
        self.peopleStore = PeopleStore(
            peopleService: peopleService,
            userId: userId
        )
    }
}

// In your SwiftUI view
struct PeopleView: View {
    @StateObject var store: PeopleStore
    
    var body: some View {
        VStack {
            // Search
            TextField("Search users", text: Binding(
                get: { store.searchQuery },
                set: { store.updateSearchQuery($0) }
            ))
            
            if store.isSearching {
                ProgressView()
            }
            
            if let error = store.searchError {
                Text("Error: \(error.localizedDescription)")
            }
            
            List(store.searchResults) { person in
                Text(person.username ?? person.email ?? "Unknown")
            }
            
            // Invitations
            Button("Load Invitations") {
                Task {
                    await store.loadInvitations()
                }
            }
            
            List(store.receivedInvitations) { invitation in
                Button("Accept") {
                    Task {
                        await store.acceptInvitation(invitationId: invitation.id)
                    }
                }
            }
            
            // Friends
            Button("Load Friends") {
                Task {
                    await store.loadFriendConnections()
                }
            }
            
            List(store.friendConnections) { friend in
                Text(friend.username ?? friend.email ?? "Unknown")
            }
        }
    }
}
```

### PeopleService API

The `PeopleServiceProtocol` provides methods for:

**Search:**
- `searchUsers(q:limit:)` - Search for users by email or username

**Invitations:**
- `startInvitation(orgId:inviteeUserId:role:)` - Create an organization invitation
- `acceptInvitation(token:)` - Accept invitation by token
- `acceptInvitationById(invitationId:)` - Accept invitation by ID
- `declineInvitation(invitationId:)` - Decline an invitation
- `revokeInvitation(invitationId:)` - Revoke a sent invitation
- `resendInvitation(invitationId:)` - Resend an invitation
- `listSentInvitations(inviterId:cursor:limit:)` - List sent invitations
- `listReceivedInvitations(userId:cursor:limit:)` - List received invitations

**Friends:**
- `startFriendRequest(targetUserId:)` - Send a friend request
- `acceptFriendRequest(requestId:)` - Accept a friend request
- `declineFriendRequest(requestId:)` - Decline a friend request
- `cancelFriendRequest(requestId:)` - Cancel a sent friend request
- `listSentFriendRequests(requesterId:cursor:limit:)` - List sent friend requests
- `listReceivedFriendRequests(targetUserId:cursor:limit:)` - List received friend requests
- `listFriendConnections()` - List confirmed friends
- `removeFriendConnection(friendId:)` - Remove a friend connection

### PeopleStore Features

`PeopleStore` is an `@ObservableObject` that:
- Manages search with automatic debouncing (250ms)
- Handles cancellation of in-flight requests
- Provides separate loading states for search, invitations, friends, and connections
- Translates domain errors into `PeopleError` for UI display
- Supports pagination with cursor-based loading

### Configuration

The facade keeps base URL, client identifier, and user defaults persistence inside `EntityAuthConfig`. To persist a user-selected base URL, swap in `UserDefaultsBaseURLStore` as shown in the sample app's `EntityAuthViewModel`.

## License
MIT
