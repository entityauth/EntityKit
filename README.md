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

@MainActor
func signIn() async {
    do {
        try await EntityAuth.shared.login(email: "alice@example.com", password: "P@ssw0rd!", tenantId: "t1")
        // Use EntityAuth.shared API for authorized calls
    } catch {
        print("Login failed: \(error)")
    }
}
```

 

### Username APIs
```swift
try await EntityAuth.shared.setUsername("alice")
let (id, username) = try await EntityAuth.shared.fetchCurrentUser()
let ok = try await EntityAuth.shared.checkUsernameAvailability("alice")
```

### Configuration
Default base URL is `https://entity-auth.com`. To override (e.g., for dev):
```swift
EntityAuth.shared.updateBaseURL("http://localhost:3000")
```

## License
MIT
