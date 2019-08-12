import UIKit

class LargeModernNetworkOperationButton: ModernNetworkOperationButton {
    
    override var backgroundSize: CGSize {
        return CGSize(width: 60, height: 60)
    }
    
    override var iconSet: NetworkOperationIconSet.Type {
        return LargeNetworkOperationIconSet.self
    }
    
    override var indicatorLineWidth: CGFloat {
        return 4
    }
    
}
