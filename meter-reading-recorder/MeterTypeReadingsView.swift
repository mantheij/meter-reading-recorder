import SwiftUI
import CoreData

struct MeterTypeReadingsView: View {
    let type: MeterType
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var readings: FetchedResults<MeterReading>
    @State private var showDeleteConfirmation: Bool = false
    @State private var pendingDeletion: MeterReading? = nil
    @State private var showEditSheet: Bool = false
    @State private var editingReading: MeterReading? = nil
    @State private var editedValue: String = ""
    @State private var editingImage: UIImage? = nil
    @State private var showImageFullscreen: Bool = false
    @State private var fullscreenImage: UIImage? = nil
    @State private var fullscreenImageID: UUID = UUID()

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
                    title: "Keine Zählerstände",
                    subtitle: "Erfasse deinen ersten \(type.displayName)-Zählerstand über die Kamera oder manuelle Eingabe."
                )
            } else {
                List {
                    ForEach(readings) { reading in
                        ReadingRow(reading: reading, onImageTap: { img in
                            fullscreenImage = img
                            fullscreenImageID = UUID()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                showImageFullscreen = true
                            }
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingReading = reading
                            editedValue = reading.value ?? ""
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
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .alert("Eintrag löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) {
                pendingDeletion = nil
            }
            Button("Löschen", role: .destructive) {
                if let toDelete = pendingDeletion {
                    viewContext.delete(toDelete)
                    try? viewContext.save()
                    pendingDeletion = nil
                }
            }
        } message: {
            Text("Möchtest du diesen Zählerstand wirklich löschen?")
        }
        .sheet(isPresented: $showEditSheet) {
            MeterReadingFormSheet(
                title: "Zählerstand bearbeiten",
                image: editingImage,
                value: $editedValue,
                confirmTitle: "Speichern",
                onCancel: {
                    showEditSheet = false
                    editingReading = nil
                },
                onConfirm: {
                    if let sanitized = ValueFormatter.sanitizeMeterValue(editedValue), let editing = editingReading {
                        editing.value = sanitized
                        try? viewContext.save()
                        showEditSheet = false
                        editingReading = nil
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showImageFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    if let img = fullscreenImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .padding()
                            .id(fullscreenImageID)
                    } else {
                        Text("Kein Bild zum Anzeigen")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Button(action: { showImageFullscreen = false }) {
                        Label("Schließen", systemImage: "xmark.circle.fill")
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
    }
}
