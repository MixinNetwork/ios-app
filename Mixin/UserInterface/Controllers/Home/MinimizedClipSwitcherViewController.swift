import UIKit
import MixinServices

class MinimizedClipSwitcherViewController: HomeOverlayViewController {
    
    @IBOutlet weak var iconsWrapperView: UIView!
    @IBOutlet weak var button: UIButton!
    
    @IBOutlet weak var iconsWrapperLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconsWrapperBottomConstraint: NSLayoutConstraint!
    
    private let maxNumberOfVisibleClips = 5
    private let iconLength: CGFloat = 40
    private let halfIconOffset: CGFloat = 12
    private let quarterIconOffset: CGFloat = 6
    
    private var clips: [Clip] = []
    private var iconViews: [MinimizedClipIconView] = []
    private var visibleIconViews: [MinimizedClipIconView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let switcher = UIApplication.homeContainerViewController?.clipSwitcher {
            let action = #selector(ClipSwitcher.showFullscreenSwitcher)
            button.addTarget(switcher, action: action, for: .touchUpInside)
        }
    }
    
    override func updateViewSize() {
        let numberOfVisibleIcons = visibleIconViews.count
        let additional: CGFloat
        switch numberOfVisibleIcons {
        case 0, 1:
            additional = 0
        case 2, 3:
            additional = halfIconOffset * CGFloat(numberOfVisibleIcons - 1)
        default:
            additional = halfIconOffset + quarterIconOffset * CGFloat(numberOfVisibleIcons - 2)
        }
        let iconsWidth = iconLength + additional
        let horizontalMargin = contentMargin
            + iconsWrapperLeadingConstraint.constant
            + iconsWrapperTrailingConstraint.constant
        let verticalMargin = contentMargin
            + iconsWrapperTopConstraint.constant
            + iconsWrapperBottomConstraint.constant
        view.bounds.size = CGSize(width: iconsWidth + horizontalMargin,
                                  height: iconLength + verticalMargin)
    }
    
    func appendClip(_ clip: Clip, animated: Bool) {
        clips.append(clip)
        loadViewIfNeeded()
        view.alpha = 1
        
        guard clips.count <= maxNumberOfVisibleClips else {
            return
        }
        let animationDuration: TimeInterval = 0.3
        let contentShadowRectBefore = contentView.frame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset)
        let iconView = insertIconView(with: clip)
        if visibleIconViews.count >= 4 {
            UIView.performWithoutAnimation {
                iconView.showsPlaceholder = true
            }
        }
        
        var shadowAnimation: CABasicAnimation? = nil
        if animated {
            iconView.center = iconCenter(for: 0, in: visibleIconViews.count)
            if visibleIconViews.count == 1 {
                if let superview = view.superview {
                    view.frame.origin.x = superview.bounds.width
                }
            } else {
                shadowAnimation = {
                    let anim = CABasicAnimation(keyPath: #keyPath(CALayer.shadowPath))
                    anim.fromValue = CGPath(roundedRect: contentShadowRectBefore,
                                            cornerWidth: contentView.layer.cornerRadius,
                                            cornerHeight: contentView.layer.cornerRadius,
                                            transform: nil)
                    anim.duration = animationDuration
                    anim.autoreverses = false
                    anim.isRemovedOnCompletion = true
                    anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    return anim
                }()
            }
        }
        
        let layout = {
            iconView.center = self.iconCenter(for: self.visibleIconViews.count - 1,
                                              in: self.visibleIconViews.count)
            if self.visibleIconViews.count == 4 {
                self.visibleIconViews[2].center = self.iconCenter(for: 2, in: self.visibleIconViews.count)
                self.visibleIconViews[2].showsPlaceholder = true
            }
            self.updateViewSize()
            self.view.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: animationDuration,
                           delay: 0,
                           options: .curveEaseOut,
                           animations: layout,
                           completion: nil)
            if let animation = shadowAnimation {
                animation.toValue = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: contentViewVerticalShadowOffset),
                                           cornerWidth: contentView.layer.cornerRadius,
                                           cornerHeight: contentView.layer.cornerRadius,
                                           transform: nil)
                view.layer.add(animation, forKey: #keyPath(CALayer.shadowPath))
            }
        } else {
            layout()
        }
        panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: animated)
    }
    
    func removeClip(at index: Int) {
        guard index >= 0 && index < clips.count else {
            return
        }
        clips.remove(at: index)
        guard index < visibleIconViews.count else {
            return
        }
        loadViewIfNeeded()
        visibleIconViews[index].removeFromSuperview()
        visibleIconViews.remove(at: index)
        if visibleIconViews.count == 3 {
            visibleIconViews[2].center = iconCenter(for: 2, in: 3)
            visibleIconViews[2].showsPlaceholder = false
        } else if clips.count > visibleIconViews.count, visibleIconViews.count < maxNumberOfVisibleClips {
            let clip = clips[visibleIconViews.count]
            let view = insertIconView(with: clip)
            view.showsPlaceholder = visibleIconViews.count == 4
            view.center = iconCenter(for: visibleIconViews.count,
                                     in: visibleIconViews.count + 1)
        }
        if clips.isEmpty {
            view.alpha = 0
        } else {
            view.alpha = 1
            updateViewSize()
            panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: false)
        }
    }
    
    func replaceClips(with clips: [Clip]) {
        self.clips = clips
        loadViewIfNeeded()
        for icon in visibleIconViews {
            icon.removeFromSuperview()
        }
        visibleIconViews = []
        let visibleClips = clips.prefix(maxNumberOfVisibleClips)
        for (index, clip) in visibleClips.enumerated() {
            let view = insertIconView(with: clip)
            view.showsPlaceholder = visibleClips.count >= 4 && index >= 2
            view.center = iconCenter(for: index, in: visibleClips.count)
        }
        if clips.isEmpty {
            view.alpha = 0
        } else {
            view.alpha = 1
            updateViewSize()
            panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: false)
        }
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
        return view
    }
    
    @discardableResult
    private func insertIconView(with clip: Clip) -> MinimizedClipIconView  {
        let view = dequeueReusableIconView()
        view.showsPlaceholder = false
        view.load(clip: clip)
        iconsWrapperView.insertSubview(view, at: 0)
        visibleIconViews.append(view)
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
        return CGPoint(x: iconLength / 2 + offset, y: iconLength / 2)
    }
    
}
