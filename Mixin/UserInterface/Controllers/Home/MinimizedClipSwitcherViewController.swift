import UIKit
import MixinServices

class MinimizedClipSwitcherViewController: HomeOverlayViewController {
    
    @IBOutlet weak var iconsWrapperView: UIView!
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var iconsWrapperLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperBottomConstraint: NSLayoutConstraint!
    
    private let maxNumberOfVisibleClips = 3
    private let numberOfAdditionalPlaceholders = 2
    private let iconLength: CGFloat = 40
    private let halfIconOffset: CGFloat = 12
    private let quarterIconOffset: CGFloat = 6
    
    private var clips: [Clip] = []
    private var iconViews: [MinimizedClipIconView] = []
    private var visibleIconViews: [MinimizedClipIconView] = []
    private var additionalPlaceholders: [MinimizedClipIconView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let switcher = UIApplication.homeContainerViewController?.clipSwitcher {
            let action = #selector(ClipSwitcher.showFullscreenSwitcher)
            button.addTarget(switcher, action: action, for: .touchUpInside)
        }
        panningController.delegate = self
    }
    
    override func updateViewSize() {
        let numberOfVisibleIcons = visibleIconViews.count + additionalPlaceholders.count
        let iconsWidth = self.iconsWidth(for: numberOfVisibleIcons)
        let horizontalMargin = horizontalContentMargin
            + iconsWrapperLeadingConstraint.constant
            + iconsWrapperTrailingConstraint.constant
        let verticalMargin = verticalContentMargin
            + iconsWrapperTopConstraint.constant
            + iconsWrapperBottomConstraint.constant
        view.bounds.size = CGSize(width: iconsWidth + horizontalMargin,
                                  height: iconLength + verticalMargin)
    }
    
    func appendClip(_ clip: Clip, animated: Bool) {
        clips.append(clip)
        loadViewIfNeeded()
        view.alpha = 1
        
        guard clips.count <= maxNumberOfVisibleClips + 1 else {
            return
        }
        var animations: [() -> Void] = []
        let contentViewFrameBefore = contentView.frame
        let hasNoIconBefore = visibleIconViews.count == 0
        if visibleIconViews.count < maxNumberOfVisibleClips {
            if hasNoIconBefore, let superview = view.superview {
                view.frame.origin.x = superview.bounds.width
            }
            let iconView = insertIconView(with: clip)
            iconView.center = iconCenter(for: visibleIconViews.count - 1, in: visibleIconViews.count)
            visibleIconViews.append(iconView)
            animations.append {
                iconView.center = self.iconCenter(for: self.visibleIconViews.count - 1, in: self.visibleIconViews.count)
            }
        } else {
            additionalPlaceholders = [visibleIconViews.removeLast()]
            for _ in 0..<2 {
                let view = insertPlaceholder()
                view.center = iconCenter(for: maxNumberOfVisibleClips - 1,
                                         in: maxNumberOfVisibleClips - 1 + numberOfAdditionalPlaceholders)
                additionalPlaceholders.append(view)
            }
            animations.append {
                for (index, placeholder) in self.additionalPlaceholders.enumerated() {
                    placeholder.showsPlaceholder = true
                    placeholder.center = self.iconCenter(for: self.maxNumberOfVisibleClips - 1 + index,
                                                         in: self.maxNumberOfVisibleClips - 1 + self.numberOfAdditionalPlaceholders)
                }
            }
        }
        animations.append {
            self.updateViewSize()
            self.view.layoutIfNeeded()
        }
        
        var shadowAnimation: CABasicAnimation? = nil
        if animated {
            shadowAnimation = makeShadowAnimation(fromContentViewFrame: contentViewFrameBefore)
        }
        
        if animated {
            animate({
                animations.forEach({ $0() })
            }, completion: nil)
            if let animation = shadowAnimation {
                animation.toValue = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset),
                                           cornerWidth: contentView.layer.cornerRadius,
                                           cornerHeight: contentView.layer.cornerRadius,
                                           transform: nil)
                view.layer.add(animation, forKey: #keyPath(CALayer.shadowPath))
            }
        } else {
            animations.forEach({ $0() })
        }
        panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: animated)
    }
    
    func removeClip(at index: Int, animated: Bool) {
        guard index >= 0 && index < clips.count else {
            return
        }
        clips.remove(at: index)
        let willCauseVisibleChanges = index <= maxNumberOfVisibleClips
            || (visibleIconViews.count + additionalPlaceholders.count) <= (maxNumberOfVisibleClips + numberOfAdditionalPlaceholders)
        guard willCauseVisibleChanges else {
            return
        }
        loadViewIfNeeded()
        
        if visibleIconViews.count == 1 {
            let layout = {
                if let superview = self.view.superview {
                    self.view.frame.origin.x = superview.bounds.width
                }
            }
            let completion = {
                self.visibleIconViews[index].removeFromSuperview()
                self.visibleIconViews.remove(at: index)
            }
            if animated {
                animate(layout, completion: completion)
            } else {
                layout()
                completion()
            }
        } else {
            let shadowAnimation = makeShadowAnimation(fromContentViewFrame: contentView.frame)
            var animations: [() -> Void] = []
            var completions: [() -> Void] = []
            let isRemovingVisibleIcon = index < visibleIconViews.count
            if isRemovingVisibleIcon {
                let iconViewToRemove = visibleIconViews.remove(at: index)
                if index == 0 {
                    animations.append {
                        iconViewToRemove.alpha = 0
                    }
                } else {
                    animations.append {
                        iconViewToRemove.center = self.iconCenter(for: index - 1, in: self.clips.count)
                    }
                }
                completions.append {
                    iconViewToRemove.removeFromSuperview()
                }
            }
            if clips.count == maxNumberOfVisibleClips {
                if isRemovingVisibleIcon {
                    for index in 1..<maxNumberOfVisibleClips {
                        let iconView = additionalPlaceholders.removeFirst()
                        iconView.load(clip: clips[index])
                        iconView.center = iconCenter(for: 0, in: clips.count)
                        visibleIconViews.append(iconView)
                        animations.append {
                            iconView.showsPlaceholder = false
                        }
                    }
                } else {
                    let iconView = additionalPlaceholders.removeFirst()
                    iconView.load(clip: clips[maxNumberOfVisibleClips - 1])
                    iconView.center = iconCenter(for: clips.count - 2, in: clips.count)
                    visibleIconViews.append(iconView)
                    animations.append {
                        iconView.showsPlaceholder = false
                    }
                }
                let placeholdersToRemove = self.additionalPlaceholders
                additionalPlaceholders = []
                animations.append {
                    for view in placeholdersToRemove {
                        view.center = self.iconCenter(for: 0, in: 1)
                    }
                }
                completions.append {
                    for view in placeholdersToRemove {
                        view.removeFromSuperview()
                    }
                }
            }
            animations.append {
                self.updateAllIconsCenter()
                self.updateViewSize()
                self.view.layoutIfNeeded()
            }
            if animated {
                animate {
                    animations.forEach({ $0() })
                } completion: {
                    completions.forEach({ $0() })
                }
                shadowAnimation.toValue = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset),
                                                 cornerWidth: contentView.layer.cornerRadius,
                                                 cornerHeight: contentView.layer.cornerRadius,
                                                 transform: nil)
                view.layer.add(shadowAnimation, forKey: #keyPath(CALayer.shadowPath))
            } else {
                animations.forEach({ $0() })
                completions.forEach({ $0() })
            }
            panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: animated)
        }
    }
    
    func replaceClips(with clips: [Clip]) {
        self.clips = clips
        loadViewIfNeeded()
        for icon in [visibleIconViews, additionalPlaceholders].flatMap({ $0 }) {
            icon.removeFromSuperview()
        }
        visibleIconViews = []
        additionalPlaceholders = []
        
        if clips.count <= maxNumberOfVisibleClips {
            for clip in clips {
                let view = insertIconView(with: clip)
                visibleIconViews.append(view)
            }
        } else {
            for clip in clips.prefix(maxNumberOfVisibleClips - 1) {
                let view = insertIconView(with: clip)
                visibleIconViews.append(view)
            }
            for _ in 0..<(numberOfAdditionalPlaceholders + 1) {
                let view = insertPlaceholder()
                additionalPlaceholders.append(view)
            }
        }
        
        updateAllIconsCenter()
        if visibleIconViews.count + additionalPlaceholders.count == 0 {
            view.alpha = 0
        } else {
            view.alpha = 1
            updateViewSize()
            panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: false)
        }
    }
    
}

extension MinimizedClipSwitcherViewController: ViewPanningControllerDelegate {
    
    func animateAlongsideViewPanningControllerEdgeSticking(_ controller: ViewPanningController) {
        updateAllIconsCenter()
    }
    
}

extension MinimizedClipSwitcherViewController {
    
    private func dequeueReusableIconView() -> MinimizedClipIconView {
        let view: MinimizedClipIconView
        if let reusableView = iconViews.first(where: { $0.superview == nil }) {
            view = reusableView
        } else {
            view = R.nib.minimizedClipIconView(owner: nil)!
            iconViews.append(view)
        }
        view.avatarImageView.imageView.tintColor = R.color.text_accessory()
        view.alpha = 1
        return view
    }
    
    private func iconsWidth(for count: Int) -> CGFloat {
        let additional: CGFloat
        switch count {
        case 0, 1:
            additional = 0
        case 2, 3:
            additional = halfIconOffset * CGFloat(count - 1)
        default:
            additional = halfIconOffset + quarterIconOffset * 3
        }
        return iconLength + additional
    }
    
    private func updateAllIconsCenter() {
        let numberOfAllIcons = visibleIconViews.count + additionalPlaceholders.count
        for (index, view) in visibleIconViews.enumerated() {
            view.center = iconCenter(for: index, in: numberOfAllIcons)
        }
        for (index, view) in additionalPlaceholders.enumerated() {
            view.center = iconCenter(for: visibleIconViews.count + index, in: numberOfAllIcons)
        }
    }
    
    @discardableResult
    private func insertIconView(with clip: Clip) -> MinimizedClipIconView  {
        let view = dequeueReusableIconView()
        view.showsPlaceholder = false
        view.load(clip: clip)
        iconsWrapperView.insertSubview(view, at: 0)
        return view
    }
    
    @discardableResult
    private func insertPlaceholder() -> MinimizedClipIconView  {
        let view = dequeueReusableIconView()
        view.showsPlaceholder = true
        iconsWrapperView.insertSubview(view, at: 0)
        return view
    }
    
    private func iconCenter(for index: Int, in numberOfIcons: Int) -> CGPoint {
        let offset: CGFloat
        switch index {
        case 0:
            offset = 0
        case 1:
            offset = halfIconOffset
        case 2:
            if numberOfIcons == 3 {
                offset = halfIconOffset * 2
            } else {
                offset = halfIconOffset + quarterIconOffset
            }
        default:
            offset = halfIconOffset + quarterIconOffset * CGFloat(index - 1)
        }
        let x: CGFloat
        if panningController.stickingEdge.contains(.left) {
            x = iconsWidth(for: numberOfIcons) - iconLength / 2 - offset
        } else {
            x = iconLength / 2 + offset
        }
        return CGPoint(x: x, y: iconLength / 2)
    }
    
    private func animate(_ animations: @escaping () -> Void, completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: animations) { _ in
            completion?()
        }
    }
    
    private func makeShadowAnimation(fromContentViewFrame: CGRect) -> CABasicAnimation {
        let anim = CABasicAnimation(keyPath: #keyPath(CALayer.shadowPath))
        anim.fromValue = CGPath(roundedRect: fromContentViewFrame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset),
                                cornerWidth: contentView.layer.cornerRadius,
                                cornerHeight: contentView.layer.cornerRadius,
                                transform: nil)
        anim.duration = 0.3
        anim.autoreverses = false
        anim.isRemovedOnCompletion = true
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return anim
    }
    
}
