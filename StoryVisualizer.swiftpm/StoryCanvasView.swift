import SwiftUI
import UIKit
import PhotosUI

struct StoryCanvasView: View {
    @Binding var project: Project
    @State private var isTargeted = false
    @State private var viewportSize: CGSize = .zero
    @State private var cameraOffset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var zoomScale: CGFloat = CanvasCamera.initialZoomScale
    @State private var zoomStartScale: CGFloat?
    @State private var selectedMainNodeID: UUID?
    @State private var movingMainNodeID: UUID?
    @State private var movingMainStartPosition: CGPoint = .zero
    @State private var resizingLocationNodeID: UUID?
    @State private var resizeStartMiniSize: CGSize = .zero
    @State private var pendingMainDeletion: PendingMainDeletion?
    
    private var isAnyEditModeActive: Bool {
        selectedMainNodeID != nil || project.canvasNodes.contains { node in
            node.locationData?.isMiniEditing == true
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            topRibbon

            GeometryReader { viewport in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray6))
                        .overlay {
                            if isTargeted {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            }
                        }

                    ForEach($project.canvasNodes) { $node in
                        CanvasNodeContainer(
                            node: $node,
                            isSelected: selectedMainNodeID == node.id,
                            zoomScale: zoomScale,
                            worldToViewport: worldToViewport,
                            onMoveMiniNodeToMain: moveMiniNodeToMain,
                            onDelete: {
                                pendingMainDeletion = PendingMainDeletion(nodeID: node.id)
                            }
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if selectedMainNodeID == node.id, node.type == .location {
                                locationResizeHandle(for: $node)
                                    .offset(x: -8, y: -8)
                            }
                        }
                        .scaleEffect(zoomScale, anchor: .center)
                        .position(worldToViewport(node.position))
                        .onLongPressGesture(minimumDuration: 0.35) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                guard !isAnyMiniCanvasInEditMode() else { return }
                                clearMiniEditModes()
                                selectedMainNodeID = node.id
                            }
                        }
                         .simultaneousGesture(
                             DragGesture(minimumDistance: 1)
                                 .onChanged { value in
                                     guard selectedMainNodeID == node.id else { return }
                                     guard resizingLocationNodeID != node.id else { return }
                                     guard !isAnyMiniCanvasInEditMode() else { return }
                                     if movingMainNodeID != node.id {
                                         movingMainNodeID = node.id
                                         movingMainStartPosition = node.position
                                     }
                                     let newPos = CGPoint(
                                         x: movingMainStartPosition.x + (value.translation.width / zoomScale),
                                         y: movingMainStartPosition.y + (value.translation.height / zoomScale)
                                     )
                                     node.position = newPos
                                     
                                     for i in project.canvasNodes.indices {
                                         if project.canvasNodes[i].type == .location && project.canvasNodes[i].id != node.id {
                                             if let frame = miniCanvasWorldFrame(for: project.canvasNodes[i]) {
                                                 project.canvasNodes[i].locationData?.isMiniCanvasTargeted = frame.contains(newPos)
                                             }
                                         }
                                     }
                                 }
                                 .onEnded { _ in
                                     guard selectedMainNodeID == node.id else { return }
                                     guard resizingLocationNodeID != node.id else { return }
                                     
                                     for i in project.canvasNodes.indices {
                                         project.canvasNodes[i].locationData?.isMiniCanvasTargeted = false
                                     }

                                     if moveMainNodeIntoMiniCanvasIfNeeded(nodeID: node.id) {
                                         movingMainNodeID = nil
                                         return
                                     }
                                     let others = project.canvasNodes.filter { $0.id != node.id }
                                     node.position = nearestFreeWorldPosition(
                                         desired: node.position,
                                         itemSize: canvasNodeSize(node),
                                         existing: others
                                    )
                                    movingMainNodeID = nil
                                }
                        )
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    cameraOffset = .zero
                                    panStartOffset = nil
                                    zoomScale = CanvasCamera.initialZoomScale
                                    zoomStartScale = nil
                                }
                            } label: {
                                Circle()
                                    .fill(Color.white.opacity(0.95))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Image(systemName: "scope")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(Color.black.opacity(0.8))
                                    }
                                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .onAppear {
                    viewportSize = viewport.size
                    zoomScale = CanvasCamera.initialZoomScale
                }
                .onChange(of: viewport.size) { newSize in
                    viewportSize = newSize
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            guard selectedMainNodeID == nil else { return }
                            guard !isAnyMiniCanvasInEditMode() else { return }
                            if panStartOffset == nil {
                                panStartOffset = cameraOffset
                            }
                            guard let start = panStartOffset else { return }
                            cameraOffset = CGSize(
                                width: start.width - (value.translation.width / zoomScale),
                                height: start.height - (value.translation.height / zoomScale)
                            )
                        }
                        .onEnded { _ in
                            panStartOffset = nil
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if zoomStartScale == nil {
                                zoomStartScale = zoomScale
                            }
                            guard let start = zoomStartScale else { return }
                            zoomScale = min(max(start * value, 0.01), 2.8)
                        }
                        .onEnded { _ in
                            zoomStartScale = nil
                        }
                )
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let worldPoint = viewportToWorld(value.location)
                            if selectedMainNodeID != nil {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedMainNodeID = nil
                                }
                                movingMainNodeID = nil
                                resizingLocationNodeID = nil
                            }
                            clearMiniEditModes()
                            collapseChoicesCardsIfNeeded(at: worldPoint)
                        }
                )
                .dropDestination(for: String.self) { items, location in
                    handleMainDrop(items: items, at: viewportToWorld(location))
                } isTargeted: { targeted in
                    isTargeted = targeted
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray5))
        .navigationTitle("\(project.name) Canvas")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $pendingMainDeletion) { pending in
            Alert(
                title: Text("Delete Box"),
                message: Text("This will delete the item and all its contents."),
                primaryButton: .destructive(Text("Delete")) {
                    project.canvasNodes.removeAll { $0.id == pending.nodeID }
                    if selectedMainNodeID == pending.nodeID {
                        selectedMainNodeID = nil
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private var topRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CanvasNodeType.toolbarOrder) { type in
                    ToolbarDraggableBox(type: type)
                        .draggable(type.rawValue)
                }
            }
            .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray4).opacity(0.45))
        )
        .allowsHitTesting(!isAnyEditModeActive)
        .disabled(isAnyEditModeActive)
        .opacity(isAnyEditModeActive ? 0.55 : 1)
    }

    private func handleMainDrop(items: [String], at location: CGPoint) -> Bool {
        guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else {
            return false
        }

        var node = defaultNode(for: type)
        node.position = nearestFreeWorldPosition(
            desired: location,
            itemSize: canvasNodeSize(node),
            existing: project.canvasNodes
        )
        project.canvasNodes.append(node)
        return true
    }

    private func collapseChoicesCardsIfNeeded(at point: CGPoint) {
        let tappedInsideChoicesCard = project.canvasNodes.contains { node in
            guard node.type == .choices else { return false }
            let nodeSize = canvasNodeSize(node)
            let frame = CGRect(
                x: node.position.x - nodeSize.width / 2,
                y: node.position.y - nodeSize.height / 2,
                width: nodeSize.width,
                height: nodeSize.height
            )
            return frame.contains(point)
        }

        guard !tappedInsideChoicesCard else { return }
        for index in project.canvasNodes.indices {
            guard project.canvasNodes[index].type == .choices else { continue }
            project.canvasNodes[index].choicesData?.isCollapsed = true
        }
    }
    
     private func clearMiniEditModes() {
         for index in project.canvasNodes.indices {
             guard project.canvasNodes[index].type == .location else { continue }
             guard var locationData = project.canvasNodes[index].locationData else { continue }
             locationData.isMiniEditing = false
             locationData.selectedMiniNodeID = nil
             project.canvasNodes[index].locationData = locationData
         }
     }
     
     private func isAnyMiniCanvasInEditMode() -> Bool {
         return project.canvasNodes.contains { node in
             node.type == .location && node.locationData?.isMiniEditing == true
         }
     }

    private func worldToViewport(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: ((point.x - cameraOffset.width) * zoomScale) + viewportSize.width / 2,
            y: ((point.y - cameraOffset.height) * zoomScale) + viewportSize.height / 2
        )
    }

    private func viewportToWorld(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: ((point.x - viewportSize.width / 2) / zoomScale) + cameraOffset.width,
            y: ((point.y - viewportSize.height / 2) / zoomScale) + cameraOffset.height
        )
    }

    private func nearestFreeWorldPosition(desired: CGPoint, itemSize: CGSize, existing: [CanvasNode]) -> CGPoint {
        let baseRect = rectCentered(at: desired, size: itemSize)
        if !intersectsAny(rect: baseRect, nodes: existing) {
            return desired
        }

        let step: CGFloat = 36
        for radius in 1...120 {
            for gx in -radius...radius {
                for gy in -radius...radius {
                    guard abs(gx) == radius || abs(gy) == radius else { continue }
                    let candidate = CGPoint(
                        x: desired.x + CGFloat(gx) * step,
                        y: desired.y + CGFloat(gy) * step
                    )
                    if !intersectsAny(rect: rectCentered(at: candidate, size: itemSize), nodes: existing) {
                        return candidate
                    }
                }
            }
        }

        return CGPoint(x: desired.x + 240, y: desired.y + 240)
    }

    @ViewBuilder
    private func locationResizeHandle(for node: Binding<CanvasNode>) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 24, height: 24)
            .overlay {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard node.wrappedValue.type == .location else { return }
                        if resizingLocationNodeID != node.wrappedValue.id {
                            resizingLocationNodeID = node.wrappedValue.id
                            let startData = node.wrappedValue.locationData ?? .defaultData
                            resizeStartMiniSize = CGSize(
                                width: startData.pinnedMiniCanvasWidth,
                                height: startData.pinnedMiniCanvasHeight
                            )
                        }
                        guard var locationData = node.wrappedValue.locationData else { return }

                        let minWidth = minimumMiniCanvasWidth(for: locationData)
                        let minHeight = minimumMiniCanvasHeight(for: locationData)

                        locationData.pinnedMiniCanvasWidth = max(
                            minWidth,
                            resizeStartMiniSize.width + (value.translation.width / zoomScale)
                        )
                        locationData.pinnedMiniCanvasHeight = max(
                            minHeight,
                            resizeStartMiniSize.height + (value.translation.height / zoomScale)
                        )
                        node.wrappedValue.locationData = locationData
                    }
                    .onEnded { _ in
                        resizingLocationNodeID = nil
                    }
            )
    }

    private func minimumMiniCanvasWidth(for data: LocationCardData) -> CGFloat {
        let contentRequired = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
            let size = canvasNodeSize(miniNode)
            return max(
                currentMax,
                miniNode.position.x + size.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding
            )
        }
        return max(LocationCardLayout.miniCanvasMinWidth, contentRequired)
    }

    private func minimumMiniCanvasHeight(for data: LocationCardData) -> CGFloat {
        let contentRequired = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
            let size = canvasNodeSize(miniNode)
            return max(
                currentMax,
                miniNode.position.y + size.height / 2 + LocationCardLayout.miniCanvasVerticalPadding
            )
        }
        return max(LocationCardLayout.miniCanvasMinHeight, contentRequired)
    }

     private func moveMainNodeIntoMiniCanvasIfNeeded(nodeID: UUID) -> Bool {
         guard let movingIndex = project.canvasNodes.firstIndex(where: { $0.id == nodeID }) else {
             return false
         }

         let node = project.canvasNodes[movingIndex]
         guard let targetLocationID = findTargetLocationID(forWorldPoint: node.position, excluding: node.id),
               let targetLocationNode = project.canvasNodes.first(where: { $0.id == targetLocationID }),
               let miniFrame = miniCanvasWorldFrame(for: targetLocationNode) else {
             return false
         }

         // Find target location index BEFORE removing the node
         guard let targetLocationIndex = project.canvasNodes.firstIndex(where: { $0.id == targetLocationID }) else {
             return false
         }

         var movedNode = node
         let localDesired = CGPoint(
             x: movedNode.position.x - miniFrame.minX,
             y: movedNode.position.y - miniFrame.minY
         )
         
         guard var targetLocationData = project.canvasNodes[targetLocationIndex].locationData else {
             return false
         }

         let currentMiniSize = miniCanvasSize(for: targetLocationData)
         let placement = placeNodeWithoutOverlapInMini(
             desired: localDesired,
             itemSize: canvasNodeSize(movedNode),
             existing: targetLocationData.miniNodes,
             currentCanvasSize: currentMiniSize
         )

         movedNode.position = placement.position
         targetLocationData.pinnedMiniCanvasWidth = max(targetLocationData.pinnedMiniCanvasWidth, placement.requiredSize.width)
         targetLocationData.pinnedMiniCanvasHeight = max(targetLocationData.pinnedMiniCanvasHeight, placement.requiredSize.height)
         targetLocationData.miniNodes.append(movedNode)
         targetLocationData.isMiniEditing = false
         targetLocationData.selectedMiniNodeID = nil
         
         // Update the location card with new data
         project.canvasNodes[targetLocationIndex].locationData = targetLocationData
         
         // Remove the node from main canvas AFTER updating the location card
         project.canvasNodes.remove(at: movingIndex)
         
         selectedMainNodeID = nil
         return true
     }

    private func moveMiniNodeToMain(from sourceLocationID: UUID, miniNode: CanvasNode, desiredWorldPosition: CGPoint) {
        guard let sourceLocationIndex = project.canvasNodes.firstIndex(where: { $0.id == sourceLocationID }),
              var sourceLocationData = project.canvasNodes[sourceLocationIndex].locationData else {
            return
        }

        sourceLocationData.miniNodes.removeAll { $0.id == miniNode.id }
        sourceLocationData.selectedMiniNodeID = nil
        sourceLocationData.isMiniEditing = false
        project.canvasNodes[sourceLocationIndex].locationData = sourceLocationData

        var movedNode = miniNode
        movedNode.position = nearestFreeWorldPosition(
            desired: desiredWorldPosition,
            itemSize: canvasNodeSize(movedNode),
            existing: project.canvasNodes
        )
        project.canvasNodes.append(movedNode)
        selectedMainNodeID = movedNode.id
    }

    private func findTargetLocationID(forWorldPoint point: CGPoint, excluding nodeID: UUID) -> UUID? {
        for node in project.canvasNodes.reversed() {
            guard node.id != nodeID else { continue }
            guard node.type == .location else { continue }
            guard let frame = miniCanvasWorldFrame(for: node) else { continue }
            if frame.contains(point) {
                return node.id
            }
        }
        return nil
    }

    private func miniCanvasWorldFrame(for locationNode: CanvasNode) -> CGRect? {
        guard locationNode.type == .location, let data = locationNode.locationData else {
            return nil
        }
        let cardSize = locationCardSize(data)
        let miniSize = miniCanvasSize(for: data)
        let cardTopLeft = CGPoint(
            x: locationNode.position.x - cardSize.width / 2,
            y: locationNode.position.y - cardSize.height / 2
        )
        let miniOrigin = CGPoint(
            x: cardTopLeft.x + LocationCardLayout.outerHorizontalPadding,
            y: cardTopLeft.y + LocationCardLayout.outerTopPadding + LocationCardLayout.headerHeight + LocationCardLayout.headerToMiniGap
        )
        return CGRect(origin: miniOrigin, size: miniSize)
    }
}

private struct PendingMainDeletion: Identifiable {
    let id = UUID()
    let nodeID: UUID
}

private enum CanvasCamera {
    static let initialZoomScale: CGFloat = 1.0
}

private struct ToolbarDraggableBox: View {
    let type: CanvasNodeType

    var body: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(type.fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(type.borderColor, lineWidth: 2)
            }
            .frame(width: type == .location ? 100 : 90, height: 44)
            .overlay {
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.72))
            }
    }
}

private struct CanvasNodeView: View {
    @Binding var node: CanvasNode
    let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void

    var body: some View {
        switch node.type {
        case .location:
            LocationCanvasCard(
                node: $node,
                onMoveMiniNodeToMain: onMoveMiniNodeToMain
            )
        case .choices:
            ChoicesCanvasCard(data: Binding(
                get: { node.choicesData ?? .defaultData },
                set: { node.choicesData = $0 }
            ))
        case .prop:
            PropCanvasCard(data: Binding(
                get: { node.propData ?? .defaultData },
                set: { node.propData = $0 }
            ))
        case .event:
            RoundedRectangle(cornerRadius: 10)
                .fill(node.type.fillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(node.type.borderColor, lineWidth: 2)
                }
                .overlay {
                    Text(node.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black.opacity(0.72))
                }
        }
    }
}

private func defaultNode(for type: CanvasNodeType) -> CanvasNode {
    CanvasNode(
        type: type,
        position: .zero,
        choicesData: type == .choices ? .defaultData : nil,
        locationData: type == .location ? .defaultData : nil,
        propData: type == .prop ? .defaultData : nil
    )
}

private enum LocationCardLayout {
    static let cardWidth: CGFloat = 430
    static let defaultCardHeight: CGFloat = 360
    static let outerHorizontalPadding: CGFloat = 10
    static let outerTopPadding: CGFloat = 10
    static let outerBottomPadding: CGFloat = 10
    static let headerHeight: CGFloat = 56
    static let headerToMiniGap: CGFloat = 10
    static let miniCanvasMinWidth: CGFloat = cardWidth - (outerHorizontalPadding * 2)
    static let miniCanvasMinHeight: CGFloat = 250
    static let miniCanvasHorizontalPadding: CGFloat = 12
    static let miniCanvasVerticalPadding: CGFloat = 12
    static let hoverExpansionWidth: CGFloat = 120
    static let hoverExpansionHeight: CGFloat = 90
    static let headerIconSize: CGFloat = 56
}

private struct LocationCanvasCard: View {
    @Binding var node: CanvasNode
    let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var movingMiniNodeID: UUID?
    @State private var movingMiniStartPosition: CGPoint = .zero
    @State private var pendingMiniDeletionNodeID: UUID?
    @State private var isShowingMiniDeleteDialog = false

    private var data: Binding<LocationCardData> {
        Binding(
            get: { node.locationData ?? .defaultData },
            set: { node.locationData = $0 }
        )
    }

    var body: some View {
        baseCardView
            .overlay(alignment: .topLeading) {
                cardContentView
            }
            .confirmationDialog(
                "Delete Box",
                isPresented: $isShowingMiniDeleteDialog,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let targetID = pendingMiniDeletionNodeID else { return }
                    node.locationData?.miniNodes.removeAll { $0.id == targetID }
                    if node.locationData?.selectedMiniNodeID == targetID {
                        node.locationData?.selectedMiniNodeID = nil
                    }
                    pendingMiniDeletionNodeID = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingMiniDeletionNodeID = nil
                }
            } message: {
                Text("This will delete the item and all its contents.")
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let imageData = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            node.locationData?.backgroundImageData = imageData
                        }
                    }
                }
            }
    }
    
    private var baseCardView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray4))
            .overlay {
                if let imageData = node.locationData?.backgroundImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.42))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var cardContentView: some View {
        VStack(spacing: LocationCardLayout.headerToMiniGap) {
            headerView
            miniCanvasView
        }
        .padding(10)
    }
    
    private var headerView: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: LocationCardLayout.headerIconSize, height: LocationCardLayout.headerIconSize)
                    .overlay {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.82))
                    }
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            TextField("Name of location", text: data.title)
                .font(.system(size: 24, weight: .regular))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: LocationCardLayout.headerHeight)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
        }
    }
    
    private var miniCanvasView: some View {
        GeometryReader { proxy in
            ZStack {
                canvasBackground
                miniNodesContent(proxy: proxy)
            }
            .onAppear {
                ensurePinnedCanvasCoversAllNodes()
            }
            .onChange(of: miniNodeLayoutFingerprint) { _ in
                ensurePinnedCanvasCoversAllNodes()
            }
            .onChange(of: proxy.size) { _ in
                ensurePinnedCanvasCoversAllNodes()
            }
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, location in
                handleDropOnMiniCanvas(items: items, location: location, proxySize: proxy.size)
            } isTargeted: { targeted in
                node.locationData?.isMiniCanvasTargeted = targeted
                if targeted {
                    node.locationData?.pinnedMiniCanvasWidth = max(node.locationData?.pinnedMiniCanvasWidth ?? 0, proxy.size.width)
                    node.locationData?.pinnedMiniCanvasHeight = max(node.locationData?.pinnedMiniCanvasHeight ?? 0, proxy.size.height)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var canvasBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.56))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)
            }
    }
    
    private func miniNodesContent(proxy: GeometryProxy) -> some View {
        ForEach(data.miniNodes) { $miniNode in
            miniNodeItemView(miniNode: $miniNode, proxySize: proxy.size)
        }
    }
    
     private func miniNodeItemView(miniNode: Binding<CanvasNode>, proxySize: CGSize) -> some View {
         CanvasNodeView(node: miniNode, onMoveMiniNodeToMain: onMoveMiniNodeToMain)
            .frame(
                 width: canvasNodeSize(miniNode.wrappedValue).width,
                 height: canvasNodeSize(miniNode.wrappedValue).height
             )
             .zIndex(movingMiniNodeID == miniNode.id ? 10 : 0)
             .overlay(alignment: .topTrailing) {
                if data.wrappedValue.isMiniEditing && data.wrappedValue.selectedMiniNodeID == miniNode.id {
                    miniDeleteButton(nodeID: miniNode.id)
                }
            }
            .position(miniNode.wrappedValue.position)
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            node.locationData?.isMiniEditing = true
                            node.locationData?.selectedMiniNodeID = miniNode.id
                        }
                    }
                    .simultaneously(with:
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                handleMiniNodeDragChanged(value: value, miniNode: miniNode)
                            }
                            .onEnded { _ in
                                handleMiniNodeDragEnded(miniNode: miniNode, proxySize: proxySize)
                            }
                    )
            )
    }
    
    private func miniDeleteButton(nodeID: UUID) -> some View {
        Button {
            pendingMiniDeletionNodeID = nodeID
            isShowingMiniDeleteDialog = true
        } label: {
            Circle()
                .fill(Color.red)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .offset(x: 10, y: -10)
    }
     
      private func handleMiniNodeDragChanged(value: DragGesture.Value, miniNode: Binding<CanvasNode>) {
          // Automatically select this node if dragging and not yet selected
          if node.locationData?.selectedMiniNodeID != miniNode.id {
              node.locationData?.isMiniEditing = true
              node.locationData?.selectedMiniNodeID = miniNode.id
          }
          
          guard node.locationData?.isMiniEditing == true && node.locationData?.selectedMiniNodeID == miniNode.id else { return }
          
          if movingMiniNodeID != miniNode.id {
              movingMiniNodeID = miniNode.id
              movingMiniStartPosition = miniNode.wrappedValue.position
          }
          
          let newPosition = CGPoint(
              x: movingMiniStartPosition.x + value.translation.width,
              y: movingMiniStartPosition.y + value.translation.height
          )
          miniNode.wrappedValue.position = newPosition
          
          // Expand canvas when card is dragged near edges
          let nodeSize = canvasNodeSize(miniNode.wrappedValue)
          let nodeRight = miniNode.wrappedValue.position.x + nodeSize.width / 2
          let nodeLeft = miniNode.wrappedValue.position.x - nodeSize.width / 2
          let nodeBottom = miniNode.wrappedValue.position.y + nodeSize.height / 2
          let nodeTop = miniNode.wrappedValue.position.y - nodeSize.height / 2
          
          let edgeThreshold: CGFloat = 40
          
          // Expand right
          if nodeRight > (node.locationData?.pinnedMiniCanvasWidth ?? 0) - edgeThreshold {
              node.locationData?.pinnedMiniCanvasWidth = nodeRight + edgeThreshold
          }
          
          // Expand down
          if nodeBottom > (node.locationData?.pinnedMiniCanvasHeight ?? 0) - edgeThreshold {
              node.locationData?.pinnedMiniCanvasHeight = nodeBottom + edgeThreshold
          }

          // Expand left
          if nodeLeft < edgeThreshold {
              let diff = edgeThreshold - nodeLeft
              node.locationData?.pinnedMiniCanvasWidth += diff
              
              // Shift all mini nodes right (except the current one)
              for i in 0..<(node.locationData?.miniNodes.count ?? 0) {
                  if node.locationData?.miniNodes[i].id != miniNode.id {
                      node.locationData?.miniNodes[i].position.x += diff
                  }
              }
              // Shift the one we are currently dragging too (ongoing drag)
              movingMiniStartPosition.x += diff
              miniNode.wrappedValue.position.x += diff
              
              // Shift main card world position left
              node.position.x -= diff / 2
          }

          // Expand top
          if nodeTop < edgeThreshold {
              let diff = edgeThreshold - nodeTop
              node.locationData?.pinnedMiniCanvasHeight += diff
              
              // Shift all mini nodes down (except the current one)
              for i in 0..<(node.locationData?.miniNodes.count ?? 0) {
                  if node.locationData?.miniNodes[i].id != miniNode.id {
                      node.locationData?.miniNodes[i].position.y += diff
                  }
              }
              // Shift the one we are currently dragging too
              movingMiniStartPosition.y += diff
              miniNode.wrappedValue.position.y += diff
              
              // Shift main card world position up
              node.position.y -= diff / 2
          }
          
          adjustPinnedCanvasForNode(
              at: miniNode.wrappedValue.position,
              size: canvasNodeSize(miniNode.wrappedValue)
          )
      }
    
     private func handleMiniNodeDragEnded(miniNode: Binding<CanvasNode>, proxySize: CGSize) {
         guard node.locationData?.isMiniEditing == true, node.locationData?.selectedMiniNodeID == miniNode.id else { return }
         
         let nodeSize = canvasNodeSize(miniNode.wrappedValue)
         let miniBounds = CGRect(origin: .zero, size: proxySize)
         
         // Check if node center is significantly outside bounds
         if !miniBounds.insetBy(dx: -20, dy: -20).contains(miniNode.wrappedValue.position) {
             // Clear edit mode before moving node
             node.locationData?.isMiniEditing = false
             node.locationData?.selectedMiniNodeID = nil
             
             let worldPos = worldPositionForMiniNode(
                 miniPosition: miniNode.wrappedValue.position,
                 currentMiniCanvasSize: proxySize
             )
             onMoveMiniNodeToMain(node.id, miniNode.wrappedValue, worldPos)
             movingMiniNodeID = nil
             return
         }
         let others = node.locationData?.miniNodes.filter { $0.id != miniNode.id } ?? []
         miniNode.wrappedValue.position = nearestFreeMiniPosition(
             desired: miniNode.wrappedValue.position,
             itemSize: canvasNodeSize(miniNode.wrappedValue),
             existing: others
         )
         adjustPinnedCanvasForNode(
             at: miniNode.wrappedValue.position,
             size: canvasNodeSize(miniNode.wrappedValue)
         )
         movingMiniNodeID = nil
     }
    
    private func handleDropOnMiniCanvas(items: [String], location: CGPoint, proxySize: CGSize) -> Bool {
        defer { node.locationData?.isMiniCanvasTargeted = false }
        guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else {
            return false
        }

        var newNode = defaultNode(for: type)
        let itemSize = canvasNodeSize(newNode)
        let placement = placeNodeWithoutOverlapInMini(
            desired: location,
            itemSize: itemSize,
            existing: node.locationData?.miniNodes ?? [],
            currentCanvasSize: proxySize
        )
        node.locationData?.pinnedMiniCanvasWidth = max(node.locationData?.pinnedMiniCanvasWidth ?? 0, placement.requiredSize.width)
        node.locationData?.pinnedMiniCanvasHeight = max(node.locationData?.pinnedMiniCanvasHeight ?? 0, placement.requiredSize.height)
        newNode.position = placement.position
        node.locationData?.miniNodes.append(newNode)
        ensurePinnedCanvasCoversAllNodes()
        return true
    }

    private var miniNodeLayoutFingerprint: String {
        var parts: [String] = []
        for miniNode in node.locationData?.miniNodes ?? [] {
            let size = canvasNodeSize(miniNode)
            let part = "\(miniNode.id.uuidString):\(miniNode.position.x):\(miniNode.position.y):\(size.width):\(size.height)"
            parts.append(part)
        }
        return parts.joined(separator: "|")
    }

    private func ensurePinnedCanvasCoversAllNodes() {
        for miniNode in node.locationData?.miniNodes ?? [] {
            adjustPinnedCanvasForNode(at: miniNode.position, size: canvasNodeSize(miniNode))
        }
    }

    private func adjustPinnedCanvasForNode(at position: CGPoint, size: CGSize) {
        let requiredWidth = position.x + size.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding
        let requiredHeight = position.y + size.height / 2 + LocationCardLayout.miniCanvasVerticalPadding
        node.locationData?.pinnedMiniCanvasWidth = max(
            node.locationData?.pinnedMiniCanvasWidth ?? 0,
            requiredWidth,
            LocationCardLayout.miniCanvasMinWidth
        )
        node.locationData?.pinnedMiniCanvasHeight = max(
            node.locationData?.pinnedMiniCanvasHeight ?? 0,
            requiredHeight,
            LocationCardLayout.miniCanvasMinHeight
        )
    }

    private func nearestFreeMiniPosition(
        desired: CGPoint,
        itemSize: CGSize,
        existing: [CanvasNode]
    ) -> CGPoint {
        let desiredRect = rectCentered(at: desired, size: itemSize)
        if !intersectsAny(rect: desiredRect, nodes: existing) {
            return desired
        }

        let step: CGFloat = 24
        for radius in 1...80 {
            for gx in -radius...radius {
                for gy in -radius...radius {
                    guard abs(gx) == radius || abs(gy) == radius else { continue }
                    let candidate = CGPoint(
                        x: desired.x + CGFloat(gx) * step,
                        y: desired.y + CGFloat(gy) * step
                    )
                    if !intersectsAny(rect: rectCentered(at: candidate, size: itemSize), nodes: existing) {
                        return candidate
                    }
                }
            }
        }

        return desired
    }

    private func placeMiniNodeWithoutOverlap(
        desired: CGPoint,
        itemSize: CGSize,
        currentCanvasSize: CGSize
    ) -> (position: CGPoint, requiredSize: CGSize) {
        placeNodeWithoutOverlapInMini(
            desired: desired,
            itemSize: itemSize,
            existing: node.locationData?.miniNodes ?? [],
            currentCanvasSize: currentCanvasSize
        )
    }

    private func worldPositionForMiniNode(miniPosition: CGPoint, currentMiniCanvasSize: CGSize) -> CGPoint {
        let cardSize = locationCardSize(node.locationData)
        let cardTopLeft = CGPoint(
            x: node.position.x - cardSize.width / 2,
            y: node.position.y - cardSize.height / 2
        )
        let miniOrigin = CGPoint(
            x: cardTopLeft.x + LocationCardLayout.outerHorizontalPadding,
            y: cardTopLeft.y + LocationCardLayout.outerTopPadding + LocationCardLayout.headerHeight + LocationCardLayout.headerToMiniGap
        )
        return CGPoint(
            x: miniOrigin.x + miniPosition.x,
            y: miniOrigin.y + miniPosition.y
        )
    }
}


private struct ChoicesCanvasCard: View {
    @Binding var data: ChoicesCardData

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray4))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    if data.isCollapsed {
                        HStack {
                            Text("Choices")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.9))
                            Spacer()
                            Button {
                                data.isCollapsed.toggle()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 34, height: 34)
                        }

                        AutoGrowingTextEditor(
                            text: $data.title,
                            minimumHeight: ChoiceCardLayout.titleBaseHeight,
                            baseHeight: ChoiceCardLayout.titleBaseHeight,
                            lineIncrement: ChoiceCardLayout.titleLineIncrement,
                            measureFont: ChoiceCardLayout.titleFont,
                            textFont: .system(size: 24, weight: .regular),
                            measureWidth: ChoiceCardLayout.titleMeasureWidth,
                            textAlignment: .center
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(.systemGray6))
                        )
                    } else {
                        HStack {
                            AutoGrowingTextEditor(
                                text: $data.title,
                                minimumHeight: ChoiceCardLayout.titleBaseHeight,
                                baseHeight: ChoiceCardLayout.titleBaseHeight,
                                lineIncrement: ChoiceCardLayout.titleLineIncrement,
                                measureFont: ChoiceCardLayout.titleFont,
                                textFont: .system(size: 24, weight: .regular),
                                measureWidth: ChoiceCardLayout.titleMeasureWidth,
                                textAlignment: .center
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(.systemGray6))
                            )

                            Button {
                                data.isCollapsed.toggle()
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 34, height: 52)
                        }
                    }

                    if !data.isCollapsed {
                        ForEach($data.options) { $option in
                            ChoiceRowView(option: $option)
                        }

                        Button {
                            addChoice()
                        } label: {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "plus")
                                        .font(.system(size: 34, weight: .regular))
                                        .foregroundStyle(Color.black.opacity(0.82))
                                }
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
    }

    private func addChoice() {
        let nextNumber = data.options.count + 1
        data.options.append(ChoiceOption(label: "\(nextNumber)", description: ""))
    }
}

private enum PropCardLayout {
    static let cardWidth: CGFloat = 430
    static let outerPadding: CGFloat = 14
    static let verticalSpacing: CGFloat = 10
    static let titleBaseHeight: CGFloat = 52
    static let titleLineIncrement: CGFloat = 22
    static let titleFont: UIFont = .systemFont(ofSize: 24, weight: .regular)
    static let titleMeasureWidth: CGFloat = 330

    static let imageHeight: CGFloat = 180
    static let imageInnerHeight: CGFloat = 120

    static let descriptionBaseHeight: CGFloat = 56
    static let descriptionLineIncrement: CGFloat = 22
    static let descriptionFont: UIFont = .systemFont(ofSize: 22, weight: .regular)
    static let descriptionMeasureWidth: CGFloat = 360
}

private struct PropCanvasCard: View {
    @Binding var data: PropCardData
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray4))
            .overlay(alignment: .topLeading) {
                VStack(spacing: PropCardLayout.verticalSpacing) {
                    AutoGrowingTextEditor(
                        text: $data.title,
                        minimumHeight: PropCardLayout.titleBaseHeight,
                        baseHeight: PropCardLayout.titleBaseHeight,
                        lineIncrement: PropCardLayout.titleLineIncrement,
                        measureFont: PropCardLayout.titleFont,
                        textFont: .system(size: 24, weight: .regular),
                        measureWidth: PropCardLayout.titleMeasureWidth,
                        textAlignment: .center
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(alignment: .center) {
                        if data.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Name of the prop")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.65))
                                .allowsHitTesting(false)
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .frame(height: PropCardLayout.imageHeight)
                            .overlay {
                                if let imageData = data.imageData,
                                   let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding(16)
                                } else {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 86, weight: .regular))
                                        .foregroundStyle(Color.black.opacity(0.75))
                                        .frame(height: PropCardLayout.imageInnerHeight)
                                }
                            }
                    }
                    .buttonStyle(.plain)

                    AutoGrowingTextEditor(
                        text: $data.description,
                        minimumHeight: PropCardLayout.descriptionBaseHeight,
                        baseHeight: PropCardLayout.descriptionBaseHeight,
                        lineIncrement: PropCardLayout.descriptionLineIncrement,
                        measureFont: PropCardLayout.descriptionFont,
                        textFont: .system(size: 22, weight: .regular),
                        measureWidth: PropCardLayout.descriptionMeasureWidth,
                        textAlignment: .leading
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(alignment: .leading) {
                        if data.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Description")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.65))
                                .padding(.leading, 16)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(PropCardLayout.outerPadding)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let imageData = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            data.imageData = imageData
                        }
                    }
                }
            }
    }
}

private struct ChoiceRowView: View {
    @Binding var option: ChoiceOption

    var body: some View {
        let lineCount = AlphaLogic.lineCount(
            for: option.description,
            font: ChoiceCardLayout.descriptionFont,
            measureWidth: ChoiceCardLayout.descriptionMeasureWidth
        )
        let descriptionHeight = AlphaLogic.steppedHeight(
            base: ChoiceCardLayout.descriptionBaseHeight,
            increment: ChoiceCardLayout.descriptionLineIncrement,
            lineCount: lineCount
        )

        HStack(alignment: .top, spacing: 10) {
            TextField("", text: $option.label)
                .font(.system(size: 24, weight: .regular))
                .multilineTextAlignment(.center)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                )
                .onChange(of: option.label) { newValue in
                    option.label = sanitizeOneWord(newValue)
                }

            AutoGrowingTextEditor(
                text: $option.description,
                minimumHeight: descriptionHeight,
                baseHeight: ChoiceCardLayout.descriptionBaseHeight,
                lineIncrement: ChoiceCardLayout.descriptionLineIncrement,
                measureFont: ChoiceCardLayout.descriptionFont,
                textFont: .system(size: 22, weight: .regular),
                measureWidth: ChoiceCardLayout.descriptionMeasureWidth,
                textAlignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
            )
        }
    }

    private func sanitizeOneWord(_ value: String) -> String {
        let tokens = value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
        return tokens.first ?? ""
    }
}

private enum ChoiceCardLayout {
    static let cardWidth: CGFloat = 350
    static let titleBaseHeight: CGFloat = 52
    static let titleLineIncrement: CGFloat = 22
    static let descriptionBaseHeight: CGFloat = 56
    static let descriptionLineIncrement: CGFloat = 22
    static let titleFont: UIFont = .systemFont(ofSize: 24, weight: .regular)
    static let descriptionFont: UIFont = .systemFont(ofSize: 22, weight: .regular)
    static let titleMeasureWidth: CGFloat = 250
    static let descriptionMeasureWidth: CGFloat = 180
}

private enum AlphaLogic {
    static func steppedHeight(base: CGFloat, increment: CGFloat, lineCount: Int) -> CGFloat {
        let extraLines = max(0, lineCount - 1)
        return base + (CGFloat(extraLines) * increment)
    }

    static func lineCount(for text: String, font: UIFont, measureWidth: CGFloat) -> Int {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return 1 }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]

        let measured = (value as NSString).boundingRect(
            with: CGSize(width: measureWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let computed = Int(ceil(measured.height / font.lineHeight))
        return max(1, computed)
    }
}

private struct AutoGrowingTextEditor: View {
    @Binding var text: String
    let minimumHeight: CGFloat
    let baseHeight: CGFloat
    let lineIncrement: CGFloat
    let measureFont: UIFont
    let textFont: Font
    let measureWidth: CGFloat
    let textAlignment: TextAlignment
    @State private var dynamicHeight: CGFloat = 56

    var body: some View {
        TextEditor(text: $text)
            .font(textFont)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .multilineTextAlignment(textAlignment)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: max(minimumHeight, dynamicHeight), alignment: .topLeading)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            recalculateHeight(for: proxy.size.width)
                        }
                        .onChange(of: text) { _ in
                            recalculateHeight(for: proxy.size.width)
                        }
                }
            )
    }

    private func recalculateHeight(for width: CGFloat) {
        let usableWidth = max(1, min(width - 24, measureWidth))
        let lineCount = AlphaLogic.lineCount(
            for: text,
            font: measureFont,
            measureWidth: usableWidth
        )
        let contentHeight = AlphaLogic.steppedHeight(
            base: baseHeight,
            increment: lineIncrement,
            lineCount: lineCount
        )
        dynamicHeight = max(minimumHeight, contentHeight)
    }
}

private func canvasNodeSize(_ node: CanvasNode) -> CGSize {
    switch node.type {
    case .location:
        return locationCardSize(node.locationData)
    case .choices:
        return choicesCardSize(node.choicesData)
    case .prop:
        return propCardSize(node.propData)
    case .event:
        return CGSize(width: 132, height: 54)
    }
}

private func locationCardSize(_ data: LocationCardData?) -> CGSize {
    guard let data else {
        return CGSize(width: LocationCardLayout.cardWidth, height: LocationCardLayout.defaultCardHeight)
    }
    let miniSize = miniCanvasSize(for: data)

    let totalHeight = LocationCardLayout.outerTopPadding
        + LocationCardLayout.headerHeight
        + LocationCardLayout.headerToMiniGap
        + miniSize.height
        + LocationCardLayout.outerBottomPadding

    let totalWidth = miniSize.width + (LocationCardLayout.outerHorizontalPadding * 2)
    return CGSize(width: totalWidth, height: totalHeight)
}

private func choicesCardSize(_ data: ChoicesCardData?) -> CGSize {
    guard let data else {
        return CGSize(width: ChoiceCardLayout.cardWidth, height: 200)
    }

    let titleLineCount = AlphaLogic.lineCount(
        for: data.title,
        font: ChoiceCardLayout.titleFont,
        measureWidth: ChoiceCardLayout.titleMeasureWidth
    )
    let titleHeight = AlphaLogic.steppedHeight(
        base: ChoiceCardLayout.titleBaseHeight,
        increment: ChoiceCardLayout.titleLineIncrement,
        lineCount: titleLineCount
    )

    if data.isCollapsed {
        return CGSize(width: ChoiceCardLayout.cardWidth, height: 24 + 34 + 8 + titleHeight)
    }

    let baseHeight: CGFloat = 12 + titleHeight + 10
    let rowSpacing: CGFloat = 10
    let plusSectionHeight: CGFloat = 56 + 10
    let bottomPadding: CGFloat = 12

    let rowsHeight = data.options.reduce(CGFloat(0)) { partial, option in
        let lineCount = AlphaLogic.lineCount(
            for: option.description,
            font: ChoiceCardLayout.descriptionFont,
            measureWidth: ChoiceCardLayout.descriptionMeasureWidth
        )
        let rowHeight = AlphaLogic.steppedHeight(
            base: ChoiceCardLayout.descriptionBaseHeight,
            increment: ChoiceCardLayout.descriptionLineIncrement,
            lineCount: lineCount
        )
        return partial + rowHeight
    }

    let totalRowSpacing = CGFloat(max(data.options.count - 1, 0)) * rowSpacing
    let totalHeight = baseHeight + rowsHeight + totalRowSpacing + plusSectionHeight + bottomPadding

    return CGSize(width: ChoiceCardLayout.cardWidth, height: max(200, totalHeight))
}

private func propCardSize(_ data: PropCardData?) -> CGSize {
    guard let data else {
        return CGSize(width: PropCardLayout.cardWidth, height: 330)
    }

    let titleLines = AlphaLogic.lineCount(
        for: data.title,
        font: PropCardLayout.titleFont,
        measureWidth: PropCardLayout.titleMeasureWidth
    )
    let titleHeight = AlphaLogic.steppedHeight(
        base: PropCardLayout.titleBaseHeight,
        increment: PropCardLayout.titleLineIncrement,
        lineCount: titleLines
    )

    let descriptionLines = AlphaLogic.lineCount(
        for: data.description,
        font: PropCardLayout.descriptionFont,
        measureWidth: PropCardLayout.descriptionMeasureWidth
    )
    let descriptionHeight = AlphaLogic.steppedHeight(
        base: PropCardLayout.descriptionBaseHeight,
        increment: PropCardLayout.descriptionLineIncrement,
        lineCount: descriptionLines
    )

    let totalHeight = (PropCardLayout.outerPadding * 2)
        + titleHeight
        + PropCardLayout.verticalSpacing
        + PropCardLayout.imageHeight
        + PropCardLayout.verticalSpacing
        + descriptionHeight

    return CGSize(width: PropCardLayout.cardWidth, height: max(330, totalHeight))
}

private func rectCentered(at center: CGPoint, size: CGSize) -> CGRect {
    CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: size.width,
        height: size.height
    )
}

private func intersectsAny(rect: CGRect, nodes: [CanvasNode]) -> Bool {
    nodes.contains { node in
        let other = rectCentered(at: node.position, size: canvasNodeSize(node)).insetBy(dx: -4, dy: -4)
        return rect.intersects(other)
    }
}

private func miniCanvasSize(for data: LocationCardData) -> CGSize {
    let contentBottom = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
        let size = canvasNodeSize(miniNode)
        return max(currentMax, miniNode.position.y + size.height / 2 + LocationCardLayout.miniCanvasVerticalPadding)
    }
    let contentRight = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
        let size = canvasNodeSize(miniNode)
        return max(currentMax, miniNode.position.x + size.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding)
    }

    let projectedHeight = data.isMiniCanvasTargeted
        ? contentBottom + LocationCardLayout.hoverExpansionHeight
        : contentBottom
    let projectedWidth = data.isMiniCanvasTargeted
        ? contentRight + LocationCardLayout.hoverExpansionWidth
        : contentRight

    let width = max(
        LocationCardLayout.miniCanvasMinWidth,
        data.pinnedMiniCanvasWidth,
        projectedWidth
    )
    let height = max(
        LocationCardLayout.miniCanvasMinHeight,
        data.pinnedMiniCanvasHeight,
        projectedHeight
    )
    return CGSize(width: width, height: height)
}

private func placeNodeWithoutOverlapInMini(
    desired: CGPoint,
    itemSize: CGSize,
    existing: [CanvasNode],
    currentCanvasSize: CGSize
) -> (position: CGPoint, requiredSize: CGSize) {
    var width = max(
        currentCanvasSize.width,
        itemSize.width + (LocationCardLayout.miniCanvasHorizontalPadding * 2)
    )
    var height = max(
        currentCanvasSize.height,
        itemSize.height + (LocationCardLayout.miniCanvasVerticalPadding * 2)
    )

    func clampToBounds(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(
                max(point.x, itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding),
                width - itemSize.width / 2 - LocationCardLayout.miniCanvasHorizontalPadding
            ),
            y: min(
                max(point.y, itemSize.height / 2 + LocationCardLayout.miniCanvasVerticalPadding),
                height - itemSize.height / 2 - LocationCardLayout.miniCanvasVerticalPadding
            )
        )
    }

    var candidate = clampToBounds(desired)
    let stepX = itemSize.width + 18
    let stepY = itemSize.height + 18

    for _ in 0..<500 {
        let rect = rectCentered(at: candidate, size: itemSize)
        let overlaps = existing.contains { node in
            let other = rectCentered(at: node.position, size: canvasNodeSize(node)).insetBy(dx: -4, dy: -4)
            return rect.intersects(other)
        }
        if !overlaps {
            return (candidate, CGSize(width: width, height: height))
        }

        candidate.x += stepX
        if candidate.x > width - itemSize.width / 2 - LocationCardLayout.miniCanvasHorizontalPadding {
            candidate.x = itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding
            candidate.y += stepY
        }
        if candidate.y > height - itemSize.height / 2 - LocationCardLayout.miniCanvasVerticalPadding {
            width += max(stepX, 120)
            height += max(stepY, 90)
            candidate = CGPoint(
                x: itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding,
                y: itemSize.height / 2 + LocationCardLayout.miniCanvasVerticalPadding
            )
        }
        candidate = clampToBounds(candidate)
    }

    return (candidate, CGSize(width: width, height: height))
}

struct CanvasNodeContainer: View {
    @Binding var node: CanvasNode
    let isSelected: Bool
    let zoomScale: CGFloat
    let worldToViewport: (CGPoint) -> CGPoint
    let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void
    let onDelete: () -> Void
    
     var body: some View {
         CanvasNodeView(node: $node, onMoveMiniNodeToMain: onMoveMiniNodeToMain)
             .frame(width: canvasNodeSize(node).width, height: canvasNodeSize(node).height)
             .overlay(alignment: .topTrailing) {
                if isSelected {
                    deleteBadge(action: onDelete).offset(x: 12, y: -12)
                }
            }
    }
    
    @ViewBuilder
    private func deleteBadge(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.red)
                .frame(width: 30, height: 30)
                .overlay { Image(systemName: "minus").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }
        }
    }
}
