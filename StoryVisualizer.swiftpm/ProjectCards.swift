import SwiftUI

struct AddProjectCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 52, weight: .regular))
                            .foregroundStyle(Color(.systemGray2))

                        Text("New Project")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create project")
    }
}

struct ProjectCard: View {
    let project: Project

    private var visibleCharacters: [StoryCharacter] {
        Array(project.characters.prefix(4))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .overlay {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ForEach(visibleCharacters) { character in
                            CharacterSnippetBox(character: character)
                                .frame(width: 62, height: 62)
                        }
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .frame(height: 72)

                    Text(project.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(10)
            }
    }
}

private struct CharacterSnippetBox: View {
    let character: StoryCharacter

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray4))
            .overlay {
                GeometryReader { proxy in
                    AvatarFigureView(
                        avatar: character.avatar,
                        maleHairStyle: character.maleHairStyle,
                        upperClothStyle: character.upperClothStyle,
                        skinToneIndex: character.skinToneIndex,
                        bodyHeight: proxy.size.height * 1.9,
                        hairSize: proxy.size.height * 0.78,
                        hairOffsetY: -proxy.size.height * 1.02
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .scaleEffect(1.9, anchor: .top)
                    .offset(y: -4)
                    .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
