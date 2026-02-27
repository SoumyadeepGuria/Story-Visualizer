import SwiftUI

struct CharacterEditView: View {
    @Binding var character: StoryCharacter
    @Environment(\.dismiss) private var dismiss
    @State private var section: EditSection = .body
    @State private var selectedHairToneIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray5))
                        .frame(height: 410)
                        .overlay {
                            VStack(spacing: 16) {
                                AvatarFigureView(
                                    avatar: character.avatar,
                                    maleHairStyle: character.maleHairStyle,
                                    upperClothStyle: character.upperClothStyle,
                                    skinToneIndex: character.skinToneIndex,
                                    bodyHeight: 260,
                                    hairSize: 72,
                                    hairOffsetY: -101
                                )

                                Picker("Section", selection: $section) {
                                    Text("Body").tag(EditSection.body)
                                    Text("Clothes").tag(EditSection.clothes)
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }

                    if section == .body {
                        Text("Skin Tone")
                            .font(.title3.weight(.medium))
                        toneRow(
                            selectedIndex: $character.skinToneIndex,
                            palette: AvatarFigureView.skinTonePalette
                        )

                        Text("Hair")
                            .font(.title3.weight(.medium))
                        toneRow(
                            selectedIndex: $selectedHairToneIndex,
                            palette: AvatarFigureView.skinTonePalette
                        )

                        if character.avatar == .man {
                            hairSelectionRow
                        }
                    } else {
                        Text("Upper Clothes")
                            .font(.title3.weight(.medium))

                        HStack(spacing: 14) {
                            upperClothOptionTile(style: .style1)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGray6))
            .navigationTitle("Edit Character")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var hairSelectionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                hairOptionTile(style: .style1)
                hairOptionTile(style: .style2)
                hairOptionTile(style: .style3)
                hairOptionTile(style: .style4)
                hairOptionTile(style: .style5)
            }
        }
    }

    private func hairOptionTile(style: MaleHairStyle) -> some View {
        Button {
            character.maleHairStyle = style
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(height: 100)
                .overlay {
                    if let hairAssetName = style.assetImageName {
                        Image(hairAssetName, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 70)
                    } else {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(character.maleHairStyle == style ? Color.blue : Color.clear, lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 120)
    }

    private func upperClothOptionTile(style: UpperClothStyle) -> some View {
        Button {
            character.upperClothStyle = style
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(height: 120)
                .overlay {
                    if let clothAssetName = style.assetImageName {
                        Image(clothAssetName, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(character.upperClothStyle == style ? Color.blue : Color.clear, lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 150)
    }

    private func toneRow(selectedIndex: Binding<Int>, palette: [Color]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(palette.enumerated()), id: \.offset) { index, swatch in
                Button {
                    selectedIndex.wrappedValue = index
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(swatch)
                        .frame(width: 56, height: 56)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedIndex.wrappedValue == index ? Color.blue : Color.clear, lineWidth: 3)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum EditSection: String, Identifiable {
    case body
    case clothes

    var id: String { rawValue }
}
