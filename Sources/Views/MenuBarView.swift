import SwiftUI

struct MenuBarView: View {
    let onHeightChange: (CGFloat) -> Void
    @StateObject private var store = UsageStore()

    var body: some View {
        UsageDashboardView(store: store, onHeightChange: onHeightChange)
            .frame(width: 320)
    }
}
