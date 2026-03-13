import SwiftUI

struct ManualScrollView<Content: View>: View {
    
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        ScrollView {
            ZStack {
                Color(R.color.background_secondary)
                content()
            }
        }
        .background(Color(R.color.background_secondary))
    }
    
}
