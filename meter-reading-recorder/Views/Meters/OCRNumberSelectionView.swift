import SwiftUI

struct OCRNumberSelectionView: View {
    let image: UIImage
    let candidates: [OCRResult]
    let onSelect: (String, Date) -> Void
    let onRetake: () -> Void

    @State private var selectedCandidate: OCRResult?
    @State private var editedValue: String = ""
    @State private var showManualSheet = false
    @State private var manualValue = ""
    @State private var manualDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            navBar

            Divider()

            imageSection

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(L10n.detectedNumbers)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.top, AppTheme.Spacing.sm)

                candidatesGrid

                confirmSection
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showManualSheet) {
            MeterReadingFormSheet(
                title: L10n.manualEntry,
                value: $manualValue,
                date: $manualDate,
                confirmTitle: L10n.next,
                onCancel: { showManualSheet = false },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(manualValue) {
                        showManualSheet = false
                        onSelect(sanitized, manualDate)
                    }
                }
            )
        }
        .onAppear {
            if let best = candidates.first(where: { $0.isBestCandidate }) {
                select(best)
            } else if let first = candidates.first {
                select(first)
            }
        }
    }

    // MARK: - Navigation bar

    private var navBar: some View {
        HStack {
            Button(L10n.retakePhoto, action: onRetake)
                .font(.subheadline)
                .foregroundColor(AppTheme.accentPrimary)

            Spacer()

            Text(L10n.selectMeterReadingTitle)
                .font(.headline)

            Spacer()

            Button(L10n.manualEntry) {
                manualValue = ""
                manualDate = Date()
                showManualSheet = true
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.accentPrimary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(Color(.systemBackground))
    }

    // MARK: - Image with tappable overlays

    private var imageSection: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(candidates) { candidate in
                    overlayView(for: candidate, in: geo.size)
                }
            }
        }
        .frame(height: imageHeight)
        .clipped()
    }

    private func overlayView(for candidate: OCRResult, in containerSize: CGSize) -> some View {
        let rect = displayRect(for: candidate.boundingBox, containerSize: containerSize)
        let isSelected = selectedCandidate?.id == candidate.id

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isSelected ? Color.yellow :
                        candidate.isBestCandidate ? Color.green.opacity(0.9) : Color.white.opacity(0.6),
                    lineWidth: isSelected ? 3 : 2
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.yellow.opacity(0.15) : Color.clear)
                )

            if isSelected {
                Text(candidate.text)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(3)
                    .offset(y: -18)
            }
        }
        .frame(width: max(rect.width, 30), height: max(rect.height, 20))
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onTapGesture { select(candidate) }
    }

    // MARK: - Candidates grid

    private var candidatesGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.Spacing.sm
            ) {
                ForEach(candidates) { candidate in
                    candidateChip(candidate)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xs)
        }
        .frame(maxHeight: 150)
    }

    private func candidateChip(_ candidate: OCRResult) -> some View {
        let isSelected = selectedCandidate?.id == candidate.id
        return Button { select(candidate) } label: {
            VStack(spacing: 2) {
                Text(candidate.text)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if candidate.isBestCandidate {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.8) : AppTheme.accentPrimary)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .fill(isSelected ? AppTheme.accentPrimary : AppTheme.accentPrimary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                    .strokeBorder(
                        isSelected ? AppTheme.accentPrimary : AppTheme.accentPrimary.opacity(0.25),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Confirm section

    private var confirmSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Divider()

            HStack(spacing: AppTheme.Spacing.sm) {
                TextField(L10n.meterReadingPlaceholder, text: $editedValue)
                    .keyboardType(.decimalPad)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    .frame(maxWidth: 200)

                let isValid = ValueFormatter.sanitizeMeterValue(editedValue) != nil
                Button {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(editedValue) {
                        onSelect(sanitized, Date())
                    }
                } label: {
                    Label(L10n.useThisReading, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.accentPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.4)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.md)
        }
    }

    // MARK: - Helpers

    private var imageHeight: CGFloat {
        UIScreen.main.bounds.height * 0.32
    }

    private func select(_ candidate: OCRResult) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedCandidate = candidate
        }
        editedValue = OCRService.extractNumericValue(from: candidate.text)
    }

    private func displayRect(for visionBox: CGRect, containerSize: CGSize) -> CGRect {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return .zero }

        let imageAspect = imgSize.width / imgSize.height
        let containerAspect = containerSize.width / containerSize.height

        let renderedSize: CGSize
        let renderedOrigin: CGPoint

        if imageAspect > containerAspect {
            let h = containerSize.width / imageAspect
            renderedSize = CGSize(width: containerSize.width, height: h)
            renderedOrigin = CGPoint(x: 0, y: (containerSize.height - h) / 2)
        } else {
            let w = containerSize.height * imageAspect
            renderedSize = CGSize(width: w, height: containerSize.height)
            renderedOrigin = CGPoint(x: (containerSize.width - w) / 2, y: 0)
        }

        let flippedY = 1 - visionBox.origin.y - visionBox.height

        return CGRect(
            x: renderedOrigin.x + visionBox.origin.x * renderedSize.width,
            y: renderedOrigin.y + flippedY * renderedSize.height,
            width: visionBox.width * renderedSize.width,
            height: visionBox.height * renderedSize.height
        )
    }
}
