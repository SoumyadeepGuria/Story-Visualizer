import SwiftUI

struct AvatarFigureView: View {
    let avatar: AvatarType
    let maleHairStyle: MaleHairStyle
    let upperClothStyle: UpperClothStyle
    var skinToneIndex: Int = 0
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
            if avatar == .man {
                Image("Male ", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(height: bodyHeight)
                    .colorMultiply(Self.skinTonePalette[safe: skinToneIndex] ?? Self.skinTonePalette[0])

                if let upperClothAssetName = upperClothStyle.assetImageName {
                    Image(upperClothAssetName, bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(height: bodyHeight * 0.40)
                        .offset(y: -bodyHeight * 0.16)
                }

                if let hairAssetName = maleHairStyle.assetImageName {
                    Image(hairAssetName, bundle: .module)
                        .resizable()
                        .scaledToFit()
                        .frame(width: hairSize, height: hairSize)
                        .offset(y: hairOffsetY)
                }
            } else {
                Image(systemName: avatar.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: bodyHeight * 0.55)
                    .foregroundStyle(Color(.systemGray2))
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
