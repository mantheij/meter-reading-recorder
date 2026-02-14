import SwiftUI

struct ReadingRow: View {
    @ObservedObject var reading: MeterReading
    var onImageTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.value ?? "N/A")
                    .font(.title2)
                    .foregroundColor(AppTheme.textPrimary)
                Text(reading.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(AppTheme.accentSecondary.opacity(0.7))
            }
            Spacer()
            if let imageData = reading.imageData, let image = UIImage(data: imageData) {
                Button {
                    onImageTap?()
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
