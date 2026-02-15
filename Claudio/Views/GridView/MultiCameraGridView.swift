import SwiftUI

struct MultiCameraGridView: View {
    @StateObject private var viewModel = MultiStreamViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.cameras.isEmpty {
                    emptyState
                } else {
                    gridContent
                }
            }
            .navigationTitle("Live Grid")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    GridLayoutPicker(selectedLayout: $viewModel.layout) { newLayout in
                        viewModel.updateLayout(newLayout)
                    }
                }
            }
            .onAppear {
                viewModel.loadCameras()
                viewModel.startStreams()
            }
            .onDisappear {
                viewModel.stopAllStreams()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Cameras")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add cameras from the Cameras tab to view them here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var gridContent: some View {
        GeometryReader { geometry in
            let columns = viewModel.layout.columns
            let spacing: CGFloat = 2
            let totalSpacing = spacing * CGFloat(columns - 1)
            let cellWidth = (geometry.size.width - totalSpacing) / CGFloat(columns)
            let cellHeight = (geometry.size.height - totalSpacing) / CGFloat(columns)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(viewModel.visibleCameras) { camera in
                    GridCellView(
                        camera: camera,
                        engine: viewModel.engines[camera.id]
                    )
                    .frame(height: cellHeight)
                }
            }
        }
    }
}
