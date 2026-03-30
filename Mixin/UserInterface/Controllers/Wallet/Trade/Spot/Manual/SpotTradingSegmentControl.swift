import SwiftUI

struct SpotTradingSegmentControl<Segment: Hashable>: View {
    
    let segments: [Segment]
    
    @Binding var selection: Segment
    
    let content: (Segment) -> String
    
    @Namespace private var animation
    
    @ScaledMetric
    private var size: CGFloat = 12
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.self) { option in
                let isSelected = selection == option
                Text(content(option))
                    .foregroundColor(isSelected ? .white : Color(R.color.text_tertiary))
                    .font(.system(size: size, weight: isSelected ? .medium : .regular))
                    .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(R.color.theme))
                                .matchedGeometryEffect(id: "SelectedPill", in: animation)
                        }
                    }
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                    .onTapGesture {
                        withAnimation(
                            .interactiveSpring(
                                response: 0.3,
                                dampingFraction: 0.75,
                                blendDuration: 0.5
                            )
                        ) {
                            selection = option
                        }
                    }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(R.color.background_quaternary))
        )
    }
    
}
