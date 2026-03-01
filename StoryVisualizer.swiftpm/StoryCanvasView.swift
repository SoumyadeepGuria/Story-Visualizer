import SwiftUI
import UIKit
import PhotosUI

enum ConnectionSide {
    case top, bottom, left, right
}

struct OrthogonalPathFinder {
    static func findPath(from: CGPoint, to: CGPoint, fromSide: ConnectionSide, toSide: ConnectionSide, obstacles: [CGRect], padding: CGFloat = 25) -> [CGPoint] {
        // Exit vector to make the path start straight from the button
        let exitOffset: CGFloat = 20
        let firstStep: CGPoint
        switch fromSide {
        case .top: firstStep = CGPoint(x: from.x, y: from.y - exitOffset)
        case .bottom: firstStep = CGPoint(x: from.x, y: from.y + exitOffset)
        case .left: firstStep = CGPoint(x: from.x - exitOffset, y: from.y)
        case .right: firstStep = CGPoint(x: from.x + exitOffset, y: from.y)
        }
        
        // Entry vector to make the path enter straight into the target
        let entryOffset: CGFloat = 20
        let lastStep: CGPoint
        switch toSide {
        case .top: lastStep = CGPoint(x: to.x, y: to.y - entryOffset)
        case .bottom: lastStep = CGPoint(x: to.x, y: to.y + entryOffset)
        case .left: lastStep = CGPoint(x: to.x - entryOffset, y: to.y)
        case .right: lastStep = CGPoint(x: to.x + entryOffset, y: to.y)
        }

        // Try a simple 3-segment path from firstStep to lastStep
        var midPoints: [CGPoint]
        if fromSide == .top || fromSide == .bottom {
            midPoints = [CGPoint(x: firstStep.x, y: lastStep.y)]
        } else {
            midPoints = [CGPoint(x: lastStep.x, y: firstStep.y)]
        }
        
        let candidatePath = [from, firstStep] + midPoints + [lastStep, to]
        
        var hasCollision = false
        for i in 0..<candidatePath.count-1 {
            if let _ = firstObstacleIntersecting(p1: candidatePath[i], p2: candidatePath[i+1], obstacles: obstacles) {
                hasCollision = true
                break
            }
        }
        
        if !hasCollision { return candidatePath }
        
        // If simple path fails, use grid-based BFS from firstStep to lastStep
        let gridPath = findGridPath(from: firstStep, to: lastStep, fromSide: fromSide, toSide: toSide, obstacles: obstacles, padding: padding)
        return [from] + gridPath + [to]
    }
    
    private static func firstObstacleIntersecting(p1: CGPoint, p2: CGPoint, obstacles: [CGRect]) -> CGRect? {
        let segmentRect = CGRect(
            x: min(p1.x, p2.x) - 1,
            y: min(p1.y, p2.y) - 1,
            width: abs(p1.x - p2.x) + 2,
            height: abs(p1.y - p2.y) + 2
        )
        return obstacles.first { $0.intersects(segmentRect) }
    }
    
    private static func findGridPath(from: CGPoint, to: CGPoint, fromSide: ConnectionSide, toSide: ConnectionSide, obstacles: [CGRect], padding: CGFloat) -> [CGPoint] {
        var xCoords = Set<CGFloat>([from.x, to.x])
        var yCoords = Set<CGFloat>([from.y, to.y])
        for obs in obstacles {
            xCoords.insert(obs.minX - padding)
            xCoords.insert(obs.maxX + padding)
            yCoords.insert(obs.minY - padding)
            yCoords.insert(obs.maxY + padding)
        }
        let sortedX = xCoords.sorted()
        let sortedY = yCoords.sorted()
        
        struct Node: Hashable {
            let x: CGFloat
            let y: CGFloat
        }
        
        let startNode = Node(x: from.x, y: from.y)
        let targetNode = Node(x: to.x, y: to.y)
        var queue = [startNode]
        var cameFrom: [Node: Node] = [:]
        var visited = Set([startNode])
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == targetNode { break }
            guard let ix = sortedX.firstIndex(of: current.x), let iy = sortedY.firstIndex(of: current.y) else { continue }
            
            let neighbors = [
                (ix > 0) ? Node(x: sortedX[ix-1], y: current.y) : nil,
                (ix < sortedX.count - 1) ? Node(x: sortedX[ix+1], y: current.y) : nil,
                (iy > 0) ? Node(x: current.x, y: sortedY[iy-1]) : nil,
                (iy < sortedY.count - 1) ? Node(x: current.x, y: sortedY[iy+1]) : nil
            ].compactMap { $0 }
            
            for neighbor in neighbors {
                if !visited.contains(neighbor) {
                    // Force perpendicular entry check if needed
                    if neighbor == targetNode {
                        let isHorizontal = abs(current.x - neighbor.x) > 0.1
                        let isVertical = abs(current.y - neighbor.y) > 0.1
                        if (toSide == .left || toSide == .right) && isVertical { continue }
                        if (toSide == .top || toSide == .bottom) && isHorizontal { continue }
                    }
                    
                    if firstObstacleIntersecting(p1: CGPoint(x: current.x, y: current.y), p2: CGPoint(x: neighbor.x, y: neighbor.y), obstacles: obstacles) == nil {
                        visited.insert(neighbor)
                        cameFrom[neighbor] = current
                        queue.append(neighbor)
                    }
                }
            }
        }
        var path: [CGPoint] = []
        var curr: Node? = targetNode
        while curr != nil {
            path.append(CGPoint(x: curr!.x, y: curr!.y))
            curr = cameFrom[curr!]
        }
        return path.isEmpty ? [from, to] : path.reversed()
    }
}

struct ConnectionID: Equatable {
    let sourceID: UUID
    let choiceID: UUID?
    let targetID: UUID
}

struct ConnectionSource: Equatable {
    let nodeID: UUID
    let choiceID: UUID?
}

struct StoryCanvasView: View {
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss
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
    @State private var isShowingActDeletionAlert = false
    @State private var isCharacterMenuExpanded = false
    @State private var isShowingCharacterCreator = false
    @State private var newCharacter = StoryCharacter(name: "", avatar: .man)
    @State private var isStopSignSelected = true
    @State private var selectedConnectionID: ConnectionID? = nil
    @State private var sourceConnection: ConnectionSource? = nil

    private var currentActID: UUID? { project.currentActID }

    private func deleteCurrentAct() {
        guard let actID = project.currentActID, let index = project.acts.firstIndex(where: { $0.id == actID }) else { return }
        project.acts.remove(at: index)
        if project.acts.isEmpty { dismiss() }
        else {
            let nextIndex = max(0, index - 1)
            project.currentActID = project.acts[nextIndex].id
        }
    }

    private func ensureAtLeastOneAct() {
        if project.acts.isEmpty {
            let firstAct = Act(name: "Act 1")
            project.acts.append(firstAct)
            project.currentActID = firstAct.id
        }
    }

    private var currentActIndex: Int { project.acts.firstIndex(where: { $0.id == project.currentActID }) ?? 0 }
    
    private var currentConnectionColor: ColorData? {
        if isStopSignSelected { return nil }
        return project.characters.first?.connectionColor
    }
    
    private var isAnyEditModeActive: Bool {
        guard !project.acts.isEmpty else { return false }
        let idx = currentActIndex
        guard idx < project.acts.count else { return false }
        return selectedMainNodeID != nil || project.acts[idx].canvasNodes.contains { node in node.locationData?.isMiniEditing == true }
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

                    MainCanvasNodeLoop(
                        project: $project,
                        selectedMainNodeID: $selectedMainNodeID,
                        sourceConnection: $sourceConnection,
                        selectedConnectionID: $selectedConnectionID,
                        movingMainNodeID: $movingMainNodeID,
                        movingMainStartPosition: $movingMainStartPosition,
                        resizingLocationNodeID: $resizingLocationNodeID,
                        zoomScale: zoomScale,
                        worldToViewport: worldToViewport,
                        isAnyMiniCanvasInEditMode: isAnyMiniCanvasInEditMode,
                        clearMiniEditModes: clearMiniEditModes,
                        moveMiniNodeToMain: moveMiniNodeToMain,
                        onDeleteNode: { nodeID in pendingMainDeletion = PendingMainDeletion(nodeID: nodeID) },
                        miniCanvasWorldFrame: miniCanvasWorldFrame,
                        moveMainNodeIntoMiniCanvasIfNeeded: moveMainNodeIntoMiniCanvasIfNeeded,
                        nearestFreeWorldPosition: nearestFreeWorldPosition,
                        locationResizeHandle: { node in AnyView(locationResizeHandle(node)) },
                        isStopSignSelected: isStopSignSelected
                    )

                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Spacer()
                            Button { isShowingActDeletionAlert = true } label: {
                                Circle().fill(Color.white.opacity(0.95)).frame(width: 52, height: 52)
                                    .overlay { Image(systemName: "trash").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.red.opacity(0.8)) }
                                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .alert("Delete Act", isPresented: $isShowingActDeletionAlert) {
                                Button("Delete", role: .destructive) { deleteCurrentAct() }
                                Button("Cancel", role: .cancel) {}
                            } message: { Text("Are you sure you want to delete the current canvas? This action cannot be undone.") }

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    cameraOffset = .zero
                                    panStartOffset = nil
                                    zoomScale = CanvasCamera.initialZoomScale
                                    zoomStartScale = nil
                                }
                            } label: {
                                Circle().fill(Color.white.opacity(0.95)).frame(width: 52, height: 52)
                                    .overlay { Image(systemName: "scope").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.black.opacity(0.8)) }
                                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.trailing, 16).padding(.bottom, 16)
                    }
                    characterSideBar
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .onAppear {
                    ensureAtLeastOneAct()
                    viewportSize = viewport.size
                    zoomScale = CanvasCamera.initialZoomScale
                }
                .onChange(of: viewport.size) { newSize in viewportSize = newSize }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            guard selectedMainNodeID == nil else { return }
                            guard !isAnyMiniCanvasInEditMode() else { return }
                            if panStartOffset == nil { panStartOffset = cameraOffset }
                            guard let start = panStartOffset else { return }
                            cameraOffset = CGSize(width: start.width - (value.translation.width / zoomScale), height: start.height - (value.translation.height / zoomScale))
                        }
                        .onEnded { _ in panStartOffset = nil }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if zoomStartScale == nil { zoomStartScale = zoomScale }
                            guard let start = zoomStartScale else { return }
                            zoomScale = min(max(start * value, 0.01), 2.8)
                        }
                        .onEnded { _ in zoomStartScale = nil }
                )
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let worldPoint = viewportToWorld(value.location)
                            if selectedMainNodeID != nil {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedMainNodeID = nil }
                                movingMainNodeID = nil
                                resizingLocationNodeID = nil
                            }
                            selectedConnectionID = nil
                            clearMiniEditModes()
                            collapseChoicesCardsIfNeeded(at: worldPoint)
                        }
                )
                .dropDestination(for: String.self) { items, location in handleMainDrop(items: items, at: viewportToWorld(location)) }
                isTargeted: { targeted in isTargeted = targeted }
            }
        }
        .padding(16).background(Color(.systemGray5))
        .navigationTitle("\(project.name) Canvas").navigationBarTitleDisplayMode(.inline)
        .alert(item: $pendingMainDeletion) { pending in
            Alert(title: Text("Delete Box"), message: Text("This will delete the item and all its contents."),
                  primaryButton: .destructive(Text("Delete")) {
                    let actIdx = currentActIndex
                    project.acts[actIdx].canvasNodes.removeAll { $0.id == pending.nodeID }
                    if selectedMainNodeID == pending.nodeID { selectedMainNodeID = nil }
                  },
                  secondaryButton: .cancel(Text("Cancel")))
        }
    }

    private var topRibbon: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CanvasNodeType.toolbarOrder) { type in
                        ToolbarDraggableBox(type: type).draggable(type.rawValue)
                    }
                }.padding(10)
            }.background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray4).opacity(0.45)))
            actSelectorDropdown
        }
        .allowsHitTesting(!isAnyEditModeActive).disabled(isAnyEditModeActive).opacity(isAnyEditModeActive ? 0.55 : 1)
    }

    private var characterSideBar: some View {
        VStack(spacing: 12) {
            // Stop sign button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isStopSignSelected = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "nosign")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .overlay {
                        if isStopSignSelected {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 3)
                        }
                    }
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if let firstChar = project.characters.first {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isStopSignSelected = false
                    }
                } label: {
                    CharacterSidebarItem(character: firstChar)
                        .overlay {
                            if !isStopSignSelected {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .draggable(firstChar.id) { CharacterSidebarItem(character: firstChar) }
            }
            
            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isCharacterMenuExpanded.toggle() } } label: {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95)).frame(width: 56, height: 56)
                    .overlay { Image(systemName: "chevron.down").font(.system(size: 18, weight: .bold)).rotationEffect(.degrees(isCharacterMenuExpanded ? 180 : 0)) }
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
            }.buttonStyle(.plain)
            
            if isCharacterMenuExpanded {
                let otherChars = Array(project.characters.dropFirst())
                VStack(spacing: 12) {
                    ForEach(otherChars) { char in
                        Button { selectCharacter(char) } label: {
                            CharacterSidebarItem(character: char).draggable(char.id) { CharacterSidebarItem(character: char) }
                        }.buttonStyle(.plain)
                    }
                    plusSidebarButton
                }.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.8))))
            }
        }.padding(.leading, 16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .fullScreenCover(isPresented: $isShowingCharacterCreator) {
            CharacterEditView(character: $newCharacter) {
                let index = project.characters.count
                let r = 10.0 + Double(index) * 10.0
                let g = 28.0 + Double(index) * 10.0
                let b = 128.0 + Double(index) * 10.0
                newCharacter.assignedColor = ColorData(r: r, g: g, b: b)
                project.characters.append(newCharacter)
            }
        }
    }

    private func selectCharacter(_ character: StoryCharacter) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            if let index = project.characters.firstIndex(where: { $0.id == character.id }) {
                let char = project.characters.remove(at: index)
                project.characters.insert(char, at: 0)
            }
            isCharacterMenuExpanded = false
            isStopSignSelected = false
        }
    }

    private var plusSidebarButton: some View {
        Button {
            let nextNum = project.characters.count + 1
            newCharacter = StoryCharacter(name: "Character \(nextNum)", avatar: .man)
            isShowingCharacterCreator = true
        } label: {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.95)).frame(width: 56, height: 56)
                .overlay { Image(systemName: "plus").font(.system(size: 20, weight: .bold)) }
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        }.buttonStyle(.plain)
    }

    private var actSelectorDropdown: some View {
        Menu {
            ForEach(project.acts) { act in
                Button { withAnimation { project.currentActID = act.id } } label: {
                    HStack {
                        Text(act.name)
                        if project.currentActID == act.id { Image(systemName: "checkmark") }
                    }
                }
            }
            Divider()
            Button {
                let newActNumber = project.acts.count + 1
                let newAct = Act(name: "Act \(newActNumber)")
                project.acts.append(newAct)
                project.currentActID = newAct.id
            } label: { Label("Add Act", systemImage: "plus") }
        } label: {
            HStack(spacing: 8) {
                Text(project.acts.first(where: { $0.id == project.currentActID })?.name ?? "Act 1").font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
            }.padding(.horizontal, 16).frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray4).opacity(0.45)))
            .foregroundStyle(.black.opacity(0.72))
        }
    }

    private func handleMainDrop(items: [String], at location: CGPoint) -> Bool {
        guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else { return false }
        var node = defaultNode(for: type)
        let actIdx = currentActIndex
        node.position = nearestFreeWorldPosition(location, canvasNodeSize(node, project: project), project.acts[actIdx].canvasNodes)
        project.acts[actIdx].canvasNodes.append(node)
        return true
    }

    private func collapseChoicesCardsIfNeeded(at point: CGPoint) {
        guard sourceConnection == nil else { return } // Don't collapse if making connection
        
        let actIdx = currentActIndex
        let tappedInsideChoicesCard = project.acts[actIdx].canvasNodes.contains { node in
            guard node.type == .choices else { return false }
            let nodeSize = canvasNodeSize(node, project: project)
            let frame = CGRect(x: node.position.x - nodeSize.width / 2, y: node.position.y - nodeSize.height / 2, width: nodeSize.width, height: nodeSize.height)
            return frame.contains(point)
        }
        guard !tappedInsideChoicesCard else { return }
        for index in project.acts[actIdx].canvasNodes.indices {
            guard project.acts[actIdx].canvasNodes[index].type == .choices else { continue }
            project.acts[actIdx].canvasNodes[index].choicesData?.isCollapsed = true
        }
    }
    
     private func clearMiniEditModes() {
         let actIdx = currentActIndex
         for index in project.acts[actIdx].canvasNodes.indices {
             guard project.acts[actIdx].canvasNodes[index].type == .location, var locationData = project.acts[actIdx].canvasNodes[index].locationData else { continue }
             locationData.isMiniEditing = false
             locationData.selectedMiniNodeID = nil
             project.acts[actIdx].canvasNodes[index].locationData = locationData
         }
     }
     
     private func isAnyMiniCanvasInEditMode() -> Bool {
         let actIdx = currentActIndex
         return project.acts[actIdx].canvasNodes.contains { node in node.type == .location && node.locationData?.isMiniEditing == true }
     }

    private func worldToViewport(_ point: CGPoint) -> CGPoint {
        CGPoint(x: ((point.x - cameraOffset.width) * zoomScale) + viewportSize.width / 2, y: ((point.y - cameraOffset.height) * zoomScale) + viewportSize.height / 2)
    }

    private func viewportToWorld(_ point: CGPoint) -> CGPoint {
        CGPoint(x: ((point.x - viewportSize.width / 2) / zoomScale) + cameraOffset.width, y: ((point.y - viewportSize.height / 2) / zoomScale) + cameraOffset.height)
    }

    private func nearestFreeWorldPosition(_ desired: CGPoint, _ itemSize: CGSize, _ existing: [CanvasNode]) -> CGPoint {
        let baseRect = rectCentered(at: desired, size: itemSize)
        if !intersectsAny(rect: baseRect, nodes: existing, project: project) { return desired }
        let step: CGFloat = 36
        for radius in 1...120 {
            for gx in -radius...radius {
                for gy in -radius...radius {
                    guard abs(gx) == radius || abs(gy) == radius else { continue }
                    let candidate = CGPoint(x: desired.x + CGFloat(gx) * step, y: desired.y + CGFloat(gy) * step)
                    if !intersectsAny(rect: rectCentered(at: candidate, size: itemSize), nodes: existing, project: project) { return candidate }
                }
            }
        }
        return CGPoint(x: desired.x + 240, y: desired.y + 240)
    }

    @ViewBuilder
    private func locationResizeHandle(_ node: Binding<CanvasNode>) -> some View {
        Circle().fill(Color.blue).frame(width: 24, height: 24).overlay { Circle().stroke(Color.white, lineWidth: 2) }.shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard node.wrappedValue.type == .location else { return }
                        if resizingLocationNodeID != node.wrappedValue.id {
                            resizingLocationNodeID = node.wrappedValue.id
                            let startData = node.wrappedValue.locationData ?? .defaultData
                            resizeStartMiniSize = CGSize(width: startData.pinnedMiniCanvasWidth, height: startData.pinnedMiniCanvasHeight)
                        }
                        guard var locationData = node.wrappedValue.locationData else { return }
                        let minWidth = minimumMiniCanvasWidth(for: locationData)
                        let minHeight = minimumMiniCanvasHeight(for: locationData)
                        locationData.pinnedMiniCanvasWidth = max(minWidth, resizeStartMiniSize.width + (value.translation.width / zoomScale))
                        locationData.pinnedMiniCanvasHeight = max(minHeight, resizeStartMiniSize.height + (value.translation.height / zoomScale))
                        node.wrappedValue.locationData = locationData
                    }
                    .onEnded { _ in resizingLocationNodeID = nil }
            )
    }

    private func minimumMiniCanvasWidth(for data: LocationCardData) -> CGFloat {
        let contentRequired = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
            let size = canvasNodeSize(miniNode, project: project)
            return max(currentMax, miniNode.position.x + size.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding)
        }
        return max(LocationCardLayout.miniCanvasMinWidth, contentRequired)
    }

    private func minimumMiniCanvasHeight(for data: LocationCardData) -> CGFloat {
        let contentRequired = data.miniNodes.reduce(CGFloat(0)) { currentMax, miniNode in
            let size = canvasNodeSize(miniNode, project: project)
            return max(currentMax, miniNode.position.y + size.height / 2 + LocationCardLayout.miniCanvasVerticalPadding)
        }
        return max(LocationCardLayout.miniCanvasMinHeight, contentRequired)
    }

     private func moveMainNodeIntoMiniCanvasIfNeeded(_ nodeID: UUID) -> Bool {
         let actIdx = currentActIndex
         guard let movingIndex = project.acts[actIdx].canvasNodes.firstIndex(where: { $0.id == nodeID }) else { return false }
         let node = project.acts[actIdx].canvasNodes[movingIndex]
         guard let targetLocationID = findTargetLocationID(forWorldPoint: node.position, excluding: node.id),
               let targetLocationNode = project.acts[actIdx].canvasNodes.first(where: { $0.id == targetLocationID }),
               let miniFrame = miniCanvasWorldFrame(targetLocationNode),
               let targetLocationIndex = project.acts[actIdx].canvasNodes.firstIndex(where: { $0.id == targetLocationID }),
               var targetLocationData = project.acts[actIdx].canvasNodes[targetLocationIndex].locationData else { return false }

         let localDesired = CGPoint(x: node.position.x - miniFrame.minX, y: node.position.y - miniFrame.minY)
         let currentMiniSize = miniCanvasSize(for: targetLocationData, project: project)
         let placement = placeNodeWithoutOverlapInMini(localDesired, canvasNodeSize(node, project: project), targetLocationData.miniNodes, currentMiniSize, project)

         var movedNode = node
         movedNode.position = placement.position
         targetLocationData.pinnedMiniCanvasWidth = max(targetLocationData.pinnedMiniCanvasWidth, placement.requiredSize.width)
         targetLocationData.pinnedMiniCanvasHeight = max(targetLocationData.pinnedMiniCanvasHeight, placement.requiredSize.height)
         targetLocationData.miniNodes.append(movedNode)
         targetLocationData.isMiniEditing = false
         targetLocationData.selectedMiniNodeID = nil
         project.acts[actIdx].canvasNodes[targetLocationIndex].locationData = targetLocationData
         project.acts[actIdx].canvasNodes.remove(at: movingIndex)
         selectedMainNodeID = nil
         return true
     }

    private func moveMiniNodeToMain(from sourceLocationID: UUID, miniNode: CanvasNode, desiredWorldPosition: CGPoint) {
        let actIdx = currentActIndex
        guard let sourceLocationIndex = project.acts[actIdx].canvasNodes.firstIndex(where: { $0.id == sourceLocationID }),
              var sourceLocationData = project.acts[actIdx].canvasNodes[sourceLocationIndex].locationData else { return }
        sourceLocationData.miniNodes.removeAll { $0.id == miniNode.id }
        sourceLocationData.selectedMiniNodeID = nil
        sourceLocationData.isMiniEditing = false
        project.acts[actIdx].canvasNodes[sourceLocationIndex].locationData = sourceLocationData
        var movedNode = miniNode
        movedNode.position = nearestFreeWorldPosition(desiredWorldPosition, canvasNodeSize(movedNode, project: project), project.acts[actIdx].canvasNodes)
        project.acts[actIdx].canvasNodes.append(movedNode)
        selectedMainNodeID = movedNode.id
    }

    private func findTargetLocationID(forWorldPoint point: CGPoint, excluding nodeID: UUID) -> UUID? {
        let actIdx = currentActIndex
        for node in project.acts[actIdx].canvasNodes.reversed() {
            guard node.id != nodeID, node.type == .location, let frame = miniCanvasWorldFrame(node) else { continue }
            if frame.contains(point) { return node.id }
        }
        return nil
    }

    private func miniCanvasWorldFrame(_ locationNode: CanvasNode) -> CGRect? {
        guard locationNode.type == .location, let data = locationNode.locationData else { return nil }
        let cardSize = locationCardSize(data)
        let miniSize = miniCanvasSize(for: data, project: project)
        let cardTopLeft = CGPoint(x: locationNode.position.x - cardSize.width / 2, y: locationNode.position.y - cardSize.height / 2)
        let miniOrigin = CGPoint(x: cardTopLeft.x + LocationCardLayout.outerHorizontalPadding, y: cardTopLeft.y + LocationCardLayout.outerTopPadding + LocationCardLayout.headerHeight + LocationCardLayout.headerToMiniGap)
        return CGRect(origin: miniOrigin, size: miniSize)
    }
}

private struct PendingMainDeletion: Identifiable {
    let id = UUID()
    let nodeID: UUID
}

private enum CanvasCamera { static let initialZoomScale: CGFloat = 1.0 }

private struct ToolbarDraggableBox: View {
    let type: CanvasNodeType
    var body: some View {
        RoundedRectangle(cornerRadius: 9).fill(type.fillColor).overlay { RoundedRectangle(cornerRadius: 9).stroke(type.borderColor, lineWidth: 2) }
            .frame(width: type == .location ? 100 : 90, height: 44)
            .overlay { Text(type.title).font(.subheadline.weight(.semibold)).foregroundStyle(.black.opacity(0.72)) }
    }
}

private struct CanvasNodeView: View {
    @Binding var node: CanvasNode
    @Binding var project: Project
    @Binding var sourceConnection: ConnectionSource?
    let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void
    let isStopSignSelected: Bool
    var body: some View {
        switch node.type {
        case .location: LocationCanvasCard(node: $node, project: $project, sourceConnection: $sourceConnection, onMoveMiniNodeToMain: onMoveMiniNodeToMain, isStopSignSelected: isStopSignSelected)
        case .choices: ChoicesCanvasCard(nodeID: node.id, data: Binding(get: { node.choicesData ?? .defaultData }, set: { node.choicesData = $0 }), project: $project, sourceConnection: $sourceConnection)
        case .prop: PropCanvasCard(data: Binding(get: { node.propData ?? .defaultData }, set: { node.propData = $0 }))
        case .event: EventCanvasCard(data: Binding(get: { node.eventData ?? .defaultData }, set: { node.eventData = $0 }), project: $project)
        }
    }
}

private func defaultNode(for type: CanvasNodeType) -> CanvasNode {
    CanvasNode(type: type, position: .zero, choicesData: type == .choices ? .defaultData : nil, locationData: type == .location ? .defaultData : nil, propData: type == .prop ? .defaultData : nil, eventData: type == .event ? .defaultData : nil)
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
    @Binding var project: Project
    @Binding var sourceConnection: ConnectionSource?
    let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void
    let isStopSignSelected: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var movingMiniNodeID: UUID?
    @State private var movingMiniStartPosition: CGPoint = .zero
    @State private var pendingMiniDeletionNodeID: UUID?
    @State private var isShowingMiniDeleteDialog = false
    private var data: Binding<LocationCardData> { Binding(get: { node.locationData ?? .defaultData }, set: { node.locationData = $0 }) }
    
    private var currentConnectionColor: ColorData? {
        if isStopSignSelected { return nil }
        return project.characters.first?.connectionColor
    }
    
    var body: some View {
        baseCardView.overlay(alignment: .topLeading) { cardContentView }
            .confirmationDialog("Delete Box", isPresented: $isShowingMiniDeleteDialog, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    guard let targetID = pendingMiniDeletionNodeID else { return }
                    node.locationData?.miniNodes.removeAll { $0.id == targetID }
                    if node.locationData?.selectedMiniNodeID == targetID { node.locationData?.selectedMiniNodeID = nil }
                    pendingMiniDeletionNodeID = nil
                }
                Button("Cancel", role: .cancel) { pendingMiniDeletionNodeID = nil }
            } message: { Text("This will delete the item and all its contents.") }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task { if let imageData = try? await newItem.loadTransferable(type: Data.self) { await MainActor.run { node.locationData?.backgroundImageData = imageData } } }
            }
    }
    private var baseCardView: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray4))
            .overlay {
                if let imageData = node.locationData?.backgroundImageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                    RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.42)).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }.clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var cardContentView: some View { VStack(spacing: LocationCardLayout.headerToMiniGap) { headerView; miniCanvasView }.padding(10) }
    private var headerView: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Circle().fill(Color(.systemGray6)).frame(width: LocationCardLayout.headerIconSize, height: LocationCardLayout.headerIconSize)
                    .overlay { Image(systemName: "photo.badge.plus").font(.system(size: 30, weight: .regular)).foregroundStyle(Color.black.opacity(0.82)) }
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }.buttonStyle(.plain)
            TextField("Name of location", text: data.title).font(.system(size: 24, weight: .regular)).padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: LocationCardLayout.headerHeight)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
        }
    }
    private var miniCanvasView: some View {
        let currentMiniSize = miniCanvasSize(for: node.locationData ?? .defaultData, project: project)
        return GeometryReader { proxy in
            ZStack { 
                canvasBackground
                renderMiniConnections(proxySize: currentMiniSize)
                miniNodesContent(proxySize: currentMiniSize) 
            }
                .onAppear { ensurePinnedCanvasCoversAllNodes() }
                .onChange(of: miniNodeLayoutFingerprint) { _ in ensurePinnedCanvasCoversAllNodes() }
                .onChange(of: proxy.size) { _ in ensurePinnedCanvasCoversAllNodes() }
                .contentShape(Rectangle())
                .dropDestination(for: String.self) { items, location in handleDropOnMiniCanvas(items: items, location: location, proxySize: proxy.size) }
                isTargeted: { targeted in
                    node.locationData?.isMiniCanvasTargeted = targeted
                    if targeted {
                        node.locationData?.pinnedMiniCanvasWidth = max(node.locationData?.pinnedMiniCanvasWidth ?? 0, proxy.size.width)
                        node.locationData?.pinnedMiniCanvasHeight = max(node.locationData?.pinnedMiniCanvasHeight ?? 0, proxy.size.height)
                    }
                }
        }.frame(height: currentMiniSize.height).frame(maxWidth: .infinity)
    }
    private var canvasBackground: some View { RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.56)).overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.25), lineWidth: 1) } }
    private func miniNodesContent(proxySize: CGSize) -> some View { ForEach(data.miniNodes) { $miniNode in miniNodeItemView(miniNode: $miniNode, proxySize: proxySize) } }
    private func miniNodeItemView(miniNode: Binding<CanvasNode>, proxySize: CGSize) -> some View {
         CanvasNodeContainer(node: miniNode, project: $project, sourceConnection: $sourceConnection, isSelected: data.wrappedValue.selectedMiniNodeID == miniNode.id, zoomScale: 1.0, worldToViewport: { $0 }, onMoveMiniNodeToMain: onMoveMiniNodeToMain, onDelete: {
             pendingMiniDeletionNodeID = miniNode.id; isShowingMiniDeleteDialog = true
         }, isStopSignSelected: isStopSignSelected)
            .frame(width: canvasNodeSize(miniNode.wrappedValue, project: project).width, height: canvasNodeSize(miniNode.wrappedValue, project: project).height)
            .zIndex(movingMiniNodeID == miniNode.id ? 10 : 0)
            .position(miniNode.wrappedValue.position)
            .onTapGesture {
                if let src = sourceConnection, src.nodeID != miniNode.id {
                    if let sIdx = data.wrappedValue.miniNodes.firstIndex(where: { $0.id == src.nodeID }) {
                        if let cid = src.choiceID, var d = data.wrappedValue.miniNodes[sIdx].choicesData, let cIdx = d.options.firstIndex(where: { $0.id == cid }) { 
                            d.options[cIdx].target = ConnectionData(targetNodeID: miniNode.id, color: currentConnectionColor)
                            data.wrappedValue.miniNodes[sIdx].choicesData = d 
                        } else if !data.wrappedValue.miniNodes[sIdx].connections.contains(where: { $0.targetNodeID == miniNode.id }) { 
                            data.wrappedValue.miniNodes[sIdx].connections.append(ConnectionData(targetNodeID: miniNode.id, color: currentConnectionColor)) 
                        }
                        sourceConnection = nil
                    }
                }
            }
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in withAnimation(.easeInOut(duration: 0.15)) { node.locationData?.isMiniEditing = true; node.locationData?.selectedMiniNodeID = miniNode.id } }
                .simultaneously(with: DragGesture(minimumDistance: 1).onChanged { value in handleMiniNodeDragChanged(value: value, miniNode: miniNode) }.onEnded { _ in handleMiniNodeDragEnded(miniNode: miniNode, proxySize: proxySize) }))
    }
    private func miniDeleteButton(nodeID: UUID) -> some View {
        Button { pendingMiniDeletionNodeID = nodeID; isShowingMiniDeleteDialog = true } label: {
            Circle().fill(Color.red).frame(width: 28, height: 28).overlay { Image(systemName: "minus").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }
        }.buttonStyle(.plain).offset(x: 10, y: -10)
    }
    private func handleMiniNodeDragChanged(value: DragGesture.Value, miniNode: Binding<CanvasNode>) {
        if node.locationData?.selectedMiniNodeID != miniNode.id { node.locationData?.isMiniEditing = true; node.locationData?.selectedMiniNodeID = miniNode.id }
        guard node.locationData?.isMiniEditing == true && node.locationData?.selectedMiniNodeID == miniNode.id else { return }
        if movingMiniNodeID != miniNode.id { movingMiniNodeID = miniNode.id; movingMiniStartPosition = miniNode.wrappedValue.position }
        let newPosition = CGPoint(x: movingMiniStartPosition.x + value.translation.width, y: movingMiniStartPosition.y + value.translation.height)
        miniNode.wrappedValue.position = newPosition
        let nodeSize = canvasNodeSize(miniNode.wrappedValue, project: project)
        let nodeRight = miniNode.wrappedValue.position.x + nodeSize.width / 2; let nodeLeft = miniNode.wrappedValue.position.x - nodeSize.width / 2
        let nodeBottom = miniNode.wrappedValue.position.y + nodeSize.height / 2; let nodeTop = miniNode.wrappedValue.position.y - nodeSize.height / 2
        let edgeThreshold: CGFloat = 40
        if nodeRight > (node.locationData?.pinnedMiniCanvasWidth ?? 0) - edgeThreshold { node.locationData?.pinnedMiniCanvasWidth = nodeRight + edgeThreshold }
        if nodeBottom > (node.locationData?.pinnedMiniCanvasHeight ?? 0) - edgeThreshold { node.locationData?.pinnedMiniCanvasHeight = nodeBottom + edgeThreshold }
        if nodeLeft < edgeThreshold {
            let diff = edgeThreshold - nodeLeft; node.locationData?.pinnedMiniCanvasWidth += diff
            for i in 0..<(node.locationData?.miniNodes.count ?? 0) { if node.locationData?.miniNodes[i].id != miniNode.id { node.locationData?.miniNodes[i].position.x += diff } }
            movingMiniStartPosition.x += diff; miniNode.wrappedValue.position.x += diff; node.position.x -= diff / 2
        }
        if nodeTop < edgeThreshold {
            let diff = edgeThreshold - nodeTop; node.locationData?.pinnedMiniCanvasHeight += diff
            for i in 0..<(node.locationData?.miniNodes.count ?? 0) { if node.locationData?.miniNodes[i].id != miniNode.id { node.locationData?.miniNodes[i].position.y += diff } }
            movingMiniStartPosition.y += diff; miniNode.wrappedValue.position.y += diff; node.position.y -= diff / 2
        }
        adjustPinnedCanvasForNode(at: miniNode.wrappedValue.position, size: canvasNodeSize(miniNode.wrappedValue, project: project))
    }
    private func handleMiniNodeDragEnded(miniNode: Binding<CanvasNode>, proxySize: CGSize) {
        guard node.locationData?.isMiniEditing == true, node.locationData?.selectedMiniNodeID == miniNode.id else { return }
        let miniBounds = CGRect(origin: .zero, size: proxySize)
        if !miniBounds.insetBy(dx: -20, dy: -20).contains(miniNode.wrappedValue.position) {
            node.locationData?.isMiniEditing = false; node.locationData?.selectedMiniNodeID = nil
            let worldPos = worldPositionForMiniNode(miniPosition: miniNode.wrappedValue.position, currentMiniCanvasSize: proxySize)
            onMoveMiniNodeToMain(node.id, miniNode.wrappedValue, worldPos); movingMiniNodeID = nil; return
        }
        let others = node.locationData?.miniNodes.filter { $0.id != miniNode.id } ?? []
        miniNode.wrappedValue.position = nearestFreeMiniPosition(miniNode.wrappedValue.position, canvasNodeSize(miniNode.wrappedValue, project: project), others)
        adjustPinnedCanvasForNode(at: miniNode.wrappedValue.position, size: canvasNodeSize(miniNode.wrappedValue, project: project)); movingMiniNodeID = nil
    }

    @ViewBuilder private func renderMiniConnections(proxySize: CGSize) -> some View {
        let miniNodes = data.wrappedValue.miniNodes
        ForEach(miniNodes) { mNode in
            ForEach(mNode.targetNodeIDs, id: \.self) { targetID in
                if let tNode = miniNodes.first(where: { $0.id == targetID }) {
                    miniConnectionLine(from: mNode, to: tNode, choice: nil)
                }
            }
            if let cData = mNode.choicesData {
                ForEach(cData.options) { option in
                    if let tID = option.targetNodeID, let tNode = miniNodes.first(where: { $0.id == tID }) {
                        miniConnectionLine(from: mNode, to: tNode, choice: option)
                    }
                }
            }
        }
    }

    private func miniConnectionLine(from: CanvasNode, to: CanvasNode, choice: ChoiceOption?) -> some View {
        let sourceRect = rectCentered(at: from.position, size: canvasNodeSize(from, project: project))
        let targetRect = rectCentered(at: to.position, size: canvasNodeSize(to, project: project))
        let connectionInfo = bestMiniConnectionPoints(from: sourceRect, to: targetRect, fromChoice: choice, fromNode: from)
        let obstacles = data.wrappedValue.miniNodes.filter { $0.id != to.id }.map { rectCentered(at: $0.position, size: canvasNodeSize($0, project: project)).insetBy(dx: -5, dy: -5) }
        
        let connectionData = choice != nil ? choice?.target : from.connections.first(where: { $0.targetNodeID == to.id })
        let pathColor = connectionData?.color?.color ?? .black.opacity(0.6)
        
        return ConnectionLineView(
            from: connectionInfo.from,
            to: connectionInfo.to,
            fromSide: connectionInfo.fromSide,
            toSide: connectionInfo.toSide,
            obstacles: obstacles,
            isSelected: false,
            onTap: {},
            onDelete: {
                if let idx = data.wrappedValue.miniNodes.firstIndex(where: { $0.id == from.id }) {
                    if let cid = choice?.id, var cData = data.wrappedValue.miniNodes[idx].choicesData, let cIdx = cData.options.firstIndex(where: { $0.id == cid }) {
                        cData.options[cIdx].target = nil; data.wrappedValue.miniNodes[idx].choicesData = cData
                    } else {
                        data.wrappedValue.miniNodes[idx].connections.removeAll { $0.targetNodeID == to.id }
                    }
                }
            },
            color: pathColor
        )
    }

    private func bestMiniConnectionPoints(from: CGRect, to: CGRect, fromChoice: ChoiceOption?, fromNode: CanvasNode) -> (from: CGPoint, to: CGPoint, fromSide: ConnectionSide, toSide: ConnectionSide) {
        let fromPoint: CGPoint; let fromSide: ConnectionSide
        if let choice = fromChoice {
            fromPoint = choiceMiniPosition(node: fromNode, choiceID: choice.id)
            fromSide = (fromNode.choicesData?.isCollapsed ?? false) ? .bottom : .right
        } else {
            let dx = to.midX - from.midX; let dy = to.midY - from.midY
            if abs(dx) > abs(dy) {
                if dx > 0 { fromPoint = CGPoint(x: from.maxX + 15, y: from.midY); fromSide = .right }
                else { fromPoint = CGPoint(x: from.minX - 15, y: from.midY); fromSide = .left }
            } else {
                if dy > 0 { fromPoint = CGPoint(x: from.midX, y: from.maxY + 15); fromSide = .bottom }
                else { fromPoint = CGPoint(x: from.midX, y: from.minY - 15); fromSide = .top }
            }
        }
        let dx = to.midX - fromPoint.x; let dy = to.midY - fromPoint.y; var toPoint: CGPoint; var toSide: ConnectionSide
        if abs(dx) > abs(dy) { if dx > 0 { toPoint = CGPoint(x: to.minX, y: to.midY); toSide = .left } else { toPoint = CGPoint(x: to.maxX, y: to.midY); toSide = .right } }
        else { if dy > 0 { toPoint = CGPoint(x: to.midX, y: to.minY); toSide = .top } else { toPoint = CGPoint(x: to.midX, y: to.maxY); toSide = .bottom } }
        return (fromPoint, toPoint, fromSide, toSide)
    }

    private func choiceMiniPosition(node: CanvasNode, choiceID: UUID) -> CGPoint {
        guard let data = node.choicesData, let idx = data.options.firstIndex(where: { $0.id == choiceID }) else { return node.position }
        let cardSize = canvasNodeSize(node, project: project)
        if !data.isCollapsed {
            let tLines = AlphaLogic.lineCount(for: data.title, font: ChoiceCardLayout.titleFont, measureWidth: ChoiceCardLayout.titleMeasureWidth); let tH = max(52, AlphaLogic.steppedHeight(base: ChoiceCardLayout.titleBaseHeight, increment: ChoiceCardLayout.titleLineIncrement, lineCount: tLines))
            var curY = node.position.y - cardSize.height/2 + 12 + tH + 10
            for i in 0..<idx { let opt = data.options[i]; let lC = AlphaLogic.lineCount(for: opt.description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth); curY += AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: lC) + 10 }
            let thisLC = AlphaLogic.lineCount(for: data.options[idx].description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth)
            return CGPoint(x: node.position.x + ChoiceCardLayout.cardWidth/2 + 25, y: curY + AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: thisLC)/2)
        } else {
            let maxBtns = ChoiceCardLayout.maxBtnsPerRow; let rowIdx = idx / maxBtns; let colIdx = idx % maxBtns
            let btnS: CGFloat = 56; let sp: CGFloat = 4; let numRows = (data.options.count + maxBtns - 1) / maxBtns
            let rowCount = (rowIdx == numRows - 1) ? (data.options.count % maxBtns == 0 ? maxBtns : data.options.count % maxBtns) : maxBtns
            let rowWidth = CGFloat(rowCount) * btnS + CGFloat(rowCount - 1) * sp
            let posX = node.position.x - rowWidth/2 + btnS/2 + CGFloat(colIdx) * (btnS + sp)
            return CGPoint(x: posX, y: node.position.y + cardSize.height/2 + 15)
        }
    }

    private func handleDropOnMiniCanvas(items: [String], location: CGPoint, proxySize: CGSize) -> Bool {
        defer { node.locationData?.isMiniCanvasTargeted = false }
        guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else { return false }
        var newNode = defaultNode(for: type); let itemSize = canvasNodeSize(newNode, project: project)
        let placement = placeNodeWithoutOverlapInMini(location, itemSize, node.locationData?.miniNodes ?? [], proxySize, project)
        node.locationData?.pinnedMiniCanvasWidth = max(node.locationData?.pinnedMiniCanvasWidth ?? 0, placement.requiredSize.width)
        node.locationData?.pinnedMiniCanvasHeight = max(node.locationData?.pinnedMiniCanvasHeight ?? 0, placement.requiredSize.height)
        newNode.position = placement.position; node.locationData?.miniNodes.append(newNode); ensurePinnedCanvasCoversAllNodes(); return true
    }
    private var miniNodeLayoutFingerprint: String {
        var parts: [String] = []; for miniNode in node.locationData?.miniNodes ?? [] { let size = canvasNodeSize(miniNode, project: project); parts.append("\(miniNode.id.uuidString):\(miniNode.position.x):\(miniNode.position.y):\(size.width):\(size.height)") }; return parts.joined(separator: "|")
    }
    private func ensurePinnedCanvasCoversAllNodes() {
        guard let miniNodes = node.locationData?.miniNodes, !miniNodes.isEmpty else { return }
        var minTop: CGFloat = .infinity; var minLeft: CGFloat = .infinity
        for miniNode in miniNodes { let size = canvasNodeSize(miniNode, project: project); minTop = min(minTop, miniNode.position.y - size.height / 2); minLeft = min(minLeft, miniNode.position.x - size.width / 2) }
        let padding = LocationCardLayout.miniCanvasVerticalPadding; var shiftX: CGFloat = 0; var shiftY: CGFloat = 0
        if minTop < padding { shiftY = padding - minTop }; if minLeft < padding { shiftX = padding - minLeft }
        if shiftX > 0 || shiftY > 0 {
            for i in 0..<(node.locationData?.miniNodes.count ?? 0) { node.locationData?.miniNodes[i].position.x += shiftX; node.locationData?.miniNodes[i].position.y += shiftY }
            node.position.x -= shiftX / 2; node.position.y -= shiftY / 2; node.locationData?.pinnedMiniCanvasWidth += shiftX; node.locationData?.pinnedMiniCanvasHeight += shiftY
        }
        for miniNode in node.locationData?.miniNodes ?? [] { adjustPinnedCanvasForNode(at: miniNode.position, size: canvasNodeSize(miniNode, project: project)) }
    }
    private func adjustPinnedCanvasForNode(at position: CGPoint, size: CGSize) {
        let requiredWidth = position.x + size.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding; let requiredHeight = position.y + size.height / 2 + LocationCardLayout.miniCanvasVerticalPadding
        node.locationData?.pinnedMiniCanvasWidth = max(node.locationData?.pinnedMiniCanvasWidth ?? 0, requiredWidth, LocationCardLayout.miniCanvasMinWidth)
        node.locationData?.pinnedMiniCanvasHeight = max(node.locationData?.pinnedMiniCanvasHeight ?? 0, requiredHeight, LocationCardLayout.miniCanvasMinHeight)
    }
    private func nearestFreeMiniPosition(_ desired: CGPoint, _ itemSize: CGSize, _ existing: [CanvasNode]) -> CGPoint {
        let desiredRect = rectCentered(at: desired, size: itemSize); if !intersectsAny(rect: desiredRect, nodes: existing, project: project) { return desired }
        let step: CGFloat = 24
        for radius in 1...80 {
            for gx in -radius...radius {
                for gy in -radius...radius {
                    guard abs(gx) == radius || abs(gy) == radius else { continue }
                    let candidate = CGPoint(x: desired.x + CGFloat(gx) * step, y: desired.y + CGFloat(gy) * step)
                    if !intersectsAny(rect: rectCentered(at: candidate, size: itemSize), nodes: existing, project: project) { return candidate }
                }
            }
        }
        return desired
    }
    private func worldPositionForMiniNode(miniPosition: CGPoint, currentMiniCanvasSize: CGSize) -> CGPoint {
        let cardSize = locationCardSize(node.locationData); let cardTopLeft = CGPoint(x: node.position.x - cardSize.width / 2, y: node.position.y - cardSize.height / 2)
        let miniOrigin = CGPoint(x: cardTopLeft.x + LocationCardLayout.outerHorizontalPadding, y: cardTopLeft.y + LocationCardLayout.outerTopPadding + LocationCardLayout.headerHeight + LocationCardLayout.headerToMiniGap)
        return CGPoint(x: miniOrigin.x + miniPosition.x, y: miniOrigin.y + miniPosition.y)
    }
}

private struct ChoicesCanvasCard: View {
    let nodeID: UUID
    @Binding var data: ChoicesCardData
    @Binding var project: Project
    @Binding var sourceConnection: ConnectionSource?
    var body: some View {
        let actIdx = project.acts.firstIndex(where: { $0.id == project.currentActID }) ?? 0
        let node = project.acts[actIdx].canvasNodes.first(where: { $0.id == nodeID })
        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray4))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if data.isCollapsed { Text("Choices").font(.system(size: 28, weight: .regular)).foregroundStyle(Color.black.opacity(0.9)) }
                        Spacer()
                        Button { data.isCollapsed.toggle() } label: { Image(systemName: data.isCollapsed ? "chevron.down" : "chevron.up").font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.black.opacity(0.85)) }.buttonStyle(.plain).frame(width: 34, height: 34)
                    }
                    AutoGrowingTextEditor(text: $data.title, minimumHeight: ChoiceCardLayout.titleBaseHeight, baseHeight: ChoiceCardLayout.titleBaseHeight, lineIncrement: ChoiceCardLayout.titleLineIncrement, measureFont: ChoiceCardLayout.titleFont, textFont: .system(size: 24, weight: .regular), measureWidth: ChoiceCardLayout.titleMeasureWidth, textAlignment: .center).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6)))
                    
                    if data.isCollapsed {
                        Spacer()
                        VStack(alignment: .center, spacing: 4) {
                            let maxBtns = ChoiceCardLayout.maxBtnsPerRow
                            let chunked = data.options.chunked(into: maxBtns)
                            ForEach(0..<chunked.count, id: \.self) { rowIdx in
                                HStack(spacing: 4) {
                                    ForEach(chunked[rowIdx]) { option in choiceButton(option: option) }
                                }
                            }
                        }.frame(maxWidth: .infinity)
                    } else {
                        ForEach($data.options) { $option in
                            HStack(alignment: .center, spacing: 0) {
                                ChoiceRowView(option: $option)
                                choiceButton(option: option).padding(.leading, 10).offset(x: 25)
                            }
                        }
                        Button { addChoice() } label: { Circle().fill(Color(.systemGray6)).frame(width: 56, height: 56).overlay { Image(systemName: "plus").font(.system(size: 34, weight: .regular)).foregroundStyle(Color.black.opacity(0.82)) }.shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1) }.buttonStyle(.plain)
                    }
                }.padding(12)
            }
    }
    @ViewBuilder private func choiceButton(option: ChoiceOption) -> some View {
        Button { if sourceConnection?.nodeID == nodeID && sourceConnection?.choiceID == option.id { sourceConnection = nil } else { sourceConnection = ConnectionSource(nodeID: nodeID, choiceID: option.id) } } label: {
            RoundedRectangle(cornerRadius: 12).fill((sourceConnection?.nodeID == nodeID && sourceConnection?.choiceID == option.id) ? Color.green.opacity(0.4) : Color.white).frame(width: 56, height: 56)
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15), lineWidth: 1); Text(option.label).font(.system(size: 18, weight: .bold)).foregroundStyle(Color.black.opacity(0.7)) }.shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        }.buttonStyle(.plain)
    }
    private func addChoice() { let next = data.options.count + 1; data.options.append(ChoiceOption(label: "\(next)", description: "")) }
}

private enum PropCardLayout {
    static let cardWidth: CGFloat = 430; static let outerPadding: CGFloat = 14; static let verticalSpacing: CGFloat = 10; static let titleBaseHeight: CGFloat = 52; static let titleLineIncrement: CGFloat = 22; static let titleFont: UIFont = .systemFont(ofSize: 24, weight: .regular); static let titleMeasureWidth: CGFloat = 330
    static let imageHeight: CGFloat = 180; static let imageInnerHeight: CGFloat = 120
    static let descriptionBaseHeight: CGFloat = 56; static let descriptionLineIncrement: CGFloat = 22; static let descriptionFont: UIFont = .systemFont(ofSize: 22, weight: .regular); static let descriptionMeasureWidth: CGFloat = 360
}

private struct PropCanvasCard: View {
    @Binding var data: PropCardData; @State private var selectedPhotoItem: PhotosPickerItem?
    var body: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray4))
            .overlay(alignment: .topLeading) {
                VStack(spacing: PropCardLayout.verticalSpacing) {
                    AutoGrowingTextEditor(text: $data.title, minimumHeight: PropCardLayout.titleBaseHeight, baseHeight: PropCardLayout.titleBaseHeight, lineIncrement: PropCardLayout.titleLineIncrement, measureFont: PropCardLayout.titleFont, textFont: .system(size: 24, weight: .regular), measureWidth: PropCardLayout.titleMeasureWidth, textAlignment: .center).background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                        .overlay(alignment: .center) { if data.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("Name of the prop").font(.system(size: 24, weight: .regular)).foregroundStyle(Color.black.opacity(0.65)).allowsHitTesting(false) } }
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)).frame(height: PropCardLayout.imageHeight)
                            .overlay {
                                if let imageData = data.imageData, let image = UIImage(data: imageData) { Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity, maxHeight: .infinity).padding(16) }
                                else { Image(systemName: "photo.badge.plus").font(.system(size: 86, weight: .regular)).foregroundStyle(Color.black.opacity(0.75)).frame(height: PropCardLayout.imageInnerHeight) }
                            }
                    }.buttonStyle(.plain)
                    AutoGrowingTextEditor(text: $data.description, minimumHeight: PropCardLayout.descriptionBaseHeight, baseHeight: PropCardLayout.descriptionBaseHeight, lineIncrement: PropCardLayout.descriptionLineIncrement, measureFont: PropCardLayout.descriptionFont, textFont: .system(size: 22, weight: .regular), measureWidth: PropCardLayout.descriptionMeasureWidth, textAlignment: .leading).background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
                        .overlay(alignment: .leading) { if data.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("Description").font(.system(size: 22, weight: .regular)).foregroundStyle(Color.black.opacity(0.65)).padding(.leading, 16).allowsHitTesting(false) } }
                }.padding(PropCardLayout.outerPadding)
            }
            .onChange(of: selectedPhotoItem) { newItem in guard let newItem else { return }; Task { if let imageData = try? await newItem.loadTransferable(type: Data.self) { await MainActor.run { data.imageData = imageData } } } }
    }
}

private struct ChoiceRowView: View {
    @Binding var option: ChoiceOption
    var body: some View {
        let lineCount = AlphaLogic.lineCount(for: option.description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth)
        let descriptionHeight = AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: lineCount)
        HStack(alignment: .top, spacing: 10) {
            TextField("", text: $option.label).font(.system(size: 24, weight: .regular)).multilineTextAlignment(.center).frame(width: 56, height: 56).background(Circle().fill(Color(.systemGray6)).shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)).onChange(of: option.label) { newValue in option.label = sanitizeOneWord(newValue) }
            AutoGrowingTextEditor(text: $option.description, minimumHeight: descriptionHeight, baseHeight: ChoiceCardLayout.descriptionBaseHeight, lineIncrement: ChoiceCardLayout.descriptionLineIncrement, measureFont: ChoiceCardLayout.descriptionFont, textFont: .system(size: 22, weight: .regular), measureWidth: ChoiceCardLayout.descriptionMeasureWidth, textAlignment: .leading).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6)))
        }
    }
    private func sanitizeOneWord(_ value: String) -> String { value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init).first ?? "" }
}

private enum ChoiceCardLayout {
    static let cardWidth: CGFloat = 350; static let titleBaseHeight: CGFloat = 52; static let titleLineIncrement: CGFloat = 22; static let descriptionBaseHeight: CGFloat = 56; static let descriptionLineIncrement: CGFloat = 22; static let titleFont: UIFont = .systemFont(ofSize: 24, weight: .regular); static let descriptionFont: UIFont = .systemFont(ofSize: 22, weight: .regular); static let titleMeasureWidth: CGFloat = 250; static let descriptionMeasureWidth: CGFloat = 180; static let maxBtnsPerRow: Int = 5
}

private enum AlphaLogic {
    static func steppedHeight(base: CGFloat, increment: CGFloat, lineCount: Int) -> CGFloat { base + (CGFloat(max(0, lineCount - 1)) * increment) }
    static func lineCount(for text: String, font: UIFont, measureWidth: CGFloat) -> Int {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines); if value.isEmpty { return 1 }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byWordWrapping
        let measured = (value as NSString).boundingRect(with: CGSize(width: measureWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
        return max(1, Int(ceil(measured.height / font.lineHeight)))
    }
}

private struct AutoGrowingTextEditor: View {
    @Binding var text: String; let minimumHeight: CGFloat; let baseHeight: CGFloat; let lineIncrement: CGFloat; let measureFont: UIFont; let textFont: Font; let measureWidth: CGFloat; let textAlignment: TextAlignment; var isReadOnly: Bool = false; @State private var dynamicHeight: CGFloat = 56
    var body: some View {
        TextEditor(text: $text).font(textFont).scrollContentBackground(.hidden).scrollDisabled(true).disabled(isReadOnly).padding(.horizontal, 12).padding(.vertical, 8).multilineTextAlignment(textAlignment).frame(maxWidth: .infinity, alignment: .leading).frame(height: max(minimumHeight, dynamicHeight), alignment: .topLeading)
            .background(GeometryReader { proxy in Color.clear.onAppear { recalculateHeight(for: proxy.size.width) }.onChange(of: text) { _ in recalculateHeight(for: proxy.size.width) } })
    }
    private func recalculateHeight(for width: CGFloat) {
        let usableWidth = max(1, min(width - 24, measureWidth)); let lineCount = AlphaLogic.lineCount(for: text, font: measureFont, measureWidth: usableWidth)
        dynamicHeight = max(minimumHeight, AlphaLogic.steppedHeight(base: baseHeight, increment: lineIncrement, lineCount: lineCount))
    }
}

private func canvasNodeSize(_ node: CanvasNode, project: Project) -> CGSize {
    switch node.type {
    case .location: return locationCardSize(node.locationData)
    case .choices: return choicesCardSize(node.choicesData, project: project, node: node)
    case .prop: return propCardSize(node.propData)
    case .event: return eventCardSize(node.eventData)
    }
}

private enum EventCardLayout {
    static let cardWidth: CGFloat = 430; static let outerPadding: CGFloat = 14; static let titleBaseHeight: CGFloat = 52; static let titleLineIncrement: CGFloat = 22; static let titleFont: UIFont = .systemFont(ofSize: 24, weight: .regular); static let titleMeasureWidth: CGFloat = 330
    static let subEventDescBaseHeight: CGFloat = 56; static let subEventDescLineIncrement: CGFloat = 22; static let subEventDescFont: UIFont = .systemFont(ofSize: 22, weight: .regular); static let subEventDescMeasureWidth: CGFloat = 280
}

private func eventCardSize(_ data: EventCardData?) -> CGSize {
    guard let data else { return CGSize(width: EventCardLayout.cardWidth, height: 300) }
    let titleLines = AlphaLogic.lineCount(for: data.title, font: EventCardLayout.titleFont, measureWidth: EventCardLayout.titleMeasureWidth)
    let titleHeight = max(EventCardLayout.titleBaseHeight, AlphaLogic.steppedHeight(base: EventCardLayout.titleBaseHeight, increment: EventCardLayout.titleLineIncrement, lineCount: titleLines))
    let subEventsHeight = data.subEvents.reduce(CGFloat(0)) { total, sub in
        let descLines = AlphaLogic.lineCount(for: sub.description, font: EventCardLayout.subEventDescFont, measureWidth: EventCardLayout.subEventDescMeasureWidth)
        let descHeight = max(EventCardLayout.subEventDescBaseHeight, AlphaLogic.steppedHeight(base: EventCardLayout.subEventDescBaseHeight, increment: EventCardLayout.subEventDescLineIncrement, lineCount: descLines))
        return total + max(56, descHeight + 10 + 56) + 10
    }
    return CGSize(width: EventCardLayout.cardWidth, height: max(300, (EventCardLayout.outerPadding * 2) + titleHeight + 16 + 108 + 16 + subEventsHeight + 66 + 30))
}

struct EventCanvasCard: View {
    @Binding var data: EventCardData; @Binding var project: Project
    var body: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray4))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 16) {
                    AutoGrowingTextEditor(text: $data.title, minimumHeight: EventCardLayout.titleBaseHeight, baseHeight: EventCardLayout.titleBaseHeight, lineIncrement: EventCardLayout.titleLineIncrement, measureFont: EventCardLayout.titleFont, textFont: .system(size: 24, weight: .regular), measureWidth: EventCardLayout.titleMeasureWidth, textAlignment: .center).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6)))
                        .overlay(alignment: .center) { if data.title.isEmpty { Text("Name of the event").font(.system(size: 24, weight: .regular)).foregroundStyle(Color.black.opacity(0.65)).allowsHitTesting(false) } }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Involved Characters").font(.system(size: 24, weight: .regular)).foregroundStyle(Color.black.opacity(0.9))
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { ForEach(data.involvedCharacterIDs, id: \.self) { charID in if let char = project.characters.first(where: { $0.id == charID }) { CharacterIconView(character: char, size: 48) } } }.padding(.horizontal, 12).frame(height: 64).frame(minWidth: EventCardLayout.cardWidth - (EventCardLayout.outerPadding * 2), alignment: .leading) }
                    }
                    VStack(alignment: .leading, spacing: 10) { ForEach(Array(data.subEvents.enumerated()), id: \.element.id) { index, subEvent in subEventItem(at: index) }; addSubeventButton }
                }.padding(EventCardLayout.outerPadding)
            }
    }
    @ViewBuilder private func subEventItem(at index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)").font(.system(size: 24, weight: .regular)).foregroundStyle(Color.black.opacity(0.85)).frame(width: 56, height: 56).background(Circle().fill(Color(.systemGray6)).shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1))
            VStack(alignment: .leading, spacing: 10) {
                AutoGrowingTextEditor(text: Binding(get: { data.subEvents[index].description }, set: { data.subEvents[index].description = $0 }), minimumHeight: EventCardLayout.subEventDescBaseHeight, baseHeight: EventCardLayout.subEventDescBaseHeight, lineIncrement: EventCardLayout.subEventDescLineIncrement, measureFont: EventCardLayout.subEventDescFont, textFont: .system(size: 22, weight: .regular), measureWidth: EventCardLayout.subEventDescMeasureWidth, textAlignment: .leading).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6)))
                VStack(alignment: .leading, spacing: 6) {
                    if data.subEvents[index].characterIDs.isEmpty { HStack { Image(systemName: "person.badge.plus").font(.system(size: 20)); Text("Drop characters here").font(.system(size: 16)) }.foregroundStyle(Color.black.opacity(0.5)).frame(maxWidth: .infinity).frame(height: 56).background(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))) }
                    else { HStack(spacing: 8) { ForEach(data.subEvents[index].characterIDs, id: \.self) { charID in if let char = project.characters.first(where: { $0.id == charID }) { CharacterIconView(character: char, size: 40).onTapGesture { data.subEvents[index].characterIDs.removeAll { $0 == charID }; updateInvolvedCharacters() } } }; Button { if !data.subEvents[index].characterIDs.isEmpty { data.subEvents[index].characterIDs.removeLast(); updateInvolvedCharacters() } } label: { Image(systemName: "minus.circle.fill").font(.system(size: 24)).foregroundStyle(.red.opacity(0.8)) }.buttonStyle(.plain) }.padding(.horizontal, 12).frame(height: 56).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6))) }
                }.contentShape(Rectangle()).dropDestination(for: UUID.self) { items, _ in guard let charID = items.first else { return false }; if !data.subEvents[index].characterIDs.contains(charID) { data.subEvents[index].characterIDs.append(charID); updateInvolvedCharacters(); return true }; return false }
            }
        }
    }
    private var addSubeventButton: some View { Button { data.subEvents.append(SubEvent(description: "")) } label: { Circle().fill(Color(.systemGray6)).frame(width: 56, height: 56).overlay { Image(systemName: "plus").font(.system(size: 34, weight: .regular)).foregroundStyle(Color.black.opacity(0.82)) }.shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1) }.buttonStyle(.plain) }
    private func updateInvolvedCharacters() { var allIDs = Set<UUID>(); for sub in data.subEvents { for id in sub.characterIDs { allIDs.insert(id) } }; data.involvedCharacterIDs = Array(allIDs) }
}

private func locationCardSize(_ data: LocationCardData?) -> CGSize {
    guard let data else { return CGSize(width: LocationCardLayout.cardWidth, height: LocationCardLayout.defaultCardHeight) }
    let miniSize = miniCanvasSize(for: data, project: nil)
    return CGSize(width: miniSize.width + (LocationCardLayout.outerHorizontalPadding * 2), height: LocationCardLayout.outerTopPadding + LocationCardLayout.headerHeight + LocationCardLayout.headerToMiniGap + miniSize.height + LocationCardLayout.outerBottomPadding)
}

private func choicesCardSize(_ data: ChoicesCardData?, project: Project? = nil, node: CanvasNode? = nil) -> CGSize {
    guard let data else { return CGSize(width: ChoiceCardLayout.cardWidth, height: 200) }
    let titleLineCount = AlphaLogic.lineCount(for: data.title, font: ChoiceCardLayout.titleFont, measureWidth: ChoiceCardLayout.titleMeasureWidth)
    let titleHeight = max(52, AlphaLogic.steppedHeight(base: ChoiceCardLayout.titleBaseHeight, increment: ChoiceCardLayout.titleLineIncrement, lineCount: titleLineCount))
    if data.isCollapsed {
        let maxBtns = ChoiceCardLayout.maxBtnsPerRow; let numRows = (data.options.count + maxBtns - 1) / maxBtns
        let btnSize: CGFloat = 56; let spacing: CGFloat = 4
        let rowWidth = CGFloat(min(data.options.count, maxBtns)) * btnSize + CGFloat(max(0, min(data.options.count, maxBtns) - 1)) * spacing
        let totalBtnsHeight = CGFloat(numRows) * btnSize + CGFloat(max(0, numRows - 1)) * spacing
        let headerHeight = 12 + 34 + 10 + titleHeight + 12
        return CGSize(width: max(ChoiceCardLayout.cardWidth, rowWidth + 24), height: headerHeight + totalBtnsHeight + 10)
    }
    let rowsHeight = data.options.reduce(CGFloat(0)) { $0 + AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: AlphaLogic.lineCount(for: $1.description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth)) }
    return CGSize(width: ChoiceCardLayout.cardWidth, height: max(200, 12 + titleHeight + 10 + rowsHeight + (CGFloat(max(data.options.count, 0)) * 10) + 66 + 12))
}

private func propCardSize(_ data: PropCardData?) -> CGSize {
    guard let data else { return CGSize(width: PropCardLayout.cardWidth, height: 330) }
    let titleHeight = max(PropCardLayout.titleBaseHeight, AlphaLogic.steppedHeight(base: PropCardLayout.titleBaseHeight, increment: PropCardLayout.titleLineIncrement, lineCount: AlphaLogic.lineCount(for: data.title, font: PropCardLayout.titleFont, measureWidth: PropCardLayout.titleMeasureWidth)))
    let descHeight = max(PropCardLayout.descriptionBaseHeight, AlphaLogic.steppedHeight(base: PropCardLayout.descriptionBaseHeight, increment: PropCardLayout.descriptionLineIncrement, lineCount: AlphaLogic.lineCount(for: data.description, font: PropCardLayout.descriptionFont, measureWidth: PropCardLayout.descriptionMeasureWidth)))
    return CGSize(width: PropCardLayout.cardWidth, height: max(330, (PropCardLayout.outerPadding * 2) + titleHeight + PropCardLayout.verticalSpacing + PropCardLayout.imageHeight + PropCardLayout.verticalSpacing + descHeight))
}

private func rectCentered(at center: CGPoint, size: CGSize) -> CGRect { CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height) }
private func intersectsAny(rect: CGRect, nodes: [CanvasNode], project: Project) -> Bool { nodes.contains { rect.intersects(rectCentered(at: $0.position, size: canvasNodeSize($0, project: project)).insetBy(dx: -4, dy: -4)) } }
private func miniCanvasSize(for data: LocationCardData, project: Project? = nil) -> CGSize {
    let contentBottom = data.miniNodes.reduce(CGFloat(0)) { max($0, $1.position.y + (project != nil ? canvasNodeSize($1, project: project!).height : 200) / 2 + LocationCardLayout.miniCanvasVerticalPadding) }
    let contentRight = data.miniNodes.reduce(CGFloat(0)) { max($0, $1.position.x + (project != nil ? canvasNodeSize($1, project: project!).width : 430) / 2 + LocationCardLayout.miniCanvasHorizontalPadding) }
    let projectedHeight = data.isMiniCanvasTargeted ? contentBottom + LocationCardLayout.hoverExpansionHeight : contentBottom
    let projectedWidth = data.isMiniCanvasTargeted ? contentRight + LocationCardLayout.hoverExpansionWidth : contentRight
    return CGSize(width: max(LocationCardLayout.miniCanvasMinWidth, data.pinnedMiniCanvasWidth, projectedWidth), height: max(LocationCardLayout.miniCanvasMinHeight, data.pinnedMiniCanvasHeight, projectedHeight))
}

private func placeNodeWithoutOverlapInMini(_ desired: CGPoint, _ itemSize: CGSize, _ existing: [CanvasNode], _ currentCanvasSize: CGSize, _ project: Project) -> (position: CGPoint, requiredSize: CGSize) {
    var width = max(currentCanvasSize.width, itemSize.width + (LocationCardLayout.miniCanvasHorizontalPadding * 2)); var height = max(currentCanvasSize.height, itemSize.height + (LocationCardLayout.miniCanvasVerticalPadding * 2))
    func clamp(_ p: CGPoint) -> CGPoint { CGPoint(x: min(max(p.x, itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding), width - itemSize.width / 2 - LocationCardLayout.miniCanvasHorizontalPadding), y: min(max(p.y, itemSize.height / 2 + LocationCardLayout.miniCanvasVerticalPadding), height - itemSize.height / 2 - LocationCardLayout.miniCanvasVerticalPadding)) }
    var cand = clamp(desired); let stepX = itemSize.width + 18; let stepY = itemSize.height + 18
    for _ in 0..<500 {
        let rect = rectCentered(at: cand, size: itemSize); if !existing.contains(where: { rect.intersects(rectCentered(at: $0.position, size: canvasNodeSize($0, project: project)).insetBy(dx: -4, dy: -4)) }) { return (cand, CGSize(width: width, height: height)) }
        cand.x += stepX; if cand.x > width - itemSize.width / 2 - LocationCardLayout.miniCanvasHorizontalPadding { cand.x = itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding; cand.y += stepY }
        if cand.y > height - itemSize.height / 2 - LocationCardLayout.miniCanvasVerticalPadding { width += max(stepX, 120); height += max(stepY, 90); cand = clamp(CGPoint(x: itemSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding, y: itemSize.height / 2 + LocationCardLayout.miniCanvasVerticalPadding)) }
        cand = clamp(cand)
    }
    return (cand, CGSize(width: width, height: height))
}

struct CanvasNodeContainer: View {
    @Binding var node: CanvasNode; @Binding var project: Project; @Binding var sourceConnection: ConnectionSource?; let isSelected: Bool; let zoomScale: CGFloat; let worldToViewport: (CGPoint) -> CGPoint; let onMoveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void; let onDelete: () -> Void; let isStopSignSelected: Bool
    var body: some View {
        CanvasNodeView(node: $node, project: $project, sourceConnection: $sourceConnection, onMoveMiniNodeToMain: onMoveMiniNodeToMain, isStopSignSelected: isStopSignSelected)
            .frame(width: canvasNodeSize(node, project: project).width, height: canvasNodeSize(node, project: project).height)
            .overlay(alignment: .topTrailing) { if isSelected { Button(action: onDelete) { Circle().fill(Color.red).frame(width: 30, height: 30).overlay { Image(systemName: "minus").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) } }.offset(x: 12, y: -12) } }
            .overlay { if node.type != .choices { let side = bestExitSide(); let size = canvasNodeSize(node, project: project); pathMakingButton(side: side).offset(x: side == .left ? -size.width/2 - 25 : (side == .right ? size.width/2 + 25 : 0), y: side == .top ? -size.height/2 - 25 : (side == .bottom ? size.height/2 + 25 : 0)) } }
    }
    private func bestExitSide() -> ConnectionSide {
        if let targetID = node.targetNodeIDs.last, let actIdx = project.acts.firstIndex(where: { $0.id == project.currentActID }), let targetNode = project.acts[actIdx].canvasNodes.first(where: { $0.id == targetID }) {
            let dx = targetNode.position.x - node.position.x; let dy = targetNode.position.y - node.position.y
            return abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .bottom : .top)
        }
        return .right
    }
    private func pathMakingButton(side: ConnectionSide) -> some View {
        Button { if sourceConnection?.nodeID == node.id && sourceConnection?.choiceID == nil { sourceConnection = nil } else { sourceConnection = ConnectionSource(nodeID: node.id, choiceID: nil) } } label: {
            Circle().fill((sourceConnection?.nodeID == node.id && sourceConnection?.choiceID == nil) ? Color.green.opacity(0.4) : Color.white).frame(width: 44, height: 44).overlay { Circle().stroke(Color.black.opacity(0.15), lineWidth: 1); Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.black.opacity(0.7)).rotationEffect(side == .top ? .degrees(-90) : (side == .bottom ? .degrees(90) : (side == .left ? .degrees(180) : .degrees(0)))) }.shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        }.buttonStyle(.plain)
    }
}

struct MainCanvasNodeLoop: View {
    @Binding var project: Project; @Binding var selectedMainNodeID: UUID?; @Binding var sourceConnection: ConnectionSource?; @Binding var selectedConnectionID: ConnectionID?; @Binding var movingMainNodeID: UUID?; @Binding var movingMainStartPosition: CGPoint; @Binding var resizingLocationNodeID: UUID?; let zoomScale: CGFloat; let worldToViewport: (CGPoint) -> CGPoint; let isAnyMiniCanvasInEditMode: () -> Bool; let clearMiniEditModes: () -> Void; let moveMiniNodeToMain: (UUID, CanvasNode, CGPoint) -> Void; let onDeleteNode: (UUID) -> Void; let miniCanvasWorldFrame: (CanvasNode) -> CGRect?; let moveMainNodeIntoMiniCanvasIfNeeded: (UUID) -> Bool; let nearestFreeWorldPosition: (CGPoint, CGSize, [CanvasNode]) -> CGPoint; let locationResizeHandle: (Binding<CanvasNode>) -> AnyView; let isStopSignSelected: Bool
    private var currentActIndex: Int { project.acts.firstIndex(where: { $0.id == project.currentActID }) ?? 0 }
    
    private var currentConnectionColor: ColorData? {
        if isStopSignSelected { return nil }
        return project.characters.first?.connectionColor
    }
    private var currentActNodes: Binding<[CanvasNode]> {
        if let index = project.acts.firstIndex(where: { $0.id == project.currentActID }) { return $project.acts[index].canvasNodes }
        else if !project.acts.isEmpty { return $project.acts[0].canvasNodes }
        else { return .constant([]) }
    }
    var body: some View {
        let nodes = project.acts[currentActIndex].canvasNodes
        ZStack {
            ForEach(nodes) { node in
                ForEach(node.targetNodeIDs, id: \.self) { targetID in if let targetNode = nodes.first(where: { $0.id == targetID }) { renderConnection(fromNode: node, fromChoice: nil, toNode: targetNode) } }
                if node.type == .choices, let choicesData = node.choicesData { ForEach(choicesData.options) { option in if let targetID = option.targetNodeID, let targetNode = nodes.first(where: { $0.id == targetID }) { renderConnection(fromNode: node, fromChoice: option, toNode: targetNode) } } }
            }
            ForEach(currentActNodes) { $node in nodeView(for: $node) }
        }
    }
    @ViewBuilder private func renderConnection(fromNode: CanvasNode, fromChoice: ChoiceOption?, toNode: CanvasNode) -> some View {
        let sourceRect = rectCentered(at: fromNode.position, size: canvasNodeSize(fromNode, project: project))
        let targetRect = rectCentered(at: toNode.position, size: canvasNodeSize(toNode, project: project))
        let connectionInfo = bestConnectionPoints(from: sourceRect, to: targetRect, fromChoice: fromChoice, fromNode: fromNode)
        let fromPoint = worldToViewport(connectionInfo.from); let toPoint = worldToViewport(connectionInfo.to)
        let obstacles = project.acts[currentActIndex].canvasNodes.filter { $0.id != toNode.id }.map { rectCentered(at: $0.position, size: canvasNodeSize($0, project: project)).insetBy(dx: -5, dy: -5) }
        let connectionID = ConnectionID(sourceID: fromNode.id, choiceID: fromChoice?.id, targetID: toNode.id)
        
        let connectionData = fromChoice != nil ? fromChoice?.target : fromNode.connections.first(where: { $0.targetNodeID == toNode.id })
        let pathColor = connectionData?.color?.color ?? .black.opacity(0.6)
        
        ConnectionLineView(
            from: fromPoint,
            to: toPoint,
            fromSide: connectionInfo.fromSide,
            toSide: connectionInfo.toSide,
            obstacles: obstacles.map { r in
                let tl = worldToViewport(CGPoint(x: r.minX, y: r.minY))
                let br = worldToViewport(CGPoint(x: r.maxX, y: r.maxY))
                return CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
            },
            isSelected: selectedConnectionID == connectionID,
            onTap: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedConnectionID = connectionID
                    selectedMainNodeID = nil
                }
            },
            onDelete: {
                deleteConnection(connectionID)
            },
            color: pathColor
        )
    }
    private func bestConnectionPoints(from: CGRect, to: CGRect, fromChoice: ChoiceOption?, fromNode: CanvasNode) -> (from: CGPoint, to: CGPoint, fromSide: ConnectionSide, toSide: ConnectionSide) {
        let fromPoint: CGPoint
        let fromSide: ConnectionSide
        if let choice = fromChoice {
            fromPoint = choiceWorldPosition(node: fromNode, choiceID: choice.id, project: project)
            fromSide = (fromNode.choicesData?.isCollapsed ?? false) ? .bottom : .right
        } else {
            let dx = to.midX - from.midX; let dy = to.midY - from.midY
            if abs(dx) > abs(dy) {
                if dx > 0 { fromPoint = CGPoint(x: from.maxX + 25, y: from.midY); fromSide = .right }
                else { fromPoint = CGPoint(x: from.minX - 25, y: from.midY); fromSide = .left }
            } else {
                if dy > 0 { fromPoint = CGPoint(x: from.midX, y: from.maxY + 25); fromSide = .bottom }
                else { fromPoint = CGPoint(x: from.midX, y: from.minY - 25); fromSide = .top }
            }
        }
        let dx = to.midX - fromPoint.x; let dy = to.midY - fromPoint.y; var toPoint: CGPoint; var toSide: ConnectionSide
        if abs(dx) > abs(dy) { if dx > 0 { toPoint = CGPoint(x: to.minX, y: to.midY); toSide = .left } else { toPoint = CGPoint(x: to.maxX, y: to.midY); toSide = .right } }
        else { if dy > 0 { toPoint = CGPoint(x: to.midX, y: to.minY); toSide = .top } else { toPoint = CGPoint(x: to.midX, y: to.maxY); toSide = .bottom } }
        return (fromPoint, toPoint, fromSide, toSide)
    }
    private func deleteConnection(_ conn: ConnectionID) {
        if let idx = project.acts[currentActIndex].canvasNodes.firstIndex(where: { $0.id == conn.sourceID }) {
            if let cid = conn.choiceID, var data = project.acts[currentActIndex].canvasNodes[idx].choicesData, let cIdx = data.options.firstIndex(where: { $0.id == cid }) { data.options[cIdx].targetNodeID = nil; project.acts[currentActIndex].canvasNodes[idx].choicesData = data }
            else { project.acts[currentActIndex].canvasNodes[idx].targetNodeIDs.removeAll { $0 == conn.targetID } }
            selectedConnectionID = nil
        }
    }
    private func choiceWorldPosition(node: CanvasNode, choiceID: UUID, project: Project) -> CGPoint {
        guard let data = node.choicesData, let idx = data.options.firstIndex(where: { $0.id == choiceID }) else { return node.position }
        let cardSize = canvasNodeSize(node, project: project)
        if !data.isCollapsed {
            let tLines = AlphaLogic.lineCount(for: data.title, font: ChoiceCardLayout.titleFont, measureWidth: ChoiceCardLayout.titleMeasureWidth); let tH = max(52, AlphaLogic.steppedHeight(base: ChoiceCardLayout.titleBaseHeight, increment: ChoiceCardLayout.titleLineIncrement, lineCount: tLines))
            var curY = node.position.y - cardSize.height/2 + 12 + tH + 10
            for i in 0..<idx { let opt = data.options[i]; let lC = AlphaLogic.lineCount(for: opt.description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth); curY += AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: lC) + 10 }
            let thisLC = AlphaLogic.lineCount(for: data.options[idx].description, font: ChoiceCardLayout.descriptionFont, measureWidth: ChoiceCardLayout.descriptionMeasureWidth)
            return CGPoint(x: node.position.x + ChoiceCardLayout.cardWidth/2 + 25 + 28, y: curY + AlphaLogic.steppedHeight(base: ChoiceCardLayout.descriptionBaseHeight, increment: ChoiceCardLayout.descriptionLineIncrement, lineCount: thisLC)/2)
        } else {
            let maxBtns = ChoiceCardLayout.maxBtnsPerRow; let rowIdx = idx / maxBtns; let colIdx = idx % maxBtns
            let btnS: CGFloat = 56; let sp: CGFloat = 4; let numRows = (data.options.count + maxBtns - 1) / maxBtns
            let rowCount = (rowIdx == numRows - 1) ? (data.options.count % maxBtns == 0 ? maxBtns : data.options.count % maxBtns) : maxBtns
            let rowWidth = CGFloat(rowCount) * btnS + CGFloat(rowCount - 1) * sp
            let posX = node.position.x - rowWidth/2 + btnS/2 + CGFloat(colIdx) * (btnS + sp)
            return CGPoint(x: posX, y: node.position.y + cardSize.height/2 + 15)
        }
    }
    @ViewBuilder private func nodeView(for node: Binding<CanvasNode>) -> some View {
        CanvasNodeContainer(node: node, project: $project, sourceConnection: $sourceConnection, isSelected: selectedMainNodeID == node.wrappedValue.id, zoomScale: zoomScale, worldToViewport: worldToViewport, onMoveMiniNodeToMain: moveMiniNodeToMain, onDelete: { onDeleteNode(node.wrappedValue.id) }, isStopSignSelected: isStopSignSelected)
            .overlay(alignment: .bottomTrailing) { if selectedMainNodeID == node.wrappedValue.id, node.wrappedValue.type == .location { locationResizeHandle(node).offset(x: -8, y: -8) } }
            .scaleEffect(zoomScale, anchor: .center).position(worldToViewport(node.wrappedValue.position))
            .onTapGesture {
                if let src = sourceConnection, src.nodeID != node.wrappedValue.id {
                    let idx = currentActIndex; if let sIdx = project.acts[idx].canvasNodes.firstIndex(where: { $0.id == src.nodeID }) {
                        if let cid = src.choiceID, var d = project.acts[idx].canvasNodes[sIdx].choicesData, let cIdx = d.options.firstIndex(where: { $0.id == cid }) { 
                            d.options[cIdx].target = ConnectionData(targetNodeID: node.wrappedValue.id, color: currentConnectionColor)
                            project.acts[idx].canvasNodes[sIdx].choicesData = d 
                        } else if !project.acts[idx].canvasNodes[sIdx].connections.contains(where: { $0.targetNodeID == node.wrappedValue.id }) {
                            project.acts[idx].canvasNodes[sIdx].connections.append(ConnectionData(targetNodeID: node.wrappedValue.id, color: currentConnectionColor))
                        }
                        sourceConnection = nil
                    }
                }
            }
            .onLongPressGesture(minimumDuration: 0.35) { withAnimation(.easeInOut(duration: 0.15)) { guard !isAnyMiniCanvasInEditMode() else { return }; clearMiniEditModes(); selectedMainNodeID = node.wrappedValue.id } }
            .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { value in handleDragChanged(value: value, node: node) }.onEnded { _ in handleDragEnded(node: node) })
    }
    private func handleDragChanged(value: DragGesture.Value, node: Binding<CanvasNode>) {
        guard selectedMainNodeID == node.wrappedValue.id, resizingLocationNodeID != node.wrappedValue.id, !isAnyMiniCanvasInEditMode() else { return }
        if movingMainNodeID != node.wrappedValue.id { movingMainStartPosition = node.wrappedValue.position; movingMainNodeID = node.wrappedValue.id }
        let newPos = CGPoint(x: movingMainStartPosition.x + (value.translation.width / zoomScale), y: movingMainStartPosition.y + (value.translation.height / zoomScale)); node.wrappedValue.position = newPos
        let actIdx = currentActIndex; for i in project.acts[actIdx].canvasNodes.indices { if project.acts[actIdx].canvasNodes[i].type == .location && project.acts[actIdx].canvasNodes[i].id != node.wrappedValue.id, let frame = miniCanvasWorldFrame(project.acts[actIdx].canvasNodes[i]) { project.acts[actIdx].canvasNodes[i].locationData?.isMiniCanvasTargeted = frame.contains(newPos) } }
    }
    private func handleDragEnded(node: Binding<CanvasNode>) {
        guard selectedMainNodeID == node.wrappedValue.id, resizingLocationNodeID != node.wrappedValue.id else { return }
        let actIdx = currentActIndex; for i in project.acts[actIdx].canvasNodes.indices { project.acts[actIdx].canvasNodes[i].locationData?.isMiniCanvasTargeted = false }
        if moveMainNodeIntoMiniCanvasIfNeeded(node.wrappedValue.id) { movingMainNodeID = nil; return }
        node.wrappedValue.position = nearestFreeWorldPosition(node.wrappedValue.position, canvasNodeSize(node.wrappedValue, project: project), project.acts[actIdx].canvasNodes.filter { $0.id != node.wrappedValue.id }); movingMainNodeID = nil
    }
}

struct ConnectionLineView: View {
    let from: CGPoint
    let to: CGPoint
    let fromSide: ConnectionSide
    let toSide: ConnectionSide
    let obstacles: [CGRect]
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let color: Color
    var body: some View {
        let pathPoints = OrthogonalPathFinder.findPath(from: from, to: to, fromSide: fromSide, toSide: toSide, obstacles: obstacles)
        let midIndex = pathPoints.count / 2; let midPoint = pathPoints.count > 1 ? CGPoint(x: (pathPoints[midIndex-1].x + pathPoints[midIndex].x)/2, y: (pathPoints[midIndex-1].y + pathPoints[midIndex].y)/2) : from
        ZStack {
            Path { path in if let f = pathPoints.first { path.move(to: f); for i in 1..<pathPoints.count { path.addLine(to: pathPoints[i]) } } }.stroke(Color.black.opacity(0.001), lineWidth: 24).onTapGesture { onTap() }
            Path { path in if let f = pathPoints.first { path.move(to: f); for i in 1..<pathPoints.count { path.addLine(to: pathPoints[i]) } } }.stroke(isSelected ? Color.blue : color, lineWidth: 3)
            if pathPoints.count >= 2 { ArrowHead(from: pathPoints[pathPoints.count-2], to: pathPoints.last!).fill(isSelected ? Color.blue : color) }
            if isSelected { Button(action: onDelete) { Circle().fill(Color.red).frame(width: 32, height: 32).overlay { Image(systemName: "trash.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) }.shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2) }.buttonStyle(.plain).position(midPoint) }
        }
    }
}

struct ArrowHead: Shape {
    let from: CGPoint; let to: CGPoint
    func path(in rect: CGRect) -> Path {
        var path = Path(); let headL: CGFloat = 15; let headA: CGFloat = .pi / 6; let dist = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        guard dist > 0.1 else { return path }; let angle = atan2(to.y - from.y, to.x - from.x)
        path.move(to: to); path.addLine(to: CGPoint(x: to.x - headL * cos(angle - headA), y: to.y - headL * sin(angle - headA))); path.addLine(to: CGPoint(x: to.x - headL * cos(angle + headA), y: to.y - headL * sin(angle + headA))); path.closeSubpath(); return path
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}
