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
    
    func appendClip(_ clip: Clip) {
        clips.append(clip)
        view.alpha = 1
        if clips.count <= maxNumberOfVisibleClips {
            loadViewIfNeeded()
            let view = insertIconView(with: clip)
            visibleIconViews.append(view)
            view.center = iconCenter(for: visibleIconViews.count - 1,
                                     in: visibleIconViews.count)
            if visibleIconViews.count >= 4 {
                view.showsPlaceholder = true
            }
            if visibleIconViews.count == 4 {
                visibleIconViews[2].center = iconCenter(for: 2, in: visibleIconViews.count)
                visibleIconViews[2].showsPlaceholder = true
            }
            updateViewSize()
            panningController.stickViewToParentEdge(horizontalVelocity: 0, animated: false)
        }
    }
    
    func removeClip(at index: Int) {
        guard index >= 0 && index < clips.count else {
            return
        }
        clips.remove(at: index)
        loadViewIfNeeded()
        guard index < maxNumberOfVisibleClips else {
            return
        }
        visibleIconViews[index].removeFromSuperview()
        visibleIconViews.remove(at: index)
        if visibleIconViews.count == 3 {
            visibleIconViews[2].center = iconCenter(for: 2, in: 3)
            visibleIconViews[2].showsPlaceholder = false
        } else if clips.count > visibleIconViews.count, visibleIconViews.count < maxNumberOfVisibleClips {
            let clip = clips[visibleIconViews.count]
            let view = insertIconView(with: clip)
            visibleIconViews.append(view)
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
        let visibleClips = clips.prefix(maxNumberOfVisibleClips)
        for (index, clip) in visibleClips.enumerated() {
            let view = insertIconView(with: clip)
            visibleIconViews.append(view)
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
