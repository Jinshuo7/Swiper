#if DEBUG
import SwiftUI
import UIKit

/// Throwaway: does a handle-free, magnetic dock distinguish taps from moves?
/// Launch with -viewerDockPrototype. No PhotoKit, saved state, or deletion.
struct ViewerDockPrototype: View {
    enum Stop: String, CaseIterable { case left, bottom, right }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @State private var stop = Stop.bottom
    @State private var target: Stop?
    @State private var finger: CGPoint?
    @GestureState private var touching = false
    @State private var dragging = false
    @State private var showSettings = false
    @State private var showReview = false
    @State private var history: [Bool] = []
    @State private var message = "Drag the tray to move it. Tap to decide."
    @State private var capture = 85.0
    @State private var attraction = 12.0
    @State private var haptics = true
    @State private var diagnosticImage = false
    @State private var imageDrag: CGFloat = 0
    private let tokenSize: CGFloat = 44
    private let dockLength: CGFloat = 168
    private let dockThickness: CGFloat = 60

    private var landing: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.32, bounce: 0.16)
    }
    private var marked: Int { history.filter { $0 }.count }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safe = proxy.safeAreaInsets
            ZStack {
                Color.black
                sample
                    .frame(width: size.width, height: size.height)
                    .offset(x: imageDrag)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 15).onChanged { value in
                        guard !dragging, abs(value.translation.width) > abs(value.translation.height) else { return }
                        imageDrag = value.translation.width
                    }.onEnded { value in
                        guard !dragging else { return }
                        if abs(value.translation.width) > 90,
                           abs(value.translation.width) > abs(value.translation.height) {
                            decide(value.translation.width < 0)
                        }
                        withAnimation(landing) { imageDrag = 0 }
                    })

                if abs(imageDrag) > 15 {
                    Text(imageDrag < 0 ? "Mark" : "Keep")
                        .font(.headline).foregroundStyle(imageDrag < 0 ? .red : .green)
                        .padding(12).modifier(PrototypeGlass(opaque: reduceTransparency))
                        .position(x: imageDrag < 0 ? 58 : size.width - 58, y: size.height * 0.6)
                        .allowsHitTesting(false)
                }
                navigation(safe: safe)
                if dragging {
                    ForEach(Stop.allCases, id: \.self) { candidate in
                        let active = target == candidate
                        Capsule().fill(.white.opacity(active ? 0.95 : 0.35))
                            .frame(width: candidate == .bottom ? (active ? 38 : 20) : 4,
                                   height: candidate == .bottom ? 4 : (active ? 38 : 20))
                            .shadow(color: .black.opacity(0.5), radius: 3)
                            .position(marker(candidate, size: size, safe: safe))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: active)
                            .allowsHitTesting(false)
                    }
                }
                dock
                    .position(dockPoint(size: size, safe: safe))
                    .gesture(dockGesture(size: size, safe: safe))
                VStack {
                    Spacer()
                    Text(message).font(.caption2).multilineTextAlignment(.center)
                        .accessibilityIdentifier("prototype.status")
                        .foregroundStyle(.white).padding(6)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, max(4, safe.bottom - 4))
                }.allowsHitTesting(false)
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
            if phase != .active { resetDrag(); imageDrag = 0 }
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

    @ViewBuilder private var sample: some View {
        if diagnosticImage {
            // A 4:3 fixture makes accidental crop/resizing obvious.
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

    private func navigation(safe: EdgeInsets) -> some View {
        VStack {
            HStack(alignment: .top) {
                Button { showSettings = true } label: {
                    Image(systemName: "house").frame(width: 44, height: 44)
                }.modifier(PrototypeGlass(opaque: reduceTransparency))
                    .accessibilityLabel("Prototype settings")
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Button { showReview = true } label: {
                        Text("Review · \(marked)").font(.subheadline.weight(.medium))
                            .padding(.horizontal, 13).frame(height: 44)
                    }.modifier(PrototypeGlass(opaque: reduceTransparency))
                    Text("PHOTO").font(.caption2.weight(.medium))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .modifier(PrototypeGlass(opaque: reduceTransparency))
                }
            }.foregroundStyle(.primary)
                .padding(.horizontal, 16).padding(.top, max(54, safe.top) + 8)
            Spacer()
        }
    }

    private var dock: some View {
        let vertical = stop != .bottom
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        return ZStack {
            if dragging {
                Image(systemName: "rectangle.stack").font(.system(size: 17, weight: .medium))
                    .transition(.opacity)
            } else {
                layout {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium)).frame(width: 44, height: 44)
                    Image(systemName: "trash.fill").font(.system(size: 23, weight: .semibold))
                        .frame(width: 48, height: 48).foregroundStyle(.white)
                        .background(.red, in: Circle())
                    Image(systemName: "checkmark").font(.system(size: 25, weight: .semibold))
                        .frame(width: 48, height: 48).foregroundStyle(.white)
                        .background(.green, in: Circle())
                }.transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.85)))
            }
        }
        .frame(width: dragging ? tokenSize : (vertical ? dockThickness : dockLength),
               height: dragging ? tokenSize : (vertical ? dockLength : dockThickness))
        .modifier(PrototypeGlass(opaque: reduceTransparency))
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

    private func centre(_ p: Stop, size: CGSize, safe: EdgeInsets) -> CGPoint {
        switch p {
        case .bottom: return CGPoint(x: size.width / 2, y: size.height - max(34, safe.bottom) - 48)
        case .left: return CGPoint(x: 46, y: min(size.height * 0.72, size.height - max(34, safe.bottom) - 94))
        case .right: return CGPoint(x: size.width - 46, y: min(size.height * 0.72, size.height - max(34, safe.bottom) - 94))
        }
    }
    private func marker(_ p: Stop, size: CGSize, safe: EdgeInsets) -> CGPoint {
        let c = centre(p, size: size, safe: safe)
        return p == .bottom ? CGPoint(x: c.x, y: size.height - max(34, safe.bottom) - 10)
            : CGPoint(x: p == .left ? 8 : size.width - 8, y: c.y)
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    private func candidate(at point: CGPoint, size: CGSize, safe: EdgeInsets) -> Stop? {
        if let target, distance(point, centre(target, size: size, safe: safe)) < capture + 15 { return target }
        return Stop.allCases.min { distance(point, centre($0, size: size, safe: safe)) < distance(point, centre($1, size: size, safe: safe)) }
            .flatMap { distance(point, centre($0, size: size, safe: safe)) < capture ? $0 : nil }
    }
    private func dockPoint(size: CGSize, safe: EdgeInsets) -> CGPoint {
        guard dragging, var point = finger else { return centre(stop, size: size, safe: safe) }
        if let target, !reduceMotion {
            let c = centre(target, size: size, safe: safe)
            let d = distance(point, c)
            let pull = min(d, attraction * max(0, 1 - d / (capture + 15)))
            if d > 0 { point.x += (c.x - point.x) / d * pull; point.y += (c.y - point.y) / d * pull }
        }
        return CGPoint(x: min(max(26, point.x), size.width - 26),
                       y: min(max(max(54, safe.top) + 26, point.y), size.height - max(34, safe.bottom) - 26))
    }
    private func dockGesture(size: CGSize, safe: EdgeInsets) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("prototypeCanvas"))
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                if !dragging && hypot(value.translation.width, value.translation.height) >= 9 {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { dragging = true }
                }
                guard dragging else { return }
                finger = value.location
                let next = candidate(at: value.location, size: size, safe: safe)
                if next != target { target = next; if next != nil { tick() } }
                message = target.map { "Release to dock \($0.rawValue)" } ?? "Moving · release away from an edge to cancel"
            }
            .onEnded { value in
                if dragging {
                    let next = candidate(at: value.location, size: size, safe: safe)
                    withAnimation(landing) { if let next { stop = next }; resetDrag() }
                    message = next.map { "Docked \($0.rawValue) · no decision made" } ?? "Move cancelled · no decision made"
                } else {
                    let c = centre(stop, size: size, safe: safe)
                    let axis = stop == .bottom ? value.startLocation.x - c.x : value.startLocation.y - c.y
                    if axis < -28 { undo() } else if axis < 24 { decide(true) } else { decide(false) }
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
#endif
