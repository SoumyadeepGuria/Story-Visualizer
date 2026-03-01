import SwiftUI
import PhotosUI

struct CharacterEditView: View {
    @Binding var character: StoryCharacter
    var onDone: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem? = nil

    private let maleAssets = [
        CharacterAsset(name: "Male", imageName: "Male"),
        CharacterAsset(name: "Young Male", imageName: "Male_Child"),
        CharacterAsset(name: "Old Male", imageName: "Male_Old"),
        CharacterAsset(name: "Mermaid", imageName: "Male_Mermaid")
    ]
    
    private let femaleAssets = [
        CharacterAsset(name: "Female", imageName: "Female"),
        CharacterAsset(name: "Young Female", imageName: "Female_Child"),
        CharacterAsset(name: "Old Female", imageName: "Female_Old"),
        CharacterAsset(name: "Mermaid", imageName: "Female_Mermaid ")
    ]
    
    private let animalAssets = [
        CharacterAsset(name: "Bat", imageName: "Bat"),
        CharacterAsset(name: "Black Panther", imageName: "Black_Panther"),
        CharacterAsset(name: "Cat", imageName: "Cat"),
        CharacterAsset(name: "Deer", imageName: "deer"),
        CharacterAsset(name: "Dog", imageName: "Dog"),
        CharacterAsset(name: "Elephant", imageName: "Elephant"),
        CharacterAsset(name: "Giraffe", imageName: "Giraffe"),
        CharacterAsset(name: "Hippo", imageName: "Hippo"),
        CharacterAsset(name: "Horse", imageName: "Horse"),
        CharacterAsset(name: "Lion", imageName: "Lion"),
        CharacterAsset(name: "Monkey", imageName: "Monkey"),
        CharacterAsset(name: "Mouse", imageName: "Mouse"),
        CharacterAsset(name: "Tiger", imageName: "Tiger"),
        CharacterAsset(name: "Unicorn", imageName: "Unicorn"),
        CharacterAsset(name: "Zebra", imageName: "Zebra")
    ]
    
    private let birdAssets = [
        CharacterAsset(name: "Chicken", imageName: "Chicken"),
        CharacterAsset(name: "Crow", imageName: "Crow"),
        CharacterAsset(name: "Duck", imageName: "Duck"),
        CharacterAsset(name: "Eagle", imageName: "Eagle"),
        CharacterAsset(name: "Kingfisher", imageName: "Kingfisher"),
        CharacterAsset(name: "Ostrich", imageName: "Ostrich"),
        CharacterAsset(name: "Parrot", imageName: "parrot"),
        CharacterAsset(name: "Peacock", imageName: "Peacock"),
        CharacterAsset(name: "Swallow", imageName: "Swallow")
    ]
    
    private let fishAssets = [
        CharacterAsset(name: "Dolphin", imageName: "Dolphin"),
        CharacterAsset(name: "Fish", imageName: "Fish"),
        CharacterAsset(name: "Shark", imageName: "Shark")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            
                            Menu {
                                Picker("Role", selection: $character.role) {
                                    ForEach(CharacterRole.allCases) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(character.role.rawValue)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(character.role.color.opacity(0.15))
                                .foregroundStyle(character.role.color)
                                .cornerRadius(8)
                            }
                        }
                        
                        Spacer()
                        
                        TextField("Character Name", text: $character.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.bottom, 8)

                    RoundedRectangle(cornerRadius: 14)
                        .fill(character.role.color.opacity(0.5))
                        .frame(height: 380)
                        .animation(.easeInOut, value: character.role)
                        .overlay {
                            VStack(spacing: 16) {
                                AvatarFigureView(
                                    character: character,
                                    bodyHeight: 260,
                                    hairSize: 72,
                                    hairOffsetY: -101
                                )
                                .overlay(alignment: .topLeading) {
                                    Circle()
                                        .fill(character.assignedColor.color)
                                        .frame(width: 24, height: 24)
                                        .shadow(radius: 1)
                                        .padding(16)
                                }
                                .overlay(alignment: .topTrailing) {
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 44, height: 44)
                                            .shadow(radius: 2)
                                            .overlay {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.blue)
                                            }
                                    }
                                    .padding(12)
                                }
                                
                                Picker("Type", selection: $character.avatar) {
                                    ForEach(AvatarType.allCases) { type in
                                        Text(type.label).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }

                    if let customData = character.customImages[character.avatar] {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal")
                                .font(.title3.weight(.medium))
                            
                            Button {
                                character.selectedAsset = nil
                            } label: {
                                VStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)
                                        .frame(height: 100)
                                        .overlay {
                                            if let uiImage = UIImage(data: customData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(12)
                                            }
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(character.selectedAsset == nil ? character.assignedColor.color : Color.clear, lineWidth: 3)
                                        }
                                    
                                    Text(character.name)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 100)
                        }
                    }

                    if character.avatar == .man {
                        assetSection(title: "Style", assets: maleAssets)
                    } else if character.avatar == .woman {
                        assetSection(title: "Style", assets: femaleAssets)
                    } else if character.avatar == .animal {
                        assetSection(title: "Animals", assets: animalAssets)
                        assetSection(title: "Birds", assets: birdAssets)
                        assetSection(title: "Fish", assets: fishAssets)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: character.avatar.systemImageName)
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("Coming Soon")
                                .font(.title3.weight(.bold))
                            
                            Text("Customization for \(character.avatar.label) will be available in a future update.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGray6))
            .navigationTitle("Edit Character")
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            character.customImages[character.avatar] = data
                            character.selectedAsset = nil
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func assetSection(title: String, assets: [CharacterAsset]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.medium))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(assets) { asset in
                        assetTile(asset: asset)
                    }
                }
            }
        }
    }

    private func assetTile(asset: CharacterAsset) -> some View {
        Button {
            character.selectedAsset = asset.imageName
        } label: {
            VStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .frame(height: 100)
                    .overlay {
                        Image(asset.imageName, bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(character.selectedAsset == asset.imageName ? character.assignedColor.color : Color.clear, lineWidth: 3)
                    }
                
                Text(asset.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 100)
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
