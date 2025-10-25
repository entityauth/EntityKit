import SwiftUI

public struct UserButton: View {
    public init() {}

    public var body: some View {
        Button(action: {}) {
            ZStack {
                Circle().fill(.secondary).frame(width: 36, height: 36)
                Image(systemName: "person.fill").foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}


