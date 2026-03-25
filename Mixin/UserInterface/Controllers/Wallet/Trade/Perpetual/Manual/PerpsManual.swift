import Foundation
import SwiftUI

enum PerpsManual {
    
    enum Page: Int {
        case intro
        case long
        case short
        case leverage
        case size
    }
    
    static let cardInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    
    static func viewController(initialPage: Page = .intro) -> ManualViewController {
        let pages = [
            ManualViewController.Page(
                title: R.string.localizable.brief_introduction(),
                view: PerpsManualIntroductionPageView()
            ),
            ManualViewController.Page(
                title: R.string.localizable.long(),
                view: PerpsManualLongPageView()
            ),
            ManualViewController.Page(
                title: R.string.localizable.short(),
                view: PerpsManualShortPageView()
            ),
            ManualViewController.Page(
                title: R.string.localizable.leverage(),
                view: PerpsManualLeveragePageView()
            ),
            ManualViewController.Page(
                title: R.string.localizable.position_size(),
                view: PerpsManualPositionSizePageView()
            ),
        ]
        let manual = ManualViewController(
            pages: pages,
            initialIndex: initialPage.rawValue
        )
        manual.title = R.string.localizable.perpetual_futures_guide()
        return manual
    }
    
}
