import SwiftUI

struct CharacterCardView: View {
    @Binding var character: StoryCharacter
    var onEditTap: () -> Void
    var onSwipeUp: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(character.role.color.opacity(0.5))
            .animation(.easeInOut, value: character.role)
            .overlay {
                VStack(spacing: 12) {
                    HStack {
                        // Spacer to balance the name title
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 20, height: 20)
                        
                        TextField("Character Name", text: $character.name)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.plain)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Circle()
                            .fill(character.assignedColor.color)
                            .opacity(1.0)
                            .frame(width: 16, height: 16)
                            .shadow(radius: 1)
                    }
                    .padding(.top, 12)

                    Spacer()

                    AvatarFigureView(
                        character: character,
                        bodyHeight: 165,
                        hairSize: 50,
                        hairOffsetY: -63
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    HStack {
                        Picker("Type", selection: Binding(
                            get: { character.avatar },
                            set: { newType in
                                character.avatar = newType
                                // Set defaults when section changes
                                switch newType {
                                case .man:
                                    character.selectedAsset = "Male"
                                case .woman:
                                    character.selectedAsset = "Female"
                                case .animal:
                                    character.selectedAsset = "Dog"
                                case .unknown:
                                    character.selectedAsset = nil
                                }
                            }
                        )) {
                            ForEach(AvatarType.allCases) { type in
                                Image(systemName: type.systemImageName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Spacer()

                        Button(action: onEditTap) {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "pencil")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let isUpwardSwipe = value.translation.height < -60
                        let mostlyVertical = abs(value.translation.width) < 80
                        if isUpwardSwipe && mostlyVertical {
                            onSwipeUp()
                        }
                    }
            )
    }
}
