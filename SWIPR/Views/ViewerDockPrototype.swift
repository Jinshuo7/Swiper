#if DEBUG
import SwiftUI
import UIKit

/// Throwaway: does a handle-free, magnetic dock distinguish taps from moves?
/// Launch with -viewerDockPrototype. No PhotoKit, saved state, or deletion.
struct ViewerDockPrototype: View {
    enum Stop: String, CaseIterable { case left, bottom, right }
    private enum DockAppearance {
        case porcelain, quietRail, split, labeledGlass
        case neutralIcons, neutralKeepLabel, neutralLabels
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var stop: Stop = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-viewerDockStartLeft") { return .left }
        if arguments.contains("-viewerDockStartRight") { return .right }
        return .bottom
    }()
    @State private var target: Stop? = ProcessInfo.processInfo.arguments.contains("-viewerDockPrototypeDragPreview") ? .bottom : nil
    @State private var finger: CGPoint?
    @GestureState private var touching = false
    @State private var dragging = ProcessInfo.processInfo.arguments.contains("-viewerDockPrototypeDragPreview")
    @State private var showSettings = false
    @State private var showReview = false
    @State private var history: [Bool] = []
    @State private var message = "Drag the tray to move it. Tap to decide."
    @State private var capture = 85.0
    @State private var attraction = 12.0
    @State private var haptics = true
    @State private var diagnosticImage = false
    private let tokenSize: CGFloat = 68
    private let edgeInset: CGFloat = 12
    private var dockLength: CGFloat {
        switch dockAppearance {
        case .labeledGlass, .neutralLabels: 296
        case .neutralKeepLabel: 232
        case .neutralIcons: 168
        default: 207
        }
    }
    private var dockThickness: CGFloat {
        switch dockAppearance {
        case .labeledGlass, .neutralKeepLabel, .neutralLabels: 124
        default: 70
        }
    }
    private let actionWidth: CGFloat = 68
    private let actionHeight: CGFloat = 54
    private var primaryPairOffset: CGFloat {
        switch dockAppearance {
        case .labeledGlass, .neutralIcons, .neutralKeepLabel, .neutralLabels: 29
        default: 25.5
        }
    }

    private func dockSize(vertical: Bool) -> CGSize {
        switch (dockAppearance, vertical) {
        case (.neutralLabels, true):
            return CGSize(width: 52, height: separatedEdgeControls ? 178 : 158)
        case (.neutralLabels, false):
            return CGSize(width: 296, height: 52)
        default:
            return CGSize(width: vertical ? dockThickness : dockLength,
                          height: vertical ? dockLength : dockThickness)
        }
    }

    private var landing: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.32, bounce: 0.16)
    }
    private var dockMorph: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.22, bounce: 0.08)
    }
    private var marked: Int { history.filter { $0 }.count }
    private var dockAppearance: DockAppearance {
        if ProcessInfo.processInfo.arguments.contains("-viewerDockNeutralIcons") { return .neutralIcons }
        if ProcessInfo.processInfo.arguments.contains("-viewerDockNeutralKeepLabel") { return .neutralKeepLabel }
        if ProcessInfo.processInfo.arguments.contains("-viewerDockNeutralLabels") { return .neutralLabels }
        if ProcessInfo.processInfo.arguments.contains("-viewerDockLabeledGlass") { return .labeledGlass }
        if ProcessInfo.processInfo.arguments.contains("-viewerDockQuietRail") { return .quietRail }
        if ProcessInfo.processInfo.arguments.contains("-viewerDockSplit") { return .split }
        return .porcelain
    }
    private var separatedEdgeControls: Bool {
        ProcessInfo.processInfo.arguments.contains("-viewerDockSeparatedEdges")
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safe = proxy.safeAreaInsets
            ZStack {
                Color.black
                PrototypeSwipeSurface(diagnosticImage: diagnosticImage,
                                      dockDragging: dragging,
                                      reduceMotion: reduceMotion,
                                      onDecision: decide)
                navigation(safe: safe)
                if dragging {
                    if let target {
                        magneticLink(from: dockPoint(size: size, safe: safe),
                                     to: landingCentre(target, size: size, safe: safe))
                    }
                    ForEach(Stop.allCases, id: \.self) { candidate in
                        landingPad(candidate, active: target == candidate)
                            .position(landingCentre(candidate, size: size, safe: safe))
                    }
                }
                dock
                    .position(dockPoint(size: size, safe: safe))
                    .gesture(dockGesture(size: size, safe: safe))
            }
            .coordinateSpace(name: "prototypeCanvas")
            .onChange(of: touching) { _, active in
                if !active && dragging {
                    // Covers system gesture cancellation as well as a normal end.
                    withAnimation(landing) { resetDrag() }
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { resetDrag() }
        }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(isPresented: $showReview) {
            NavigationStack {
                List {
                    Text("Sample-only prototype. Nothing can be deleted.")
                    Text("\(history.count) decisions · \(marked) marked")
                    Button("Restore all sample marks") { history = history.map { _ in false } }
                }.navigationTitle("Sample review")
                    .toolbar { Button("Done") { showReview = false } }
            }.presentationDetents([.medium])
        }
    }

    private func navigation(safe: EdgeInsets) -> some View {
        VStack {
            HStack(alignment: .top) {
                Button { showSettings = true } label: {
                    Image(systemName: "house").frame(width: 44, height: 44)
                }.modifier(PrototypeGlass(opaque: reduceTransparency))
                    .accessibilityLabel("Prototype settings")
                    .accessibilityIdentifier("prototype.home")
                Spacer()
                Button { showReview = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if marked > 0 {
                                Text("\(marked)")
                                    .font(.caption2.bold()).foregroundStyle(.white)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(.red, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                }.modifier(PrototypeGlass(opaque: reduceTransparency))
                    .accessibilityLabel("Review \(marked) marked sample items")
                    .accessibilityIdentifier("prototype.review")
            }.foregroundStyle(.primary)
                .padding(.horizontal, 16).padding(.top, max(54, safe.top) + 8)
            Spacer()
        }
    }

    private var dock: some View {
        let vertical = stop != .bottom
        let expandedSize = dockSize(vertical: vertical)
        return ZStack {
            if dragging {
                ZStack {
                    Circle().fill(.black.opacity(0.78))
                    Circle().stroke(.white.opacity(0.45), lineWidth: 1.5)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: tokenSize, height: tokenSize)
                .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
                .transition(.scale(scale: 0.78).combined(with: .opacity))
            } else {
                expandedDock(vertical: vertical)
                .frame(width: expandedSize.width, height: expandedSize.height)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .frame(width: dragging ? tokenSize : expandedSize.width,
               height: dragging ? tokenSize : expandedSize.height)
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Decision controls")
        .accessibilityIdentifier("prototype.dock")
        .accessibilityValue("\(stop.rawValue), \(marked) sample items marked")
        .accessibilityActions {
            Button("Keep") { decide(false) }
            Button("Mark") { decide(true) }
            Button("Undo") { undo() }
            ForEach(Stop.allCases, id: \.self) { p in
                Button("Move \(p.rawValue)") { withAnimation(landing) { stop = p } }
            }
        }
    }

    @ViewBuilder private func expandedDock(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        let separatedLayout = vertical ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))
        switch dockAppearance {
        case .porcelain:
            layout {
                undoControl
                dockDivider(vertical: !vertical)
                trashControl
                keepControl
            }
            .padding(7)
            .modifier(PrototypeGlass(opaque: reduceTransparency))
        case .quietRail:
            layout {
                quietUndoControl
                dockDivider(vertical: !vertical)
                quietAction("trash.fill", tint: .red)
                quietAction("checkmark", tint: .green)
            }
            .padding(7)
            .background(.black.opacity(0.66), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.42), radius: 12, y: 6)
        case .split:
            layout {
                quietUndoControl
                    .background(.black.opacity(0.66), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                layout {
                    quietAction("trash.fill", tint: .red)
                    quietAction("checkmark", tint: .green)
                }
                .padding(4)
                .background(.black.opacity(0.66), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .shadow(color: .black.opacity(0.42), radius: 12, y: 6)
        case .labeledGlass:
            layout {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 52, height: 52)
                    .modifier(PrototypeTintedGlass(tint: .white, circle: true))
                labeledGlassAction("trash.fill", label: "Delete", tint: .red)
                labeledGlassAction("checkmark", label: "Keep", tint: .green)
            }
        case .neutralIcons:
            layout {
                clearGlassCircle("arrow.uturn.backward")
                clearGlassCircle("trash")
                clearGlassCircle("arrow.right")
            }
        case .neutralKeepLabel:
            layout {
                clearGlassCircle("arrow.uturn.backward")
                clearGlassCircle("trash")
                clearGlassLabel("arrow.right", label: "Keep")
            }
        case .neutralLabels:
            if vertical {
                separatedLayout {
                    compactGlassUndo
                    if separatedEdgeControls {
                        separatedEdgePrimaryControls
                    } else {
                        edgePrimaryControls
                    }
                }
            } else {
                separatedLayout {
                    compactGlassUndo
                    layout {
                        clearGlassLabel("trash", label: "Delete")
                        clearGlassLabel("arrow.right", label: "Keep")
                    }
                }
            }
        }
    }

    private var undoControl: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 38, height: 38)
    }

    private var quietUndoControl: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .frame(width: 38, height: 38)
    }

    private var trashControl: some View {
        Image(systemName: "trash.fill").font(.system(size: 25, weight: .semibold))
            .frame(width: actionWidth, height: actionHeight).foregroundStyle(.red)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.red.opacity(0.2), lineWidth: 1))
    }

    private var keepControl: some View {
        Image(systemName: "checkmark").font(.system(size: 27, weight: .semibold))
            .frame(width: actionWidth, height: actionHeight).foregroundStyle(.green)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.green.opacity(0.2), lineWidth: 1))
    }

    private func quietAction(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: symbol == "checkmark" ? 25 : 23, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 54, height: 48)
    }

    private func labeledGlassAction(_ symbol: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .frame(width: 116, height: 52)
        .modifier(PrototypeTintedGlass(tint: tint, circle: false))
    }

    private func clearGlassCircle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.82))
            .frame(width: 52, height: 52)
            .modifier(PrototypeNeutralGlass(circle: true))
    }

    private var compactGlassUndo: some View {
        Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.76))
            .frame(width: 36, height: 36)
            .modifier(PrototypeNeutralGlass(circle: true))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private var edgePrimaryControls: some View {
        VStack(spacing: 0) {
            Image(systemName: "trash")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 52, height: 49)
            Rectangle()
                .fill(.primary.opacity(0.14))
                .frame(width: 26, height: 1)
            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 52, height: 49)
        }
        .foregroundStyle(.primary.opacity(0.82))
        .frame(width: 52, height: 100)
        .modifier(PrototypeNeutralGlass(circle: false))
    }

    private var separatedEdgePrimaryControls: some View {
        VStack(spacing: 16) {
            clearGlassCircle("trash")
            clearGlassCircle("arrow.right")
        }
    }

    private func clearGlassLabel(_ symbol: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary.opacity(0.82))
        .frame(width: 116, height: 52)
        .modifier(PrototypeNeutralGlass(circle: false))
    }

    private func dockDivider(vertical: Bool) -> some View {
        Rectangle().fill(.white.opacity(0.16))
            .frame(width: vertical ? 1 : 30, height: vertical ? 30 : 1)
    }

    private func landingPad(_ candidate: Stop, active: Bool) -> some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .stroke(active ? Color.cyan.opacity(0.5 - Double(ring) * 0.12) : .white.opacity(0.09),
                            lineWidth: active ? 2 : 1)
                    .frame(width: CGFloat(64 + ring * 16), height: CGFloat(64 + ring * 16))
            }
            Circle().fill(active ? Color.cyan.opacity(0.24) : Color.black.opacity(0.42))
                .frame(width: 58, height: 58)
            Circle().stroke(active ? Color.cyan : Color.white.opacity(0.3), lineWidth: active ? 3 : 1.5)
                .frame(width: 58, height: 58)
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(active ? Color.cyan : .white.opacity(0.46))
        }
            .frame(width: 96, height: 96)
            .shadow(color: active ? Color.cyan.opacity(0.55) : .clear,
                    radius: active ? 24 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: active)
            .allowsHitTesting(false)
    }

    private func magneticLink(from: CGPoint, to: CGPoint) -> some View {
        Path { path in path.move(to: from); path.addLine(to: to) }
            .stroke(Color.cyan.opacity(0.72),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
            .shadow(color: .cyan.opacity(0.7), radius: 8)
            .allowsHitTesting(false)
    }

    private func centre(_ p: Stop, size: CGSize, safe: EdgeInsets) -> CGPoint {
        switch p {
        case .bottom:
            return CGPoint(x: size.width / 2 - primaryPairOffset,
                           y: size.height - max(34, safe.bottom) - 42)
        case .left:
            return CGPoint(x: safe.leading + dockSize(vertical: true).width / 2 + edgeInset,
                           y: min(size.height * 0.72, size.height - max(34, safe.bottom) - 80) - primaryPairOffset)
        case .right:
            return CGPoint(x: size.width - safe.trailing - dockSize(vertical: true).width / 2 - edgeInset,
                           y: min(size.height * 0.72, size.height - max(34, safe.bottom) - 80) - primaryPairOffset)
        }
    }
    private func landingCentre(_ p: Stop, size: CGSize, safe: EdgeInsets) -> CGPoint {
        guard p == .bottom else { return centre(p, size: size, safe: safe) }
        return CGPoint(x: size.width / 2,
                       y: centre(.bottom, size: size, safe: safe).y - actionHeight)
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    private func candidate(at point: CGPoint, size: CGSize, safe: EdgeInsets) -> Stop? {
        if let target, distance(point, landingCentre(target, size: size, safe: safe)) < capture + 15 { return target }
        return Stop.allCases.min { distance(point, landingCentre($0, size: size, safe: safe)) < distance(point, landingCentre($1, size: size, safe: safe)) }
            .flatMap { distance(point, landingCentre($0, size: size, safe: safe)) < capture ? $0 : nil }
    }
    private func dockPoint(size: CGSize, safe: EdgeInsets) -> CGPoint {
        guard dragging else { return centre(stop, size: size, safe: safe) }
        var point = finger ?? CGPoint(x: size.width * 0.72,
                                      y: landingCentre(.bottom, size: size, safe: safe).y + tokenSize * 0.75)
        if let target, !reduceMotion {
            let c = landingCentre(target, size: size, safe: safe)
            let d = distance(point, c)
            let pull = min(d, attraction * max(0, 1 - d / (capture + 15)))
            if d > 0 { point.x += (c.x - point.x) / d * pull; point.y += (c.y - point.y) / d * pull }
        }
        point.y -= tokenSize * 0.9
        return CGPoint(x: min(max(tokenSize / 2, point.x), size.width - tokenSize / 2),
                       y: min(max(max(54, safe.top) + tokenSize / 2, point.y),
                              size.height - max(34, safe.bottom) - tokenSize / 2))
    }
    private func dockGesture(size: CGSize, safe: EdgeInsets) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("prototypeCanvas"))
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                finger = value.location
                if !dragging && hypot(value.translation.width, value.translation.height) >= 9 {
                    withAnimation(dockMorph) { dragging = true }
                }
                guard dragging else { return }
                let next = candidate(at: value.location, size: size, safe: safe)
                if next != target { target = next; if next != nil { tick() } }
            }
            .onEnded { value in
                if dragging {
                    let next = candidate(at: value.location, size: size, safe: safe)
                    withAnimation(landing) { if let next { stop = next }; resetDrag() }
                    message = next.map { "Docked \($0.rawValue) · no decision made" } ?? "Move cancelled · no decision made"
                } else {
                    let c = centre(stop, size: size, safe: safe)
                    let axis = stop == .bottom ? value.startLocation.x - c.x : value.startLocation.y - c.y
                    if stop != .bottom, separatedEdgeControls, (21...37).contains(axis) {
                        message = "No action · space between Delete and Keep"
                    } else if axis < -46 {
                        undo()
                    } else if axis < 25 {
                        decide(true)
                    } else {
                        decide(false)
                    }
                }
            }
    }
    private func resetDrag() { dragging = false; finger = nil; target = nil }
    private func tick() { if haptics { UISelectionFeedbackGenerator().selectionChanged() } }
    private func decide(_ mark: Bool) {
        history.append(mark); message = "\(mark ? "Marked" : "Kept") sample · \(history.count) decisions · \(marked) marked"; tick()
    }
    private func undo() {
        if !history.isEmpty { history.removeLast() }
        message = "Undo · \(history.count) decisions · \(marked) marked"; tick()
    }
    private var settings: some View {
        NavigationStack {
            Form {
                Section("Prototype — no real photos or deletion") {
                    Text("Tap Trash or Keep. Drag anywhere on the tray to move it. A movement cancels the tap. Home opens these tuning controls.")
                    Text("\(message)")
                }
                Section("Magnetic landing") {
                    Text("Capture distance: \(Int(capture)) pt")
                    Slider(value: $capture, in: 55...120, step: 5)
                    Text("Maximum attraction: \(Int(attraction)) pt")
                    Slider(value: $attraction, in: 0...24, step: 2)
                    Picker("Position", selection: $stop) {
                        ForEach(Stop.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                Toggle("Haptics", isOn: $haptics)
                Toggle("4:3 edge-check image", isOn: $diagnosticImage)
                Button("Reset sample decisions") { history = []; message = "Sample decisions reset" }
            }.navigationTitle("Viewer prototype")
                .toolbar { Button("Done") { showSettings = false } }
        }
    }
}

private struct PrototypeSwipeSurface: View {
    @Environment(\.scenePhase) private var scenePhase
    let diagnosticImage: Bool
    let dockDragging: Bool
    let reduceMotion: Bool
    let onDecision: (Bool) -> Void
    @State private var drag: CGFloat = 0

    private var landing: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.3, bounce: 0.12)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let progress = min(abs(drag) / 120, 1)
            let deleting = drag < 0
            let tint = deleting ? Color.red : Color.green
            ZStack {
                sample
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1 - progress * 0.045)
                    .rotationEffect(.degrees(Double(drag / max(size.width, 1)) * 5), anchor: .bottom)
                    .offset(x: drag)

                LinearGradient(colors: deleting ? [tint.opacity(0.72), .clear] : [.clear, tint.opacity(0.72)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: min(150, size.width * 0.4), height: size.height)
                    .position(x: deleting ? 75 : size.width - 75, y: size.height / 2)
                    .opacity(progress)

                HStack(spacing: 10) {
                    Image(systemName: deleting ? "trash.fill" : "checkmark")
                    Text(deleting ? "Delete" : "Keep")
                }
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .shadow(color: .black.opacity(0.85), radius: 4, y: 2)
                .position(x: size.width * (deleting ? 0.28 : 0.72), y: size.height / 3)
                .opacity(progress)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 15).onChanged { value in
                guard !dockDragging,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                drag = value.translation.width
            }.onEnded { value in
                guard !dockDragging else { return }
                if abs(value.translation.width) > 90,
                   abs(value.translation.width) > abs(value.translation.height) {
                    onDecision(value.translation.width < 0)
                }
                withAnimation(landing) { drag = 0 }
            })
        }
        .clipped()
        .onChange(of: dockDragging) { _, movingDock in
            if movingDock { drag = 0 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { drag = 0 }
        }
    }

    @ViewBuilder private var sample: some View {
        if diagnosticImage {
            ZStack {
                Color.white
                Rectangle().strokeBorder(.red, lineWidth: 8)
                VStack {
                    Text("TOP — complete 4:3 image")
                    Spacer()
                    Text("LEFT                         RIGHT")
                    Spacer()
                    Text("BOTTOM — all edges must remain visible")
                }.foregroundStyle(.black).padding(14)
            }.aspectRatio(4 / 3, contentMode: .fit)
        } else {
            Image("PrototypeCoast").resizable().scaledToFit()
        }
    }
}

private struct PrototypeGlass: ViewModifier {
    let opaque: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if opaque {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

private struct PrototypeTintedGlass: ViewModifier {
    let tint: Color
    let circle: Bool

    @ViewBuilder func body(content: Content) -> some View {
        let tintStrength = circle ? 0.06 : 0.10
        if circle {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.clear.tint(tint.opacity(tintStrength)), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.75))
                    .shadow(color: tint.opacity(0.18), radius: 12, y: 7)
            } else {
                content
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(tint.opacity(0.28), lineWidth: 1))
            }
        } else {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.clear.tint(tint.opacity(tintStrength)), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.75))
                    .shadow(color: tint.opacity(0.20), radius: 12, y: 7)
            } else {
                content
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(tint.opacity(0.32), lineWidth: 1))
            }
        }
    }
}

private struct PrototypeNeutralGlass: ViewModifier {
    let circle: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if circle {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.18), radius: 9, y: 5)
            } else {
                content.background(.regularMaterial, in: Circle())
            }
        } else {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.18), radius: 9, y: 5)
            } else {
                content.background(.regularMaterial, in: Capsule())
            }
        }
    }
}
#endif
