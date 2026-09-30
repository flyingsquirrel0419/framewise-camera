import SwiftUI
import CompositionKit

/// The whole app: a full-bleed camera with a quiet composition guide on top.
struct CameraScreen: View {
    let settings: AppSettings
    @State private var model: CameraViewModel
    @State private var showSettings = false
    @State private var showPhoto = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    init(settings: AppSettings) {
        self.settings = settings
        _model = State(initialValue: CameraViewModel(settings: settings))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch model.status {
            case .needsPermission, .denied:
                PermissionView(isDenied: model.status == .denied) { await model.requestPermission() }
                    .transition(.opacity)
            case .unavailable, .failed:
                UnavailableView()
                    .transition(.opacity)
            case .idle, .running:
                cameraLayout
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.status)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await model.start() }
            case .background: model.stop()
            default: break
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: { model.settingsChanged() }) {
            SettingsView(settings: settings)
        }
        .fullScreenCover(isPresented: $showPhoto) {
            PhotoViewer(image: model.lastPhoto)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var quadrantRotation: Angle { .degrees(model.motionState.quadrant.uiRotationDegrees) }

    // MARK: Layout

    private var cameraLayout: some View {
        VStack(spacing: 0) {
            topBar
                .frame(height: 52)
            previewArea
            Spacer(minLength: 10)
            VStack(spacing: 16) {
                ModeSelector(modes: settings.availableModes, selected: model.mode) { model.setMode($0) }
                CameraControls(thumbnail: model.lastThumbnail,
                               isOptimal: model.guide.result?.isOptimal == true && settings.showGuide,
                               isCapturing: model.isCapturing,
                               onShutter: { model.capture() },
                               onFlip: { Task { await model.switchCamera() } },
                               onThumbnail: { showPhoto = true })
            }
            .padding(.bottom, 14)
        }
    }

    private var topBar: some View {
        HStack {
            if model.configuration?.supportsFlash == true {
                iconButton(model.flash.symbol, label: "a11y.flash") { model.cycleFlash() }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
            Spacer()
            if settings.showScore, let score = model.guide.result?.score {
                ScorePill(score: score)
                    .rotationEffect(quadrantRotation)
                    .transition(.opacity)
            }
            Spacer()
            styleMenu
            iconButton("gearshape", label: "a11y.settings") { showSettings = true }
        }
        .padding(.horizontal, 18)
        .animation(.easeInOut(duration: 0.3), value: model.guide.result == nil)
    }

    /// Auto style follows the subject; picking one pins it.
    private var styleMenu: some View {
        Menu {
            Picker(selection: Binding(get: { settings.styleChoice }, set: { model.setStyleChoice($0) })) {
                Label("style.auto", systemImage: "sparkles").tag("auto")
                ForEach(PhotoStyle.allCases, id: \.self) { style in
                    Text(LocalizedStringKey(L10n.styleKey(style))).tag(style.rawValue)
                }
            } label: {
                Text("style.title")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: settings.fixedStyle == nil ? "sparkles" : "camera.filters")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(LocalizedStringKey(L10n.styleKey(model.activeStyle)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Theme.charcoal.opacity(0.8), in: Capsule())
            .rotationEffect(quadrantRotation)
            .animation(.easeInOut(duration: 0.3), value: model.activeStyle)
        }
        .accessibilityLabel(Text("a11y.style"))
        .padding(.trailing, 8)
    }

    private func iconButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 38, height: 38)
                .background(Theme.charcoal.opacity(0.8), in: Circle())
                .rotationEffect(quadrantRotation)
                .animation(.smooth(duration: 0.35), value: quadrantRotation)
        }
        .accessibilityLabel(Text(label))
    }

    private var previewArea: some View {
        ZStack {
            CameraPreview(renderer: model.renderer)
            GuideOverlay(guide: model.guide, imageSize: model.imageSize, settings: settings, motion: model.motionState,
                         selectedID: model.selectedID) { point, id in
                model.tap(at: point, subjectID: id)
            }
            focusMarkerLayer
            tipLayer
            Color.black
                .opacity(model.captureFlash ? 0.9 : 0)
                .allowsHitTesting(false)
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipped()
        .overlay(alignment: .bottom) {
            if let lenses = model.configuration?.lenses, lenses.count > 1 {
                ZoomSelector(lenses: lenses, selected: model.configuration?.selectedLens) { model.select($0) }
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .top) { toastView }
        .overlay(alignment: .topLeading) { selectionChip }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                model.shiftMode(by: dx < 0 ? 1 : -1)
            }
        )
    }

    /// The tip sits at the bottom of the photo: the preview's bottom edge in
    /// portrait, or the matching side edge when the phone is held sideways.
    private var tipLayer: some View {
        GeometryReader { geo in
            let q = model.motionState.quadrant
            let tip = model.guide.tip
            let key = L10n.tipKey(tip, kind: model.guide.result?.subjectKind)
            let reason = model.guide.reason.map(L10n.reasonKey)
            let position: CGPoint = {
                switch q {
                case .portrait: return CGPoint(x: geo.size.width / 2, y: geo.size.height - 84)
                case .gravityRight: return CGPoint(x: geo.size.width - 44, y: geo.size.height / 2)
                case .gravityLeft: return CGPoint(x: 44, y: geo.size.height / 2)
                }
            }()
            ZStack {
                if settings.showTips, model.status == .running {
                    TipView(tipKey: key, reasonKey: reason, isOptimal: model.guide.result?.isOptimal == true)
                }
            }
            .frame(maxWidth: (q == .portrait ? geo.size.width : geo.size.height) - 56)
            .rotationEffect(.degrees(q.uiRotationDegrees))
            .position(position)
            .animation(.easeInOut(duration: 0.3), value: key + (reason ?? ""))
            .animation(.smooth(duration: 0.35), value: q)
        }
        .allowsHitTesting(false)
    }

    private var focusMarkerLayer: some View {
        GeometryReader { geo in
            if let marker = model.focusMarker {
                let mapper = PreviewGeometry(viewSize: geo.size, imageSize: model.imageSize)
                FocusMarkerView()
                    .id(marker.id)
                    .position(mapper.point(marker.point))
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }

    /// Shown while a tapped subject is locked; tap to return to automatic.
    @ViewBuilder
    private var selectionChip: some View {
        if model.selectedID != nil {
            let kind = model.guide.result?.subjectKind ?? .object
            Button { model.clearSelection() } label: {
                HStack(spacing: 6) {
                    Circle().fill(Theme.tint(for: kind)).frame(width: 6, height: 6)
                    Text("chip.selected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(12)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = model.toast {
            Button {
                if toast.opensSettings, let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text(LocalizedStringKey(toast.key))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.55), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
