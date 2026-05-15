import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "brain.filled.head.profile")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)

                Text("AI Usage Widget")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Read Claude consumption from the local Claude CLI\ndirectly from the menu bar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                if let error = store.loginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text("The widget fetches your Claude usage directly from the Anthropic API.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await store.refresh() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "brain")
                        Text("Fetch Usage")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)

                Text("More services coming soon")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding(.bottom, 8)
        }
        .padding(20)
        .frame(width: 320, height: 300)
    }
}
