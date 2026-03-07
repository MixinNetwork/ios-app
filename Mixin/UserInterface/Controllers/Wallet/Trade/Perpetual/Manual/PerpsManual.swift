import Foundation
import SwiftUI

enum PerpsManual {
    
    static let cardInsets = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
    
    static func pages() -> [ManualViewController.Page] {
        [
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
                title: R.string.localizable.position(),
                view: PerpsManualPositionPageView()
            ),
        ]
    }
    
}
