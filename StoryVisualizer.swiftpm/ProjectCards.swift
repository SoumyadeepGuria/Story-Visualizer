import SwiftUI

struct AddProjectCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 52, weight: .regular))
                            .foregroundStyle(Color(.systemGray2))

                        Text("New Project")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create project")
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .overlay {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4))
                                .frame(width: 28, height: 28)
                        }
                    }

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .frame(height: 58)
                        .padding(.top, 6)

                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(10)
            }
    }
}
