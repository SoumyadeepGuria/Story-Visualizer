import SwiftUI

struct ContentView: View {
    @State private var projects: [Project] = []
    @State private var isShowingCreateProjectAlert = false
    @State private var newProjectName = ""
    @State private var path: [UUID] = []

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: isPad ? 250 : 170), spacing: 12, alignment: .top)]
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    AddProjectCard {
                        newProjectName = ""
                        isShowingCreateProjectAlert = true
                    }
                    .frame(height: isPad ? 210 : 160)

                    ForEach(projects) { project in
                        NavigationLink(value: project.id) {
                            ProjectCard(project: project)
                                .frame(height: isPad ? 210 : 160)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGray6))
            .navigationDestination(for: UUID.self) { projectID in
                if let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
                    CharacterSetupView(project: $projects[projectIndex])
                }
            }
            .alert("New Project", isPresented: $isShowingCreateProjectAlert) {
                TextField("Project name", text: $newProjectName)

                Button("Cancel", role: .cancel) {
                    newProjectName = ""
                }

                Button("Add") {
                    let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    let project = Project(name: trimmedName)
                    projects.insert(project, at: 0)
                    newProjectName = ""
                    path.append(project.id)
                }
            } message: {
                Text("Enter the project name.")
            }
        }
    }
}
