import SwiftUI

struct CharacterIconView: View {
    let character: StoryCharacter; let size: CGFloat
    var isInspected: Bool = false
    var onDoubleTap: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            // ... (rest of the ZStack content)
            // Main background with role-colored outline
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(character.role.color)
                .frame(width: size, height: size)
            
            // Inner content box (white box from screenshot)
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(Color(.systemGray6))
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay {
                    AvatarFigureView(character: character, bodyHeight: size * 3.0, hairSize: size * 0.8, hairOffsetY: -size * 1.1)
                        .offset(y: size * 1.0)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
            
            // Corner tag with unique character color (Top Right)
            CornerTag()
                .fill(character.assignedColor.color)
                .frame(width: size * 0.45, height: size * 0.45)
                .position(x: size * 0.775, y: size * 0.225)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(alignment: .trailing) {
            if isInspected {
                TooltipView(text: character.name, color: character.assignedColor.color)
                    .offset(x: size * 1.0 + 8) // Move it fully outside the icon with 8pt spacing
            }
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
    }
}

struct TooltipView: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 0) {
            // Triangle pointer
            Triangle()
                .fill(color)
                .frame(width: 8, height: 10)
                .rotationEffect(.degrees(-90))
            
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(color))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .fixedSize()
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CornerTag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Elongated curve to cover more of the inner box
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.maxY * 0.7))
        path.closeSubpath()
        return path
    }
}

struct CharacterSidebarItem: View {
    let character: StoryCharacter
    var isInspected: Bool = false
    var onDoubleTap: (() -> Void)? = nil
    var body: some View {
        CharacterIconView(character: character, size: 56, isInspected: isInspected, onDoubleTap: onDoubleTap)
    }
}
