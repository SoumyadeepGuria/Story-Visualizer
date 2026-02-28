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
                        CanvasNodeView(node: $node)
                            .frame(
                                width: canvasNodeSize(node).width,
                                height: canvasNodeSize(node).height
                            )
                            .scaleEffect(zoomScale, anchor: .center)
                            .position(worldToViewport(node.position))
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
                            collapseChoicesCardsIfNeeded(at: viewportToWorld(value.location))
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
}

private enum CanvasCamera {
    // This is the baseline zoom used on first load and crosshair reset.
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

    var body: some View {
        switch node.type {
        case .location:
            LocationCanvasCard(data: Binding(
                get: { node.locationData ?? .defaultData },
                set: { node.locationData = $0 }
            ))
        case .choices:
            ChoicesCanvasCard(data: Binding(
                get: { node.choicesData ?? .defaultData },
                set: { node.choicesData = $0 }
            ))
        case .prop, .event:
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
        locationData: type == .location ? .defaultData : nil
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
    @Binding var data: LocationCardData
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray4))
            .overlay {
                if let imageData = data.backgroundImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.42))
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(spacing: LocationCardLayout.headerToMiniGap) {
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

                        TextField("Name of location", text: $data.title)
                            .font(.system(size: 24, weight: .regular))
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .frame(height: LocationCardLayout.headerHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                            )
                    }

                    GeometryReader { proxy in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.56))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.25), lineWidth: 1)
                                }

                            ForEach($data.miniNodes) { $miniNode in
                                CanvasNodeView(node: $miniNode)
                                    .frame(
                                        width: canvasNodeSize(miniNode).width,
                                        height: canvasNodeSize(miniNode).height
                                    )
                                    .position(miniNode.position)
                            }
                        }
                        .onAppear {
                            clampMiniNodePositions(to: proxy.size)
                        }
                        .onChange(of: miniNodeLayoutFingerprint) { _ in
                            clampMiniNodePositions(to: proxy.size)
                        }
                        .onChange(of: proxy.size) { newSize in
                            clampMiniNodePositions(to: newSize)
                        }
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { items, location in
                            defer { data.isMiniCanvasTargeted = false }
                            guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else {
                                return false
                            }

                            var node = defaultNode(for: type)
                            let itemSize = canvasNodeSize(node)
                            let placement = placeMiniNodeWithoutOverlap(
                                desired: location,
                                itemSize: itemSize,
                                currentCanvasSize: proxy.size
                            )
                            data.pinnedMiniCanvasWidth = max(data.pinnedMiniCanvasWidth, placement.requiredSize.width)
                            data.pinnedMiniCanvasHeight = max(data.pinnedMiniCanvasHeight, placement.requiredSize.height)
                            node.position = placement.position
                            data.miniNodes.append(node)
                            clampMiniNodePositions(to: placement.requiredSize)
                            return true
                        } isTargeted: { targeted in
                            data.isMiniCanvasTargeted = targeted
                            if targeted {
                                // Commit the live hover-expanded canvas size so the card
                                // does not shrink immediately after drop.
                                data.pinnedMiniCanvasWidth = max(data.pinnedMiniCanvasWidth, proxy.size.width)
                                data.pinnedMiniCanvasHeight = max(data.pinnedMiniCanvasHeight, proxy.size.height)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let imageData = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            data.backgroundImageData = imageData
                        }
                    }
                }
            }
    }

    private var miniNodeLayoutFingerprint: String {
        data.miniNodes.map { node in
            let size = canvasNodeSize(node)
            return "\\(node.id.uuidString):\\(node.position.x):\\(node.position.y):\\(size.width):\\(size.height)"
        }
        .joined(separator: "|")
    }

    private func clampMiniNodePositions(to canvasSize: CGSize) {
        guard !data.miniNodes.isEmpty else { return }
        for index in data.miniNodes.indices {
            let nodeSize = canvasNodeSize(data.miniNodes[index])

            let minX = nodeSize.width / 2 + LocationCardLayout.miniCanvasHorizontalPadding
            let maxX = max(minX, canvasSize.width - nodeSize.width / 2 - LocationCardLayout.miniCanvasHorizontalPadding)

            let minY = nodeSize.height / 2 + LocationCardLayout.miniCanvasVerticalPadding
            let maxY = max(minY, canvasSize.height - nodeSize.height / 2 - LocationCardLayout.miniCanvasVerticalPadding)

            data.miniNodes[index].position = CGPoint(
                x: min(max(data.miniNodes[index].position.x, minX), maxX),
                y: min(max(data.miniNodes[index].position.y, minY), maxY)
            )
        }
    }

    private func placeMiniNodeWithoutOverlap(
        desired: CGPoint,
        itemSize: CGSize,
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
            let overlaps = data.miniNodes.contains { existing in
                let other = rectCentered(at: existing.position, size: canvasNodeSize(existing)).insetBy(dx: -4, dy: -4)
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
    case .prop, .event:
        return CGSize(width: 132, height: 54)
    }
}

private func locationCardSize(_ data: LocationCardData?) -> CGSize {
    guard let data else {
        return CGSize(width: LocationCardLayout.cardWidth, height: LocationCardLayout.defaultCardHeight)
    }

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

    let miniCanvasWidth = max(
        LocationCardLayout.miniCanvasMinWidth,
        data.pinnedMiniCanvasWidth,
        projectedWidth
    )
    let miniCanvasHeight = max(
        LocationCardLayout.miniCanvasMinHeight,
        data.pinnedMiniCanvasHeight,
        projectedHeight
    )

    let totalHeight = LocationCardLayout.outerTopPadding
        + LocationCardLayout.headerHeight
        + LocationCardLayout.headerToMiniGap
        + miniCanvasHeight
        + LocationCardLayout.outerBottomPadding

    let totalWidth = miniCanvasWidth + (LocationCardLayout.outerHorizontalPadding * 2)
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
