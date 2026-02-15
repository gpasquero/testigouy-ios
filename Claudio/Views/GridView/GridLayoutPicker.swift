import SwiftUI

struct GridLayoutPicker: View {
    @Binding var selectedLayout: GridLayout
    let onChange: (GridLayout) -> Void

    var body: some View {
        Menu {
            ForEach(GridLayout.allCases) { layout in
                Button(action: {
                    selectedLayout = layout
                    onChange(layout)
                }) {
                    Label(layout.displayName, systemImage: layout.systemImage)
                }
            }
        } label: {
            Image(systemName: selectedLayout.systemImage)
        }
    }
}
