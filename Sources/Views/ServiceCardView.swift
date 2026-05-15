import SwiftUI

struct ServiceCardView: View {
    let usage: ServiceUsage

    private var percentageText: String {
        String(format: "%.1f%%", usage.usageRatio * 100)
    }

    private var primaryValueText: String {
        usage.primaryMetricValue ?? formatTokens(usage.totalTokens)
    }

    private var secondaryValueText: String {
        usage.secondaryMetricValue ?? (usage.monthlyTokenLimit > 0 ? formatTokens(usage.monthlyTokenLimit) : "—")
    }

    private var usageColor: Color {
        switch usage.usageRatio {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Image(systemName: usage.iconName)
                    .foregroundStyle(.purple)
                Text(usage.serviceName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if usage.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else if let error = usage.error {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(error)
                } else {
                    Text(percentageText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(usageColor)
                }
            }

            if let error = usage.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(usageColor.gradient)
                            .frame(width: geo.size.width * usage.usageRatio, height: 8)
                            .animation(.easeInOut(duration: 0.4), value: usage.usageRatio)
                    }
                }
                .frame(height: 8)

                // Usage counts
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(usage.primaryMetricLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(primaryValueText)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(usage.secondaryMetricLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(secondaryValueText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                if let detailText = usage.detailText {
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }

                if let reset = usage.resetDate {
                    Text("Resets \(reset)")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
            }

            if let updated = Optional(usage.lastUpdated), !usage.isLoading {
                Text("Updated \(updated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fk", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
