import SwiftUI
import CoreData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appLanguage) private var appLanguage
    @EnvironmentObject private var authService: AuthService

    @State private var showCamera = false
    @State private var isProcessingOCR = false
    @State private var recognizedValue: String? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var showTypeSelector = false
    @State private var showErrorAlert = false
    @State private var showOCRSelection = false
    @State private var ocrCandidates: [OCRResult] = []
    @State private var selectedReadingDate = Date()
    @State private var showManualEntry: Bool = false
    @State private var manualValue: String = ""
    @State private var manualDate = Date()
    @State private var showSidebar: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var showLoginToast = false

    private var isEmailNotVerified: Bool {
        if case .emailNotVerified = authService.state { return true }
        return false
    }

    var body: some View {
        if isEmailNotVerified {
            EmailVerificationView()
                .environmentObject(authService)
        } else {
        ZStack(alignment: .leading) {
            NavigationStack(path: $navigationPath) {
                VStack(spacing: 0) {
                    if authService.isAuthenticated {
                        SyncBanner(
                            syncService: SyncService.shared,
                            networkMonitor: NetworkMonitor.shared
                        )
                    }
                    MeterTypeListView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showSidebar = true
                                    }
                                }) {
                                    Image(systemName: "line.3.horizontal")
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Text(L10n.meterReadings)
                                    .font(.largeTitle).bold()
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: {
                                    manualValue = ""
                                    manualDate = Date()
                                    showManualEntry = true
                                }) {
                                    Image(systemName: "plus")
                                }
                            }
                        }

                    PrimaryButton(title: L10n.captureMeterReading, icon: "camera.fill") {
                        showCamera = true
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .navigationDestination(for: SidebarDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView()
                    case .visualization:
                        VisualizationView()
                    case .account:
                        AccountView()
                    }
                }
            }
            SidebarView(showSidebar: $showSidebar) { destination in
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSidebar = false
                }
                navigationPath.append(destination)
            }
            .allowsHitTesting(showSidebar)

            // OCR selection is shown as a ZStack overlay to avoid chaining three
            // fullScreenCover modifiers (which causes blank white screens on iOS).
            if showOCRSelection, let img = capturedImage {
                OCRNumberSelectionView(
                    image: img,
                    candidates: ocrCandidates,
                    onSelect: { value, date in
                        recognizedValue = value
                        selectedReadingDate = date
                        showOCRSelection = false
                        showTypeSelector = true
                    },
                    onRetake: {
                        showOCRSelection = false
                        capturedImage = nil
                        ocrCandidates = []
                        showCamera = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea())
                .zIndex(10)
            }

            if isProcessingOCR {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .zIndex(11)
                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text(L10n.recognitionInProgress)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .zIndex(12)
            }
        }
        .onChange(of: authService.isAuthenticated) { _, _ in
            navigationPath = NavigationPath()
        }
        .onChange(of: authService.loginSuccessEvent) { _, event in
            if event != nil {
                authService.loginSuccessEvent = nil
                withAnimation { showLoginToast = true }
            }
        }
        .overlay(alignment: .top) {
            if showLoginToast {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L10n.loginSuccessful)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .shadow(radius: 4)
                .padding(.top, AppTheme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showLoginToast = false
                        }
                    }
                }
            }
        }
        .animation(.easeInOut, value: showLoginToast)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                capturedImage = image
                processImage(image)
            }
            .ignoresSafeArea()
        }
        .alert(L10n.recognitionFailed, isPresented: $showErrorAlert, actions: {
            Button(L10n.retakePhoto) {
                recognizedValue = nil
                capturedImage = nil
                showCamera = true
            }
            Button(L10n.cancel, role: .cancel) {}
        }, message: {
            Text(L10n.recognitionFailedMessage)
        })
        .sheet(isPresented: $showManualEntry) {
            MeterReadingFormSheet(
                title: L10n.manualEntry,
                value: $manualValue,
                date: $manualDate,
                confirmTitle: L10n.next,
                onCancel: { showManualEntry = false },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(manualValue) {
                        recognizedValue = sanitized
                        selectedReadingDate = manualDate
                        capturedImage = nil
                        showManualEntry = false
                        showTypeSelector = true
                    }
                }
            )
        }
        .confirmationDialog(L10n.selectMeterType, isPresented: $showTypeSelector, titleVisibility: .visible) {
            ForEach(MeterType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    if let value = recognizedValue {
                        let image = capturedImage ?? UIImage()
                        saveReading(value: value, type: type, image: image, date: selectedReadingDate)
                    }
                    recognizedValue = nil
                    capturedImage = nil
                    showTypeSelector = false
                }
            }
            Button(L10n.cancel, role: .cancel) {
                recognizedValue = nil
                capturedImage = nil
                showTypeSelector = false
            }
        }
        }
    }

    func processImage(_ image: UIImage) {
        isProcessingOCR = true
        DispatchQueue.global(qos: .userInitiated).async {
            OCRService.recognizeAllCandidates(in: image) { candidates in
                DispatchQueue.main.async {
                    isProcessingOCR = false
                    ocrCandidates = candidates
                    selectedReadingDate = Date()
                    if candidates.isEmpty {
                        capturedImage = nil
                        showErrorAlert = true
                    } else {
                        showOCRSelection = true
                    }
                }
            }
        }
    }

    func saveReading(value: String, type: MeterType, image: UIImage, date: Date = Date()) {
        let newReading = MeterReading(context: viewContext)
        let readingId = UUID()
        newReading.id = readingId
        newReading.value = value
        newReading.meterType = type.rawValue
        newReading.date = date
        newReading.createdAt = date
        newReading.modifiedAt = date
        newReading.softDeleted = false
        newReading.userId = authService.currentUserId
        newReading.syncStatusEnum = .pending
        newReading.version = 1
        newReading.deviceId = DeviceIdentifier.current

        if let fileName = ImageStorageService.shared.saveImage(image, id: readingId) {
            newReading.imageFileName = fileName
        }

        try? viewContext.save()
    }
}

