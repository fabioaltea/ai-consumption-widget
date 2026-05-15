import SwiftUI

struct MenuBarView: View {
    @StateObject private var store = UsageStore()

    var body: some View {
        UsageDashboardView(store: store)
            .frame(width: 320)
    }
}
