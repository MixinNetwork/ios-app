import UIKit

extension UIBackgroundConfiguration {
    
    static let groupedCell = {
        var config: UIBackgroundConfiguration = .listGroupedCell()
        config.backgroundColor = R.color.background()
        return config
    }()
    
}
