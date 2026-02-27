import Foundation

struct Project: Identifiable {
    let id = UUID()
    let name: String
    var characters: [StoryCharacter] = [
        StoryCharacter(name: "Character 1", avatar: .woman)
    ]
}

struct StoryCharacter: Identifiable {
    let id = UUID()
    var name: String
    var avatar: AvatarType
    var maleHairStyle: MaleHairStyle = .none
    var upperClothStyle: UpperClothStyle = .style1
    var skinToneIndex: Int = 0
}

enum MaleHairStyle: String, CaseIterable, Identifiable {
    case none
    case style1
    case style2
    case style3
    case style4
    case style5

    var id: String { rawValue }

    var assetImageName: String? {
        switch self {
        case .none:
            return nil
        case .style1:
            return "MaleHair1"
        case .style2:
            return "MaleHair2"
        case .style3:
            return "MaleHair3"
        case .style4:
            return "MaleHair4"
        case .style5:
            return "MaleHair5"
        }
    }
}

enum UpperClothStyle: String, CaseIterable, Identifiable {
    case none
    case style1

    var id: String { rawValue }

    var assetImageName: String? {
        switch self {
        case .none:
            return nil
        case .style1:
            return "Uppercloth1"
        }
    }
}

enum AvatarType: String, CaseIterable, Identifiable {
    case man
    case woman

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .man:
            return "person.fill"
        case .woman:
            return "person.crop.circle.fill"
        }
    }

    var assetImageName: String? {
        switch self {
        case .man:
            return "Male "
        case .woman:
            return nil
        }
    }

    var label: String {
        switch self {
        case .man:
            return "Male"
        case .woman:
            return "Female"
        }
    }
}
