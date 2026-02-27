import SwiftUI

struct StoryCanvasView: View {
    let projectName: String

    @State private var canvasNodes: [CanvasNode] = []
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            topRibbon

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray6))
                        .overlay {
                            if isTargeted {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                            }
                        }

                    ForEach(canvasNodes) { node in
                        CanvasNodeView(node: node)
                            .frame(
                                width: node.type == .location ? locationSize(for: node).width : 132,
                                height: node.type == .location ? locationSize(for: node).height : 54
                            )
                            .position(node.position)
                    }
                }
                .contentShape(Rectangle())
                .dropDestination(for: String.self) { items, location in
                    handleDrop(items: items, at: location, canvasSize: proxy.size)
                } isTargeted: { targeted in
                    isTargeted = targeted
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray5))
        .navigationTitle("\(projectName) Canvas")
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

    private func handleDrop(items: [String], at location: CGPoint, canvasSize: CGSize) -> Bool {
        guard let raw = items.first, let type = CanvasNodeType(rawValue: raw) else {
            return false
        }

        if type != .location,
           let locationIndex = canvasNodes.firstIndex(where: { node in
               node.type == .location && locationFrame(for: node).contains(location)
           }) {
            canvasNodes[locationIndex].children.append(type)
            return true
        }

        let size = type == .location ? locationSize(forChildrenCount: 0) : CGSize(width: 132, height: 54)
        let node = CanvasNode(
            type: type,
            position: clamped(location, itemSize: size, canvasSize: canvasSize),
            children: []
        )
        canvasNodes.append(node)
        return true
    }

    private func clamped(_ point: CGPoint, itemSize: CGSize, canvasSize: CGSize) -> CGPoint {
        let x = min(max(point.x, itemSize.width / 2), canvasSize.width - itemSize.width / 2)
        let y = min(max(point.y, itemSize.height / 2), canvasSize.height - itemSize.height / 2)
        return CGPoint(x: x, y: y)
    }

    private func locationSize(for node: CanvasNode) -> CGSize {
        locationSize(forChildrenCount: node.children.count)
    }

    private func locationSize(forChildrenCount count: Int) -> CGSize {
        let rows = max(1, Int(ceil(Double(max(count, 1)) / 2.0)))
        return CGSize(width: 270, height: CGFloat(84 + (rows * 34)))
    }

    private func locationFrame(for node: CanvasNode) -> CGRect {
        let size = locationSize(for: node)
        return CGRect(
            x: node.position.x - size.width / 2,
            y: node.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
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
    let node: CanvasNode

    var body: some View {
        if node.type == .location {
            RoundedRectangle(cornerRadius: 12)
                .fill(node.type.fillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(node.type.borderColor, lineWidth: 2)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(node.type.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(node.type.borderColor)

                        if node.children.isEmpty {
                            Text("Drop Choices / Prop / Event here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(child.fillColor)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(child.borderColor, lineWidth: 1.5)
                                        }
                                        .frame(height: 28)
                                        .overlay {
                                            Text(child.title)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.black.opacity(0.7))
                                        }
                                }
                            }
                        }
                    }
                    .padding(10)
                }
        } else {
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

private struct CanvasNode: Identifiable {
    let id = UUID()
    let type: CanvasNodeType
    var position: CGPoint
    var children: [CanvasNodeType]
}

private enum CanvasNodeType: String, Identifiable, CaseIterable {
    case location
    case choices
    case prop
    case event

    var id: String { rawValue }

    static var toolbarOrder: [CanvasNodeType] {
        [.location, .choices, .prop, .event]
    }

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .choices:
            return "Choices"
        case .prop:
            return "Prop"
        case .event:
            return "Event"
        }
    }

    var fillColor: Color {
        switch self {
        case .location:
            return Color.yellow.opacity(0.34)
        case .choices:
            return Color.cyan.opacity(0.38)
        case .prop:
            return Color.green.opacity(0.34)
        case .event:
            return Color.red.opacity(0.30)
        }
    }

    var borderColor: Color {
        switch self {
        case .location:
            return Color.orange
        case .choices:
            return Color.cyan
        case .prop:
            return Color.green
        case .event:
            return Color.red
        }
    }
}
