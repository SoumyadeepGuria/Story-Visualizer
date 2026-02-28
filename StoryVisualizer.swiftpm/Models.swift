import Foundation
import SwiftUI

struct Project: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var characters: [StoryCharacter] = [
        StoryCharacter(name: "Character 1", avatar: .woman)
    ]
    var canvasNodes: [CanvasNode] = []
}

struct StoryCharacter: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var avatar: AvatarType
    var maleHairStyle: MaleHairStyle = .none
    var upperClothStyle: UpperClothStyle = .style1
    var skinToneIndex: Int = 0
}

enum MaleHairStyle: String, CaseIterable, Identifiable, Codable, Equatable {
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

enum UpperClothStyle: String, CaseIterable, Identifiable, Codable, Equatable {
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

enum AvatarType: String, CaseIterable, Identifiable, Codable, Equatable {
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

struct CanvasNode: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: CanvasNodeType
    var position: CGPoint
    var choicesData: ChoicesCardData?
    var locationData: LocationCardData?
}

enum CanvasNodeType: String, Identifiable, CaseIterable, Codable, Equatable {
    case location
    case choices
    case prop
    case event

    var id: String { rawValue }
}

struct LocationCardData: Codable, Equatable {
    var title: String
    var backgroundImageData: Data?
    var miniNodes: [CanvasNode]
    var isMiniCanvasTargeted: Bool
    var pinnedMiniCanvasHeight: CGFloat
    var pinnedMiniCanvasWidth: CGFloat

    static var defaultData: LocationCardData {
        LocationCardData(
            title: "",
            backgroundImageData: nil,
            miniNodes: [],
            isMiniCanvasTargeted: false,
            pinnedMiniCanvasHeight: 250,
            pinnedMiniCanvasWidth: 410
        )
    }
}

struct ChoicesCardData: Codable, Equatable {
    var title: String
    var options: [ChoiceOption]
    var isCollapsed: Bool

    static var defaultData: ChoicesCardData {
        ChoicesCardData(
            title: "",
            options: [
                ChoiceOption(label: "1", description: "")
            ],
            isCollapsed: false
        )
    }
}

struct ChoiceOption: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var description: String
}

extension CanvasNodeType {
    static var toolbarOrder: [CanvasNodeType] {
        [.location, .choices, .prop, .event]
    }

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .choices:
            return "Choices"
        case .prop:
            return "Prop"
        case .event:
            return "Event"
        }
    }

    var fillColor: Color {
        switch self {
        case .location:
            return Color.yellow.opacity(0.34)
        case .choices:
            return Color.cyan.opacity(0.38)
        case .prop:
            return Color.green.opacity(0.34)
        case .event:
            return Color.red.opacity(0.30)
        }
    }

    var borderColor: Color {
        switch self {
        case .location:
            return Color.orange
        case .choices:
            return Color.cyan
        case .prop:
            return Color.green
        case .event:
            return Color.red
        }
    }
}
