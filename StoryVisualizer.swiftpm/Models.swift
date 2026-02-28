import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let storyCharacter = UTType.data
}

extension UUID: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .storyCharacter)
    }
}

struct Project: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var characters: [StoryCharacter] = [
        StoryCharacter(name: "Character 1", avatar: .woman)
    ]
    var acts: [Act] = [Act(name: "Act 1")]
    var currentActID: UUID?

    init(name: String) {
        self.name = name
        self.currentActID = acts.first?.id
    }
}

struct Act: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
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
    var propData: PropCardData?
    var eventData: EventCardData?
}

enum CanvasNodeType: String, Identifiable, CaseIterable, Codable, Equatable {
    case location
    case choices
    case prop
    case event

    var id: String { rawValue }
}

struct EventCardData: Codable, Equatable {
    var title: String
    var involvedCharacterIDs: [UUID]
    var subEvents: [SubEvent]

    static var defaultData: EventCardData {
        EventCardData(
            title: "",
            involvedCharacterIDs: [],
            subEvents: [SubEvent(description: "")]
        )
    }
}

struct SubEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var description: String
    var characterIDs: [UUID] = []
}

struct LocationCardData: Codable, Equatable {
    var title: String
    var backgroundImageData: Data?
    var miniNodes: [CanvasNode]
    var isMiniCanvasTargeted: Bool
    var isMiniEditing: Bool
    var selectedMiniNodeID: UUID?
    var pinnedMiniCanvasHeight: CGFloat
    var pinnedMiniCanvasWidth: CGFloat
    
    init(
        title: String,
        backgroundImageData: Data?,
        miniNodes: [CanvasNode],
        isMiniCanvasTargeted: Bool,
        isMiniEditing: Bool,
        selectedMiniNodeID: UUID?,
        pinnedMiniCanvasHeight: CGFloat,
        pinnedMiniCanvasWidth: CGFloat
    ) {
        self.title = title
        self.backgroundImageData = backgroundImageData
        self.miniNodes = miniNodes
        self.isMiniCanvasTargeted = isMiniCanvasTargeted
        self.isMiniEditing = isMiniEditing
        self.selectedMiniNodeID = selectedMiniNodeID
        self.pinnedMiniCanvasHeight = pinnedMiniCanvasHeight
        self.pinnedMiniCanvasWidth = pinnedMiniCanvasWidth
    }
    
    private enum CodingKeys: String, CodingKey {
        case title
        case backgroundImageData
        case miniNodes
        case isMiniCanvasTargeted
        case isMiniEditing
        case selectedMiniNodeID
        case pinnedMiniCanvasHeight
        case pinnedMiniCanvasWidth
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        backgroundImageData = try container.decodeIfPresent(Data.self, forKey: .backgroundImageData)
        miniNodes = try container.decodeIfPresent([CanvasNode].self, forKey: .miniNodes) ?? []
        isMiniCanvasTargeted = try container.decodeIfPresent(Bool.self, forKey: .isMiniCanvasTargeted) ?? false
        isMiniEditing = try container.decodeIfPresent(Bool.self, forKey: .isMiniEditing) ?? false
        selectedMiniNodeID = try container.decodeIfPresent(UUID.self, forKey: .selectedMiniNodeID)
        pinnedMiniCanvasHeight = try container.decodeIfPresent(CGFloat.self, forKey: .pinnedMiniCanvasHeight) ?? 250
        pinnedMiniCanvasWidth = try container.decodeIfPresent(CGFloat.self, forKey: .pinnedMiniCanvasWidth) ?? 410
    }

    static var defaultData: LocationCardData {
        LocationCardData(
            title: "",
            backgroundImageData: nil,
            miniNodes: [],
            isMiniCanvasTargeted: false,
            isMiniEditing: false,
            selectedMiniNodeID: nil,
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

struct PropCardData: Codable, Equatable {
    var title: String
    var imageData: Data?
    var description: String

    static var defaultData: PropCardData {
        PropCardData(
            title: "",
            imageData: nil,
            description: ""
        )
    }
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
