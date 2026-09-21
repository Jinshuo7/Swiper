import SwiperKit
import SwiftUI

struct DeletionReviewView: View {
    @EnvironmentObject private var model: AppModel

    @State private var isSelecting = false
    @State private var selected: Set<String> = []
    @State private var inspected: IdentifiedString?
    @State private var showDeleteConfirmation = false
    @State private var dragStartLocation: CGPoint?
    @State private var dragBaseSelection: Set<String> = []

    private let columns = 3
    private let spacing: CGFloat = 2

    private var markedIDs: [String] { model.markedIDs }

    var body: some View {
        VStack(spacing: 0) {
            header
            if markedIDs.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                grid
                bottomBar
            }
        }
        .fullScreenCover(item: $inspected) { item in
            InspectionView(id: item.id)
        }
        .alert("Delete \(markedIDs.count) \(markedIDs.count == 1 ? "photo" : "photos")?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await model.confirmDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the marked photos from your library after the system confirmation. Photos you restored stay put.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                model.leaveReview()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("review.back")
            Spacer()
            VStack(spacing: 2) {
                Text("Review deletion")
                    .font(.headline)
                Text(DeletionWording.markedForDeletion(markedIDs.count))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityIdentifier("review.markedCount")
            }
            Spacer()
            if markedIDs.isEmpty {
                Color.clear.frame(width: 44, height: 44)
            } else {
                Button(isSelecting ? "Done" : "Select") {
                    isSelecting.toggle()
                    if !isSelecting { selected.removeAll() }
                }
                .font(.subheadline.weight(.semibold))
                .frame(width: 60, height: 44)
                .accessibilityIdentifier("review.selectToggle")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Grid

    private var grid: some View {
        GeometryReader { geometry in
            let cellWidth = (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(Array(markedIDs.enumerated()), id: \.element) { index, id in
                        ReviewCell(
                            id: id,
                            isSelecting: isSelecting,
                            isSelected: selected.contains(id)
                        )
                        .frame(height: cellWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { handleTap(id: id) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("review.cell.\(index)")
                        .accessibilityLabel(
                            "\(isSelecting && selected.contains(id) ? "Selected, " : "")Marked photo \(index + 1) of \(markedIDs.count)"
                        )
                        .accessibilityHint(isSelecting ? "Double tap to select or deselect" : "Double tap to inspect")
                    }
                }
                .coordinateSpace(name: "reviewGrid")
                .gesture(
                    selectionGesture(cellWidth: cellWidth),
                    including: isSelecting ? .all : .none
                )
            }
            .scrollDisabled(isSelecting)
        }
        .padding(.horizontal, spacing)
    }

    private func selectionGesture(cellWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("reviewGrid"))
            .onChanged { value in
                if dragStartLocation == nil {
                    dragStartLocation = value.startLocation
                    dragBaseSelection = selected
                }
                let rect = CGRect(
                    x: min(value.startLocation.x, value.location.x),
                    y: min(value.startLocation.y, value.location.y),
                    width: max(abs(value.location.x - value.startLocation.x), 1),
                    height: max(abs(value.location.y - value.startLocation.y), 1)
                )
                let ids = ids(in: rect, cellWidth: cellWidth)
                selected = dragBaseSelection.union(ids)
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 6 {
                    toggle(idAt: value.location, cellWidth: cellWidth)
                }
                dragStartLocation = nil
                dragBaseSelection = []
            }
    }

    private func handleTap(id: String) {
        if isSelecting {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        } else {
            inspected = IdentifiedString(id: id)
        }
    }

    private func toggle(idAt point: CGPoint, cellWidth: CGFloat) {
        if let id = id(at: point, cellWidth: cellWidth) {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        }
    }

    private func id(at point: CGPoint, cellWidth: CGFloat) -> String? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let column = Int(point.x / (cellWidth + spacing))
        let row = Int(point.y / (cellWidth + spacing))
        guard column >= 0, column < columns, row >= 0 else { return nil }
        let index = row * columns + column
        return markedIDs.indices.contains(index) ? markedIDs[index] : nil
    }

    private func ids(in rect: CGRect, cellWidth: CGFloat) -> Set<String> {
        guard !rect.isNull else { return [] }
        var result = Set<String>()
        for (index, id) in markedIDs.enumerated() {
            let row = index / columns
            let column = index % columns
            let frame = CGRect(
                x: CGFloat(column) * (cellWidth + spacing),
                y: CGFloat(row) * (cellWidth + spacing),
                width: cellWidth,
                height: cellWidth
            )
            if frame.intersects(rect) { result.insert(id) }
        }
        return result
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if isSelecting {
                Button {
                    model.restore(ids: Array(selected))
                    selected.removeAll()
                    if model.queueCount == 0 { isSelecting = false }
                } label: {
                    Label("Restore \(selected.count) selected", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("review.restoreSelected")
            } else {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete \(markedIDs.count) \(markedIDs.count == 1 ? "photo" : "photos")", systemImage: "trash")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isBusy)
                .accessibilityIdentifier("review.delete")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.001))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.7))
            Text("Nothing is marked for deletion")
                .foregroundStyle(.white.opacity(0.75))
            Button("Done") { model.leaveReview() }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 60)
                .accessibilityIdentifier("review.emptyDone")
        }
    }
}

private struct ReviewCell: View {
    @EnvironmentObject private var model: AppModel
    let id: String
    let isSelecting: Bool
    let isSelected: Bool

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.opacity(0.05)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.white)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .padding(6)
            }
        }
        .clipped()
        .task(id: id) {
            image = await model.library.thumbnail(for: id, targetSize: CGSize(width: 240, height: 240))
        }
    }
}

private struct InspectionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let id: String

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .overlay(alignment: .topLeading) {
                TopBarButton(systemImage: "xmark", label: "Close") { dismiss() }
                    .padding(16)
            }
            .overlay(alignment: .bottom) {
                Button {
                    model.restore(ids: [id])
                    dismiss()
                } label: {
                    Label("Restore photo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
                .accessibilityIdentifier("inspect.restore")
            }
            .task(id: id) {
                image = await model.library.displayImage(for: id, targetSize: geometry.size)
            }
        }
    }
}

private struct IdentifiedString: Identifiable {
    let id: String
}
