import SwiftUI

struct CharacterIconView: View {
    let character: StoryCharacter; let size: CGFloat
    var body: some View {
        ZStack {
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
            
            // Corner tag with unique character color
            CornerTag()
                .fill(character.assignedColor.color)
                .frame(width: size * 0.45, height: size * 0.45)
                .position(x: size * 0.775, y: size * 0.225)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
    var body: some View {
        CharacterIconView(character: character, size: 56)
    }
}
