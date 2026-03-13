import SwiftUI
import RswiftResources

struct BulletinText: View {
    
    private let content: String
    
    init(_ contents: [String]) {
        self.content = "• " + contents.joined(separator: "\n• ")
    }
    
    var body: some View {
        Text(content)
            .modifier(ManualText(.body))
    }
    
}
