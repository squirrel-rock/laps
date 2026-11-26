import SwiftUI

/// The Picture tab: today's photo, uncovered a piece at a time.
struct PictureView: View {
    @Environment(WalkStore.self) private var store
    @Environment(PhotoStore.self) private var photos
    @State private var fullScreen = false

    var body: some View {
        let s = photos.settings
        let walking = store.walkingCreditsToday, standing = store.standingCreditsToday

        ScrollView {
            VStack(spacing: 20) {
                if !s.isOn {
                    message("The daily picture is turned off.",
                            detail: "You can turn it on in Reminders, under Picture reward.")
                } else if let p = photos.picture(for: store.todayKey) {
                    let shown = PictureMath.revealed(walking: walking, standing: standing, tiles: s.tiles, mode: s.mode)
                    let complete = shown >= s.tiles

                    VStack(spacing: 14) {
                        TilePicture(image: photos.dayImage(p), tiles: s.tiles, revealed: shown,
                                    order: PictureMath.order(tiles: s.tiles, seed: "\(p.day)-\(p.photoID)"))
                            .onTapGesture { if complete { fullScreen = true } }
                            .accessibilityAddTraits(complete ? .isButton : [])
                            .accessibilityHint(complete ? "Shows the picture full screen" : "")

                        Text(PictureMath.status(walking: walking, standing: standing, tiles: s.tiles, mode: s.mode))
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(complete ? Theme.warm : Theme.text)
                            .multilineTextAlignment(.center)

                        if complete {
                            Label("Tap the picture to see it full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        } else if let done = p.completedTiles {
                            Label("You finished it at \(done) tiles today. It's saved in your gallery.",
                                  systemImage: "checkmark.seal.fill")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.darkTeal)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .card()

                    ChallengeCard(walking: walking, standing: standing)
                    GallerySection()
                } else {
                    message("No photos yet.",
                            detail: "Add some in Reminders → Picture reward → Manage photos, and a new one will appear here each day.")
                    if !photos.gallery.isEmpty { GallerySection() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Today's picture")
        .onAppear { photos.sync(day: store.todayKey, walking: walking, standing: standing) }
        .fullScreenCover(isPresented: $fullScreen) {
            if let p = photos.picture(for: store.todayKey), let img = photos.dayImage(p) {
                FullScreenPicture(image: img)
            }
        }
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(Theme.teal)
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            Text(detail)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .card()
    }
}

/// Change today's challenge or mode right from the picture. Never touches his activity records.
private struct ChallengeCard: View {
    @Environment(PhotoStore.self) private var photos
    let walking: Int
    let standing: Int

    var body: some View {
        let s = photos.settings
        let other: RewardMode = s.mode == .determined ? .flexible : .determined
        let now = PictureMath.revealed(walking: walking, standing: standing, tiles: s.tiles, mode: s.mode)
        let ifSwitched = PictureMath.revealed(walking: walking, standing: standing, tiles: s.tiles, mode: other)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Picture challenge")
                    .font(.system(.headline, design: .rounded))
                Picker("Picture challenge", selection: Binding(
                    get: { s.tiles }, set: { t in withAnimation { photos.updateSettings { $0.tiles = t } } })) {
                    ForEach(PictureSettings.tileChoices, id: \.self) { Text("\($0) tiles").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Reward mode")
                    .font(.system(.headline, design: .rounded))
                Picker("Reward mode", selection: Binding(
                    get: { s.mode }, set: { m in withAnimation { photos.updateSettings { $0.mode = m } } })) {
                    ForEach(RewardMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if ifSwitched != now {
                    // So nothing vanishes by surprise.
                    Text("\(other.title) would show \(ifSwitched) of \(s.tiles) right now.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .foregroundStyle(Theme.text)
        .card()
    }
}

/// The photo with its hidden tiles. Uncovered tiles fade away in a scattered order;
/// once every tile is uncovered the grid lines go too, leaving the whole picture.
struct TilePicture: View {
    let image: UIImage?
    let tiles: Int
    let revealed: Int
    let order: [Int]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let grid = PictureSettings.grid(tiles: tiles)
        let complete = revealed >= tiles
        // Position of each cell in the reveal order.
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        Color.clear
            .aspectRatio(CropRect.aspect, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Theme.lightTeal
                }
            }
            .overlay {
                GeometryReader { geo in
                    let cw = geo.size.width / CGFloat(grid.columns), ch = geo.size.height / CGFloat(grid.rows)
                    ForEach(0..<tiles, id: \.self) { cell in
                        let hidden = (rank[cell] ?? 0) >= revealed
                        Rectangle()
                            .fill(Theme.tileCover)
                            .frame(width: cw, height: ch)
                            .scaleEffect(hidden || reduceMotion ? 1 : 0.4)
                            .opacity(hidden ? 1 : 0)
                            .position(x: (CGFloat(cell % grid.columns) + 0.5) * cw,
                                      y: (CGFloat(cell / grid.columns) + 0.5) * ch)
                    }
                    // Grid lines, until the picture is whole.
                    Path { p in
                        for c in 1..<grid.columns {
                            p.move(to: CGPoint(x: CGFloat(c) * cw, y: 0)); p.addLine(to: CGPoint(x: CGFloat(c) * cw, y: geo.size.height))
                        }
                        for r in 1..<grid.rows {
                            p.move(to: CGPoint(x: 0, y: CGFloat(r) * ch)); p.addLine(to: CGPoint(x: geo.size.width, y: CGFloat(r) * ch))
                        }
                    }
                    .stroke(Theme.card, lineWidth: 2)
                    .opacity(complete ? 0 : 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(reduceMotion ? .easeInOut(duration: 0.4) : .easeOut(duration: 0.8), value: revealed)
            .animation(.easeInOut(duration: 1.2), value: complete)
            .accessibilityElement()
            .accessibilityLabel(complete ? "Today's picture, complete" : "Today's picture")
            .accessibilityValue("\(min(revealed, tiles)) of \(tiles) pieces uncovered")
    }
}

/// A finished picture on black, with pinch to zoom.
struct FullScreenPicture: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(min(4, max(1, scale * pinch)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(MagnifyGesture()
                    .updating($pinch) { v, state, _ in state = v.magnification }
                    .onEnded { v in withAnimation { scale = min(4, max(1, scale * v.magnification)) } })
                .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2 } }
                .accessibilityLabel("Today's picture")
            Button { dismiss() } label: {
                Label("Close", systemImage: "xmark")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .padding(.horizontal, 22)
                    .frame(minHeight: 56)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(20)
        }
    }
}

// MARK: - Gallery

/// His finished pictures, newest first, grouped by month.
private struct GallerySection: View {
    @Environment(PhotoStore.self) private var photos
    @Environment(WalkStore.self) private var store

    var body: some View {
        let done = photos.gallery
        VStack(alignment: .leading, spacing: 14) {
            Text("Your gallery")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.text)
            if done.isEmpty {
                Text("Each picture you finish is kept here, with the date and what you did that day.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(months(done), id: \.title) { month in
                    Text(month.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                        ForEach(month.pictures, id: \.day) { p in
                            NavigationLink {
                                GalleryDetailView(picture: p)
                            } label: {
                                VStack(spacing: 6) {
                                    Group {
                                        if let img = photos.dayImage(p, .thumb) {
                                            Image(uiImage: img).resizable().aspectRatio(CropRect.aspect, contentMode: .fit)
                                        } else {
                                            Theme.tileCover.aspectRatio(CropRect.aspect, contentMode: .fit)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    Text(shortDate(p.day))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                            .accessibilityLabel("Picture from \(longDate(p.day))")
                            .accessibilityHint("Shows it larger, with what you did that day")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private struct Month { let title: String; let pictures: [DailyPicture] }

    private func months(_ list: [DailyPicture]) -> [Month] {
        var out: [Month] = []
        for p in list {
            let title = store.date(forKey: p.day)?.formatted(.dateTime.month(.wide).year()) ?? ""
            if out.last?.title == title {
                out[out.count - 1] = Month(title: title, pictures: out[out.count - 1].pictures + [p])
            } else {
                out.append(Month(title: title, pictures: [p]))
            }
        }
        return out
    }

    private func shortDate(_ key: String) -> String {
        if key == store.todayKey { return "Today" }
        return store.date(forKey: key)?.formatted(.dateTime.month(.abbreviated).day()) ?? key
    }

    private func longDate(_ key: String) -> String {
        store.date(forKey: key)?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? key
    }
}

/// One finished picture: larger, with the date, the challenge he reached, and his day.
struct GalleryDetailView: View {
    @Environment(PhotoStore.self) private var photos
    @Environment(WalkStore.self) private var store
    let picture: DailyPicture
    @State private var fullScreen = false

    var body: some View {
        let record = store.record(for: picture.day)
        let image = photos.dayImage(picture)

        ScrollView {
            VStack(spacing: 18) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(CropRect.aspect, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture { fullScreen = true }
                        .accessibilityLabel("The finished picture")
                        .accessibilityHint("Shows it full screen")
                        .accessibilityAddTraits(.isButton)
                }

                VStack(spacing: 0) {
                    if let tiles = picture.completedTiles {
                        SummaryRow(title: "Challenge",
                                   value: "\(tiles) tiles" + (picture.completedMode.map { ", \($0.title)" } ?? ""))
                        Divider()
                    }
                    SummaryRow(title: "Walking", value: "\(record.walkingCredits)")
                    Divider()
                    SummaryRow(title: "That's", value: LapMath.walkingDescription(laps: record.lapCount, carWalks: record.carWalks))
                    Divider()
                    SummaryRow(title: "Activities", value: "\(record.standingCredits)")
                }
                .card()

                if let image {
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("Picture from \(title)", image: Image(uiImage: image))) {
                        Label("Save or share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle(minHeight: 64))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $fullScreen) {
            if let image { FullScreenPicture(image: image) }
        }
    }

    private var title: String {
        store.date(forKey: picture.day)?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) ?? picture.day
    }
}
