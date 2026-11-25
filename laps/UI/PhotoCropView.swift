import SwiftUI

/// Crop one photo to the 4:5 picture frame: drag to move, pinch to zoom, or use the
/// big buttons (easier with a shaky hand). The rest of the photo shows faintly outside the frame.
struct PhotoCropView: View {
    @Environment(PhotoStore.self) private var photos
    @Environment(\.dismiss) private var dismiss
    let photoID: UUID
    /// e.g. "Photo 2 of 5" when stepping through a new import.
    var progress: String?
    var saveTitle = "Save"
    /// Close the screen after saving (off when stepping through several photos).
    var dismissOnSave = true
    var onFinish: () -> Void = {}

    @State private var source: UIImage?
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var gestureScale: CGFloat = 1
    @State private var gestureOffset: CGSize = .zero
    @State private var saving = false
    @State private var frameSize: CGSize = .zero
    @State private var loadedFor: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        VStack(spacing: 16) {
            if let progress {
                Text(progress)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text("Drag to move. Pinch, or use the buttons, to zoom.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                let frame = frameRect(in: geo.size)
                ZStack {
                    if let source {
                        let size = displaySize(source, frame: frame.size)
                        let o = clampedOffset(source, frame: frame.size, live: true)
                        // The whole photo, faint, so he can see what's left out.
                        Image(uiImage: source)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .position(x: frame.midX + o.width, y: frame.midY + o.height)
                            .opacity(0.3)
                        // The part inside the frame, at full strength.
                        Image(uiImage: source)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .position(x: frame.midX + o.width, y: frame.midY + o.height)
                            .mask(Rectangle().frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY))
                        Rectangle()
                            .strokeBorder(.white, lineWidth: 2)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                            .shadow(radius: 2)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(dragAndPinch(frame: frame.size))
                .onAppear { frameSize = frame.size; setUpIfReady() }
                .onChange(of: geo.size) { _, _ in frameSize = frameRect(in: geo.size).size }
            }
            .accessibilityElement()
            .accessibilityLabel("Photo crop")
            .accessibilityHint("Use the zoom and center buttons below to adjust")

            HStack(spacing: 12) {
                Button { zoom(by: 1 / 1.25) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    .disabled(scale <= 1.001)
                Button { zoom(by: 1.25) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                    .disabled(scale >= maxScale)
            }
            .buttonStyle(SecondaryButtonStyle(minHeight: 60))

            Button {
                withAnimation(.easeOut(duration: 0.25)) { scale = 1; offset = .zero }
            } label: {
                Label("Fill and center", systemImage: "arrow.down.forward.and.arrow.up.backward")
            }
            .buttonStyle(SecondaryButtonStyle(minHeight: 56))

            Button {
                Task { await save() }
            } label: {
                if saving { ProgressView().tint(.white) } else { Text(saveTitle) }
            }
            .buttonStyle(PrimaryButtonStyle(minHeight: 72))
            .disabled(saving || source == nil)
        }
        .font(.system(.title3, design: .rounded).weight(.semibold))
        .padding(20)
        .background(Theme.background.ignoresSafeArea())
        .task(id: photoID) { await load() }
    }

    // MARK: - Geometry

    /// The largest 4:5 frame that fits, leaving a margin so the faint edges show.
    private func frameRect(in size: CGSize) -> CGRect {
        let maxW = size.width * 0.86, maxH = size.height * 0.94
        let w = min(maxW, maxH * CropRect.aspect), h = w / CropRect.aspect
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Points per source pixel when the photo just fills the frame.
    private func baseScale(_ image: UIImage, frame: CGSize) -> CGFloat {
        max(frame.width / image.size.width, frame.height / image.size.height)
    }

    private func liveScale() -> CGFloat { min(maxScale, max(1, scale * gestureScale)) }

    private func displaySize(_ image: UIImage, frame: CGSize) -> CGSize {
        let k = baseScale(image, frame: frame) * liveScale()
        return CGSize(width: image.size.width * k, height: image.size.height * k)
    }

    /// Keeps the photo covering the whole frame.
    private func clampedOffset(_ image: UIImage, frame: CGSize, live: Bool) -> CGSize {
        let size = displaySize(image, frame: frame)
        let raw = live ? CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height) : offset
        let mx = max(0, (size.width - frame.width) / 2), my = max(0, (size.height - frame.height) / 2)
        return CGSize(width: min(mx, max(-mx, raw.width)), height: min(my, max(-my, raw.height)))
    }

    private func dragAndPinch(frame: CGSize) -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { gestureOffset = $0.translation }
                .onEnded { _ in commitGesture(frame: frame) },
            MagnifyGesture()
                .onChanged { gestureScale = $0.magnification }
                .onEnded { _ in commitGesture(frame: frame) })
    }

    private func commitGesture(frame: CGSize) {
        guard let source else { return }
        let o = clampedOffset(source, frame: frame, live: true)
        scale = liveScale()
        offset = o
        gestureScale = 1
        gestureOffset = .zero
        offset = clampedOffset(source, frame: frame, live: false)
    }

    private func zoom(by factor: CGFloat) {
        guard let source else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            let old = scale
            scale = min(maxScale, max(1, scale * factor))
            // Zoom around the frame's center.
            let r = scale / old
            offset = CGSize(width: offset.width * r, height: offset.height * r)
            offset = clampedOffset(source, frame: frameSize, live: false)
        }
    }

    // MARK: - Loading and saving

    private func load() async {
        let url = photos.url(for: photoID, .source)
        let img = await Task.detached { UIImage(contentsOfFile: url.path) }.value
        source = img
        loadedFor = .zero
        setUpIfReady()
    }

    /// Starts from the photo's saved crop.
    private func setUpIfReady() {
        guard let source, let item = photos.photo(photoID), frameSize.width > 0, loadedFor != frameSize else { return }
        loadedFor = frameSize
        let iw = source.size.width, ih = source.size.height
        let k = frameSize.width / (item.crop.width * iw)
        scale = min(maxScale, max(1, k / baseScale(source, frame: frameSize)))
        let cx = item.crop.x + item.crop.width / 2, cy = item.crop.y + item.crop.height / 2
        offset = CGSize(width: (0.5 - cx) * iw * k, height: (0.5 - cy) * ih * k)
        offset = clampedOffset(source, frame: frameSize, live: false)
    }

    /// The frame's area as fractions of the photo.
    private func currentCrop() -> CropRect? {
        guard let source, frameSize.width > 0 else { return nil }
        let iw = source.size.width, ih = source.size.height
        let k = baseScale(source, frame: frameSize) * scale
        let w = frameSize.width / (k * iw), h = frameSize.height / (k * ih)
        let cx = 0.5 - offset.width / (iw * k), cy = 0.5 - offset.height / (ih * k)
        return CropRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h).clamped()
    }

    private func save() async {
        guard let crop = currentCrop() else { return }
        saving = true
        await photos.setCrop(crop, for: photoID)
        saving = false
        onFinish()
        if dismissOnSave { dismiss() }
    }
}
