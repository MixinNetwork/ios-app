import UIKit

class AppButtonGroupView: UIView {
    
    private(set) var buttonViews = [AppButtonView]()
    
    func layoutButtons(viewModel: AppButtonGroupViewModel) {
        let diff = buttonViews.count - viewModel.frames.count
        if diff > 0 {
            for view in buttonViews.suffix(diff) {
                view.removeFromSuperview()
            }
            buttonViews.removeLast(diff)
        } else if diff < 0 {
            for _ in (0 ..< -diff) {
                let view = AppButtonView()
                buttonViews.append(view)
                addSubview(view)
            }
        }
        
        for i in 0..<buttonViews.count {
            buttonViews[i].frame = viewModel.frames[i]
        }
    }
    
}
