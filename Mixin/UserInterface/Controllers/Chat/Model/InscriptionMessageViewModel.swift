import Foundation

// FIX ME
class InscriptionMessageViewModel: CardMessageViewModel, TitledCardContentWidthCalculable {
        
    override class var bubbleImageSet: BubbleImageSet.Type {
        return AppCardBubbleImageSet.self
    }
    
    override class var leftViewSideLength: CGFloat {
        48
    }
    
    override func layout(width: CGFloat, style: Style) {
        updateContentWidth(title: "Azra Games -The Hopeful ",
                           titleFont: MessageFontSet.cardTitle.scaled,
                           subtitle: "#104655",
                           subtitleFont: MessageFontSet.cardSubtitle.scaled)
        super.layout(width: width, style: style)
    }
    
}
