import SwiftUI
import CoreData

struct MeterTypeReadingsView: View {
    let type: MeterType
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.appLanguage) private var appLanguage
    @FetchRequest var readings: FetchedResults<MeterReading>
    @State private var showDeleteConfirmation: Bool = false
    @State private var pendingDeletion: MeterReading? = nil
    @State private var showEditSheet: Bool = false
    @State private var editingReading: MeterReading? = nil
    @State private var editedValue: String = ""
    @State private var editedDate = Date()
    @State private var editingImage: UIImage? = nil
    @State private var fullscreenReading: MeterReading? = nil

    init(type: MeterType) {
        self.type = type
        _readings = FetchRequest<MeterReading>(
            sortDescriptors: [NSSortDescriptor(keyPath: \MeterReading.date, ascending: false)],
            predicate: NSPredicate(format: "meterType == %@", type.rawValue),
            animation: .default
        )
    }

    var body: some View {
        ZStack {
            if readings.isEmpty {
                EmptyStateView(
                    icon: type.iconName,
                    title: L10n.noReadings,
                    subtitle: L10n.emptyStateSubtitle(type.displayName)
                )
            } else {
                List {
                    ForEach(readings) { reading in
                        ReadingRow(reading: reading, onImageTap: {
                            fullscreenReading = reading
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingReading = reading
                            editedValue = reading.value ?? ""
                            editedDate = reading.date ?? Date()
                            if let data = reading.imageData, let uiImg = UIImage(data: data) {
                                editingImage = uiImg
                            } else {
                                editingImage = nil
                            }
                            DispatchQueue.main.async {
                                showEditSheet = true
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = reading
                                showDeleteConfirmation = true
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .alert(L10n.deleteEntry, isPresented: $showDeleteConfirmation) {
            Button(L10n.cancel, role: .cancel) {
                pendingDeletion = nil
            }
            Button(L10n.delete, role: .destructive) {
                if let toDelete = pendingDeletion {
                    viewContext.delete(toDelete)
                    try? viewContext.save()
                    pendingDeletion = nil
                }
            }
        } message: {
            Text(L10n.deleteEntryMessage)
        }
        .sheet(isPresented: $showEditSheet) {
            MeterReadingFormSheet(
                title: L10n.editMeterReading,
                image: editingImage,
                value: $editedValue,
                date: $editedDate,
                confirmTitle: L10n.save,
                onCancel: {
                    showEditSheet = false
                    editingReading = nil
                },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(editedValue), let editing = editingReading {
                        editing.value = sanitized
                        editing.date = editedDate
                        try? viewContext.save()
                        showEditSheet = false
                        editingReading = nil
                    }
                }
            )
        }
        .fullScreenCover(item: $fullscreenReading) { reading in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    if let data = reading.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        Text(L10n.noImageToShow)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Button(action: { fullscreenReading = nil }) {
                        Label(L10n.close, systemImage: "xmark.circle.fill")
                            .font(.title2)
                            .padding()
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onChange(of: editingReading) { _, newValue in
            if let data = newValue?.imageData, let uiImg = UIImage(data: data) {
                editingImage = uiImg
            } else {
                editingImage = nil
            }
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(type.displayName)
                    .font(.title2)
                    .bold()
            }
        }
    }
}
