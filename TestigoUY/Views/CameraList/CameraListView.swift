import SwiftUI

struct CameraListView: View {
    @StateObject private var viewModel = CameraListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.cameras.isEmpty {
                    emptyState
                } else {
                    cameraList
                }
            }
            .navigationTitle("Cameras")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.showingAddCamera = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddCamera) {
                AddCameraView { camera in
                    viewModel.saveCamera(camera)
                }
            }
            .sheet(item: $viewModel.editingCamera) { camera in
                AddCameraView(camera: camera) { updated in
                    viewModel.saveCamera(updated)
                }
            }
            .onAppear {
                viewModel.loadCameras()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(Color("AccentColor"))
            Text("No Cameras")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to add your first IP camera")
                .foregroundColor(.secondary)
            Text("Disfruta de la tranquilidad simple")
                .font(.caption)
                .foregroundStyle(Color("AccentColor").opacity(0.8))
                .italic()
        }
    }

    private var cameraList: some View {
        List {
            ForEach(viewModel.cameras) { camera in
                NavigationLink(destination: SingleCameraView(camera: camera)) {
                    CameraRowView(camera: camera)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteCamera(camera)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        viewModel.editingCamera = camera
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }
}
