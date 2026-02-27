import SwiftUI

struct CharacterCardView: View {
    @Binding var character: StoryCharacter
    var onEditTap: () -> Void
    var onSwipeUp: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemGray5))
            .overlay {
                VStack(spacing: 12) {
                    TextField("Character Name", text: $character.name)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    Spacer()

                    AvatarFigureView(
                        avatar: character.avatar,
                        maleHairStyle: character.maleHairStyle,
                        upperClothStyle: character.upperClothStyle,
                        skinToneIndex: character.skinToneIndex,
                        bodyHeight: 165,
                        hairSize: 50,
                        hairOffsetY: -63
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    HStack {
                        Picker("Gender", selection: $character.avatar) {
                            Text("Male").tag(AvatarType.man)
                            Text("Female").tag(AvatarType.woman)
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
