import PhotosUI
import SwiftUI

/// Settings → Manage photos: the collection of upcoming reward pictures.
/// It lives in Settings so Richard doesn't see what's coming by accident.
struct PhotoLibraryView: View {
    @Environment(PhotoStore.self) private var photos
    @State private var picked: [PhotosPickerItem] = []
    @State private var newIDs: [UUID] = []
    @State private var cropping: CropStep?
    @State private var confirmDelete: PhotoItem?
    @State private var loadFailed = 0

    struct CropStep: Identifiable {
        let ids: [UUID]
        var index = 0
        var id: UUID { ids[index] }
    }

    var body: some View {
        let skipped = photos.photos.filter(\.excluded).count

        List {
            Section {
                PhotosPicker(selection: $picked, maxSelectionCount: nil, matching: .images, photoLibrary: .shared()) {
                    Label("Add photos", systemImage: "photo.badge.plus")
                }
                .buttonStyle(PrimaryButtonStyle(minHeight: 72))
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .disabled(photos.importing > 0)

                if photos.importing > 0 {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing \(LapMath.plural(photos.importing, "photo"))…")
                    }
                    .frame(minHeight: 44)
                }
                if loadFailed > 0 {
                    Text("\(LapMath.plural(loadFailed, "photo")) couldn't be read and were left out.")
                        .foregroundStyle(Theme.secondaryText)
                }
            } footer: {
                Text("Laps keeps its own smaller copy of each photo. Removing one here never touches the original in Photos.")
            }

            Section {
                Picker("Order", selection: Binding(
                    get: { photos.settings.order },
                    set: { o in photos.updateSettings { $0.order = o } })) {
                    ForEach(PhotoOrder.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            } header: {
                Text("Order")
            } footer: {
                Text("No picture repeats until every photo has had its turn.")
            }

            if photos.photos.isEmpty {
                Section {
                    Text("No photos yet. Tap \"Add photos\" to choose some from the photo library.")
                        .foregroundStyle(Theme.secondaryText)
                        .frame(minHeight: 60)
                }
            } else {
                Section {
                    ForEach(photos.photos) { item in
                        NavigationLink {
                            PhotoCropView(photoID: item.id, onFinish: {})
                                .navigationTitle("Crop")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            PhotoRow(item: item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { confirmDelete = item } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                            Button {
                                photos.setExcluded(!item.excluded, for: item.id)
                            } label: {
                                Label(item.excluded ? "Use again" : "Skip for now",
                                      systemImage: item.excluded ? "eye" : "eye.slash")
                            }
                            .tint(Theme.purple)
                        }
                        .contextMenu {
                            Button {
                                photos.setExcluded(!item.excluded, for: item.id)
                            } label: {
                                Label(item.excluded ? "Use again" : "Skip for now",
                                      systemImage: item.excluded ? "eye" : "eye.slash")
                            }
                            Button(role: .destructive) { confirmDelete = item } label: {
                                Label("Remove from Laps", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { photos.move(from: $0, to: $1) }
                } header: {
                    Text("\(LapMath.plural(photos.photos.count, "photo"))" + (skipped > 0 ? ", \(skipped) skipped for now" : ""))
                } footer: {
                    Text("Tap a photo to change its crop. Swipe left to skip it for now or remove it. Tap Edit to change the order.")
                }
            }
        }
        .font(.system(.body, design: .rounded))
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Photos")
        .toolbar { if photos.photos.count > 1 { EditButton() } }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await importPhotos(items) }
        }
        .sheet(item: $cropping) { step in
            NavigationStack {
                PhotoCropView(
                    photoID: step.id,
                    progress: step.ids.count > 1 ? "Photo \(step.index + 1) of \(step.ids.count)" : nil,
                    saveTitle: step.index + 1 < step.ids.count ? "Save and next" : "Done",
                    dismissOnSave: false,
                    onFinish: { advance(step) })
                .id(step.id)
                .navigationTitle("Crop new photos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Keep the rest centered") { cropping = nil }
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        .confirmationDialog("Remove this photo from Laps?", isPresented: Binding(
            get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible, presenting: confirmDelete) { item in
            Button("Remove from Laps", role: .destructive) { photos.delete(item.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("The original stays in Photos, and any finished picture stays in the gallery.")
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var datas: [Data] = []
        var failed = 0
        for item in items {
            if let d = try? await item.loadTransferable(type: Data.self) { datas.append(d) } else { failed += 1 }
        }
        let ids = await photos.add(datas)
        loadFailed = failed + (datas.count - ids.count)
        if !ids.isEmpty { cropping = CropStep(ids: ids) }
    }

    private func advance(_ step: CropStep) {
        if step.index + 1 < step.ids.count {
            var next = step
            next.index += 1
            cropping = next
        } else {
            cropping = nil
        }
    }
}

private struct PhotoRow: View {
    @Environment(PhotoStore.self) private var photos
    let item: PhotoItem

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let img = photos.image(for: item.id, .thumb) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.lightTeal
                }
            }
            .frame(width: 64, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(item.excluded ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("Added \(item.addedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .foregroundStyle(Theme.text)
                if item.excluded {
                    Label("Skipped for now", systemImage: "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .frame(minHeight: 88)
        .accessibilityElement(children: .combine)
    }
}
