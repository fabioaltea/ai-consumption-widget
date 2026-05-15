import SwiftUI

struct MenuBarView: View {
    @StateObject private var store = UsageStore()

    var body: some View {
        Group {
            if store.isOnboarding {
                OnboardingView(store: store)
            } else {
                UsageDashboardView(store: store)
            }
        }
        .frame(width: 320)
    }
}
