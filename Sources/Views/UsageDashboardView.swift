import AppKit
import SwiftUI

struct UsageDashboardView: View {
    private enum UsageWindow: String {
        case fiveHours = "5 hours"
        case weekly = "weekly"
    }

    @ObservedObject var store: UsageStore
    @State private var selectedWindow: UsageWindow = .weekly
    @State private var expandedServiceId: UUID? = nil

    private var sevenDayPercentage: Double {
        (store.services.first?.usageRatio ?? 0.0) * 100
    }

    private var fiveHourPercentage: Double {
        metricPercentage(from: store.services.first?.secondaryMetricValue)
    }

    private var selectedPercentage: Double {
        selectedWindow == .weekly ? sevenDayPercentage : fiveHourPercentage
    }

    private var selectedProgressRatio: Double {
        min(max(selectedPercentage / 100, 0), 1)
    }

    private var selectedMetricLabel: String {
        switch selectedWindow {
        case .fiveHours:
            return store.services.first?.secondaryMetricLabel ?? "5-Hour Usage"
        case .weekly:
            return store.services.first?.primaryMetricLabel ?? "7-Day Usage"
        }
    }

    private var selectedMetricValue: String {
        switch selectedWindow {
        case .fiveHours:
            return store.services.first?.secondaryMetricValue ?? "0%"
        case .weekly:
            return store.services.first?.primaryMetricValue ?? "0%"
        }
    }

    private var selectedResetText: String? {
        guard let service = store.services.first else {
            return nil
        }

        switch selectedWindow {
        case .weekly:
            guard let resetDate = service.resetDate else { return nil }
            return shortResetText(from: resetDate)
        case .fiveHours:
            guard let resetDate = service.secondaryResetDate else { return nil }
            return shortResetText(from: resetDate)
        }
    }

    private var refreshHelpText: String {
        if let lastRefresh = store.lastRefresh {
            return "Refresh usage\nLast sync: \(lastRefresh.formatted(date: .abbreviated, time: .shortened))"
        }

        return "Refresh usage"
    }

    private var usageColor: Color {
        let ratio = selectedProgressRatio
        switch ratio {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .orange
        default: return .red
        }
    }

    private func getMetrics(for service: ServiceUsage) -> (label: String, value: String, percentage: Double, progressRatio: Double, resetText: String?, color: Color) {
        let weeklyPercent = service.usageRatio * 100
        let fiveHourPercent = metricPercentage(from: service.secondaryMetricValue)
        let currentPercent = selectedWindow == .weekly ? weeklyPercent : fiveHourPercent

        let label = selectedWindow == .weekly ? service.primaryMetricLabel : service.secondaryMetricLabel
        let value = selectedWindow == .weekly ? service.primaryMetricValue ?? "0%" : service.secondaryMetricValue ?? "0%"
        let resetDate = selectedWindow == .weekly ? service.resetDate : service.secondaryResetDate
        let resetText = resetDate.flatMap { shortResetText(from: $0) }

        let ratio = min(max(currentPercent / 100, 0), 1)
        let color: Color = {
            switch ratio {
            case 0..<0.6: return .green
            case 0.6..<0.85: return .orange
            default: return .red
            }
        }()

        return (label, value, currentPercent, ratio, resetText, color)
    }

    var body: some View {
        VStack(spacing: 12) {
            if store.services.isEmpty {
                VStack {
                    VStack(spacing: 10) {
                        if let error = store.loginError {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        } else {
                            ProgressView()
                            Text("Loading usage data...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 28, y: 12)
            } else {
                ForEach(store.services) { service in
                    let isExpanded = expandedServiceId == service.id
                    let metrics = getMetrics(for: service)

                    VStack(alignment: .leading, spacing: isExpanded ? 16 : 0) {
                        HStack {
                            if !isExpanded {
                                claudeLogo
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .padding(4)
                                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            Text(service.serviceName)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Spacer()
                            if isExpanded {
                                Button {
                                    Task { await store.refresh() }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(width: 26, height: 26)
                                }
                                .buttonStyle(.plain)
                                .background(.white.opacity(0.18), in: Circle())
                                .disabled(service.isLoading)
                            } else {
                                Text(metrics.value)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(metrics.color)
                            }
                        }
                        if let error = service.error {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                Text(error)
                                    .font(.system(size: 11))
                                    .lineLimit(2)
                            }
                            .foregroundStyle(.red)
                            .padding(.top, 2)
                        }

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .center, spacing: 14) {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(.white.opacity(0.16))
                                        .frame(width: 84, height: 84)
                                        .overlay {
                                            claudeLogo
                                                .resizable()
                                                .scaledToFit()
                                                .padding(16)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(.white.opacity(0.22), lineWidth: 1)
                                        }

                                    Spacer(minLength: 0)

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(metrics.label)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Text(metrics.value)
                                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                                            .contentTransition(.numericText())
                                            .lineLimit(1)
                                    }
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(.white.opacity(0.14))

                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(metrics.color.gradient)
                                            .frame(width: max(18, geo.size.width * metrics.progressRatio))
                                            .animation(.easeInOut(duration: 0.25), value: metrics.progressRatio)
                                    }
                                }
                                .frame(height: 18)

                                HStack(alignment: .center, spacing: 10) {
                                    if let resetText = metrics.resetText {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Resets")
                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                            Text(resetText)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary.opacity(0.82))
                                        }
                                    }

                                    Spacer()

                                    LimitPill(
                                        title: "5 hours",
                                        isSelected: selectedWindow == .fiveHours
                                    ) {
                                        selectedWindow = .fiveHours
                                    }

                                    LimitPill(
                                        title: "weekly",
                                        isSelected: selectedWindow == .weekly
                                    ) {
                                        selectedWindow = .weekly
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 12)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedServiceId = isExpanded ? nil : service.id
                        }
                    }
                }
            }
        }
        .padding(14)
        .onAppear {
            if expandedServiceId == nil && !store.services.isEmpty {
                expandedServiceId = store.services.first?.id
            }
        }
    }

    private func metricPercentage(from value: String?) -> Double {
        guard let value else { return 0 }
        let sanitized = value.replacingOccurrences(of: "%", with: "")
        return Double(sanitized) ?? 0
    }

    private func shortResetText(from rawValue: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        let date = formatter.date(from: rawValue) ?? fallbackFormatter.date(from: rawValue)
        guard let date else { return rawValue }

        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private var claudeLogo: Image {
        if let named = NSImage(named: NSImage.Name("claude-logo"))
            ?? NSImage(named: NSImage.Name("claude-logo.png")) {
            return Image(nsImage: named)
        }
        if let url = Bundle.main.url(forResource: "claude-logo", withExtension: "png"),
           let fileImage = NSImage(contentsOf: url) {
            return Image(nsImage: fileImage)
        }
        return Image(systemName: "brain.filled.head.profile")
    }
}

struct LimitPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.12),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? .white.opacity(0.28) : .white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
