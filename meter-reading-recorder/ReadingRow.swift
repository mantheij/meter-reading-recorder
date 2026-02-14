import SwiftUI

struct ReadingRow: View {
    @ObservedObject var reading: MeterReading
    var onImageTap: ((UIImage) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(reading.value ?? "N/A")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Text(reading.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor((colorScheme == .dark ? Color.darkMeterAccentSecondary : Color.meterAccent1).opacity(0.7))
            }
            Spacer()
            if let imageData = reading.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .onTapGesture { onImageTap?(image) }
            }
        }
    }
}
