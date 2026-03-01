import SwiftUI

struct AvatarFigureView: View {
    let character: StoryCharacter
    var bodyHeight: CGFloat = 220
    var hairSize: CGFloat = 67
    var hairOffsetY: CGFloat = -87

    static let skinTonePalette: [Color] = [
        Color(red: 0.90, green: 0.80, blue: 0.66),
        Color(red: 0.84, green: 0.65, blue: 0.49), 
        Color(red: 0.84, green: 0.74, blue: 0.65),
        Color(red: 0.64, green: 0.39, blue: 0.32),
        Color(red: 0.88, green: 0.65, blue: 0.52),
        Color(red: 0.74, green: 0.58, blue: 0.43),
        Color(red: 0.62, green: 0.38, blue: 0.26),
        Color(red: 0.45, green: 0.26, blue: 0.18)
    ]

    var body: some View {
        ZStack {
            if let customData = character.customImages[character.avatar], let uiImage = UIImage(data: customData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: bodyHeight)
            } else if let assetName = character.selectedAsset {
                Image(assetName, bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(height: bodyHeight)
            } else {
                if character.avatar == .man {
                    Image("Male ", bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(height: bodyHeight)
                        .colorMultiply(Self.skinTonePalette[safe: character.skinToneIndex] ?? Self.skinTonePalette[0])

                    if let upperClothAssetName = character.upperClothStyle.assetImageName {
                        Image(upperClothAssetName, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(height: bodyHeight * 0.40)
                            .offset(y: -bodyHeight * 0.16)
                    }

                    if let hairAssetName = character.maleHairStyle.assetImageName {
                        Image(hairAssetName, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(width: hairSize, height: hairSize)
                            .offset(y: hairOffsetY)
                    }
                } else if character.avatar != .unknown {
                    Image(systemName: character.avatar.systemImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: bodyHeight * 0.55)
                        .foregroundStyle(Color(.systemGray2))
                } else {
                    // Empty for unknown
                    Color.clear
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
