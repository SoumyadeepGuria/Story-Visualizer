import SwiftUI

struct CharacterSetupView: View {
    @Binding var project: Project
    @State private var editingCharacterID: UUID?
    @State private var pendingRemovalCharacter: PendingCharacterRemoval?

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var characterColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isPad ? 210 : 160), spacing: 12, alignment: .top)]
    }

    private var characterCountBinding: Binding<Int> {
        Binding(
            get: { project.characters.count },
            set: { newValue in
                let target = max(0, newValue)
                syncCharacterCount(target)
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Number of Characters")
                        .font(.system(size: isPad ? 40 : 30, weight: .bold))
                    Spacer()
                }

                HStack(spacing: 12) {
                    TextField("0", value: characterCountBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: isPad ? 84 : 70)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)

                    Stepper("", value: characterCountBinding, in: 0...30, step: 1)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                LazyVGrid(columns: characterColumns, spacing: 12) {
                    ForEach(project.characters.indices, id: \.self) { index in
                        // Passing the binding to a dedicated child view stops the "Type-check" timeout
                        GridCharacterItem(
                            character: $project.characters[index],
                            isPad: isPad,
                            onEdit: { editingCharacterID = project.characters[index].id },
                            onRemove: {
                                pendingRemovalCharacter = PendingCharacterRemoval(
                                    id: project.characters[index].id,
                                    name: project.characters[index].name
                                )
                            }
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGray6))
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    StoryCanvasView(project: $project)
                } label: {
                    Text("Canvas")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(
            isPresented: Binding(
                get: { editingCharacterID != nil },
                set: { if !$0 { editingCharacterID = nil } }
            )
        ) {
            if let characterID = editingCharacterID,
               let characterIndex = project.characters.firstIndex(where: { $0.id == characterID }) {
                CharacterEditView(character: $project.characters[characterIndex])
            }
        }
        .alert(item: $pendingRemovalCharacter) { pending in
            Alert(
                title: Text("Remove Character"),
                message: Text("Remove \(pending.name) from this project?"),
                primaryButton: .destructive(Text("Remove")) {
                    removeCharacter(withID: pending.id)
                },
                secondaryButton: .cancel(Text("Keep"))
            )
        }
    }

    private func syncCharacterCount(_ targetCount: Int) {
        if project.characters.count < targetCount {
            let current = project.characters.count
            let newCharacters = (current..<targetCount).map { index in
                StoryCharacter(
                    name: "Character \(index + 1)",
                    avatar: .unknown
                )
            }
            project.characters.append(contentsOf: newCharacters)
        } else if project.characters.count > targetCount {
            project.characters = Array(project.characters.prefix(targetCount))
        }
    }

    private func removeCharacter(withID characterID: UUID) {
        project.characters.removeAll { $0.id == characterID }
    }
}

private struct PendingCharacterRemoval: Identifiable {
    let id: UUID
    let name: String
}

struct GridCharacterItem: View {
    @Binding var character: StoryCharacter
    let isPad: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        CharacterCardView(character: $character) {
            onEdit()
        } onSwipeUp: {
            onRemove()
        }
        .frame(height: isPad ? 340 : 290)
    }
}
