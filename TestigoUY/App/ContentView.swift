import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CameraListView()
                .tabItem {
                    Label("Cameras", systemImage: "video")
                }

            MultiCameraGridView()
                .tabItem {
                    Label("Grid", systemImage: "square.grid.2x2")
                }

            RecordingListView()
                .tabItem {
                    Label("Recordings", systemImage: "film.stack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color("AccentColor"))
    }
}
