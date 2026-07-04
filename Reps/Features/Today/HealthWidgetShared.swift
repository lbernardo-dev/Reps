import SwiftUI

// MARK: - Detail navigation bar used across health widget detail views
struct HealthWidgetDetailNavBar: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    var domain: MetricDomain?

    private var tint: Color { domain?.tint ?? PulseTheme.accent }

    var body: some View {
        DetailNavigationHeaderBar(title: title, tint: tint) {
            dismiss()
        }
    }
}

// MARK: - Insight row used across health detail views
struct HealthInsightRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 2)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)
        }
        .padding(.vertical, 4)
    }
}

struct HealthStatItem: Identifiable, Equatable {
    let id: String
    let value: String
    let label: String

    init(id: String? = nil, value: String, label: String) {
        self.id = id ?? label
        self.value = value
        self.label = label
    }
}

struct HealthStatsHeader: View {
    let items: [HealthStatItem]
    var domain: MetricDomain?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().frame(height: 36)
                }
                statCell(item)
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(HealthStatsHeaderSurface(domain: domain))
    }

    private func statCell(_ item: HealthStatItem) -> some View {
        VStack(spacing: 4) {
            Text(item.value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Text(item.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HealthStatsHeaderSurface: ViewModifier {
    let domain: MetricDomain?

    func body(content: Content) -> some View {
        if let domain {
            GlassMetricCard(domain: domain, contentPadding: 0) {
                content
                    .padding(.vertical, 14)
            }
        } else {
            content
                .padding(.vertical, 14)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        }
    }
}

// MARK: - Mini metric tile for health detail views
struct HealthMiniTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var domain: MetricDomain?

    var body: some View {
        HealthMiniTileSurface(domain: domain) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(localizedKey(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(localizedKey(subtitle))
                    .font(.system(size: 9))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct HealthMiniTileSurface<Content: View>: View {
    let domain: MetricDomain?
    let content: Content

    init(domain: MetricDomain?, @ViewBuilder content: () -> Content) {
        self.domain = domain
        self.content = content()
    }

    var body: some View {
        if let domain {
            GlassMetricCard(domain: domain, minHeight: 100, contentPadding: 12) {
                content
            }
        } else {
            PulseCard(minHeight: 100, contentPadding: 12) {
                content
            }
        }
    }
}
