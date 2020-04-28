import UIKit

class LayoutMarginsInsetedTableView: UITableView {
    
    private var observedViews = Set<UIView>()
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        insetsLayoutMarginsFromSafeArea = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        insetsLayoutMarginsFromSafeArea = false
    }
    
    deinit {
        removeAllObservations()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let view = object as? UIView, keyPath == #keyPath(UIView.frame) {
            applyInset(to: view)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview is UITableViewHeaderFooterView || subview is UITableViewCell {
            observe(view: subview)
        }
    }
    
    override func reloadData() {
        removeAllObservations()
        super.reloadData()
    }
    
    private func observe(view: UIView) {
        guard !observedViews.contains(view) else {
            return
        }
        view.addObserver(self, forKeyPath: #keyPath(UIView.frame), options: [], context: nil)
        observedViews.insert(view)
    }
    
    private func removeAllObservations() {
        for view in observedViews {
            view.removeObserver(self, forKeyPath: #keyPath(UIView.frame))
        }
        observedViews.removeAll()
    }
    
    private func applyInset(to view: UIView) {
        var leftInset = layoutMargins.left
        if leftInset < safeAreaInsets.left {
            leftInset += safeAreaInsets.left
        }
        leftInset = ceil(leftInset)
        var rightInset = layoutMargins.right
        if rightInset < safeAreaInsets.right {
            rightInset += safeAreaInsets.right
        }
        rightInset = ceil(rightInset)
        let frame = CGRect(x: leftInset,
                           y: view.frame.origin.y,
                           width: view.frame.width - leftInset - rightInset,
                           height: view.frame.height)
        view.layer.frame = frame
    }
    
}
