import SwiftUI

struct GlassSectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String?
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, subtitle: String, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(.thinMaterial, in: Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText(for: colorScheme))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
