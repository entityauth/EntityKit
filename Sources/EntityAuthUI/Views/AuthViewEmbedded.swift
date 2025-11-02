import SwiftUI
import EntityAuthDomain

/// Simple embedded auth component - shows the authentication form directly embedded in your view.
/// This is a clean 1-line API for auth - no TabView, no complexity.
public struct AuthViewEmbedded: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        #if os(iOS)
        let maxWidth: CGFloat = 380
        #else
        let maxWidth: CGFloat = 448
        #endif
        
        return HStack {
            Spacer()
            VStack(spacing: 24) {
                // Entity Auth branding
                Text("Entity Auth")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                
                // Auth form
                AuthGate()
            }
            .frame(maxWidth: maxWidth)
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

