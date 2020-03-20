import UIKit
import MixinServices

class RecorderLockView: UIView {
    
    static let backgroundImage = R.image.conversation.bg_recorder_lock()!
    static let shackleImage = R.image.conversation.ic_recorder_lock_shackle()!
    static let lockBodyImage = R.image.conversation.ic_recorder_lock_body()!
    static let lockedImage = R.image.conversation.ic_recorder_lock_locked()!
    static let directionIndicationImage = R.image.conversation.ic_recorder_lock_direction_up()!
    
    let backgroundImageView = UIImageView(image: RecorderLockView.backgroundImage)
    let lockShackleImageView = UIImageView(image: RecorderLockView.shackleImage)
    let lockBodyImageView = UIImageView(image: RecorderLockView.lockBodyImage)
    let lockedImageView = UIImageView(image: RecorderLockView.lockedImage)
    let directionIndicatorImageView = UIImageView(image: RecorderLockView.directionIndicationImage)
    
    private let lockedIconZoomingTransform = CGAffineTransform(scaleX: 1.3, y: 1.3)
    private let lockedIconZoomingAnimationDuration: TimeInterval = 0.2
    
    var isLocked = false {
        didSet {
            lockedImageView.isHidden = !isLocked
            backgroundImageView.isHidden = isLocked
            lockShackleImageView.isHidden = isLocked
            lockBodyImageView.isHidden = isLocked
            directionIndicatorImageView.isHidden = isLocked
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return BackgroundSize.start
    }
    
    var progress: Float = 0 {
        didSet {
            setNeedsLayout()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !isLocked {
            let progress = max(0, min(1, CGFloat(self.progress)))
            let backgroundOrigin = (BackgroundOrigin.end - BackgroundOrigin.start) * progress + BackgroundOrigin.start
            let backgroundSize = (BackgroundSize.end - BackgroundSize.start) * progress + BackgroundSize.start
            backgroundImageView.frame = CGRect(origin: backgroundOrigin, size: backgroundSize)
            lockBodyImageView.center = (LockBodyCenter.end - LockBodyCenter.start) * progress + LockBodyCenter.start
            lockShackleImageView.center = (LockShackleCenter.end - LockShackleCenter.start) * progress + LockShackleCenter.start
            directionIndicatorImageView.center = (DirectionIndicatorCenter.end - DirectionIndicatorCenter.start) * progress + DirectionIndicatorCenter.start
            directionIndicatorImageView.alpha = 1 - progress
        }
    }
    
    private func prepare() {
        bounds.size = BackgroundSize.start
        progress = 0
        isLocked = false
        addSubview(backgroundImageView)
        addSubview(lockShackleImageView)
        addSubview(lockBodyImageView)
        addSubview(directionIndicatorImageView)
        lockedImageView.frame.origin = BackgroundOrigin.end
        addSubview(lockedImageView)
    }
    
    func performLockedIconZoomAnimation(completion: @escaping () -> Void) {
        UIView.animate(withDuration: lockedIconZoomingAnimationDuration, delay: 0, options: .curveEaseIn, animations: {
            self.lockedImageView.transform = self.lockedIconZoomingTransform
        }, completion: nil)
        UIView.animate(withDuration: lockedIconZoomingAnimationDuration, delay: lockedIconZoomingAnimationDuration, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.lockedImageView.transform = .identity
        }, completion: nil)
        UIView.animate(withDuration: lockedIconZoomingAnimationDuration, delay: lockedIconZoomingAnimationDuration * 2, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.lockedImageView.transform = self.lockedIconZoomingTransform
        }, completion: nil)
        UIView.animate(withDuration: lockedIconZoomingAnimationDuration, delay: lockedIconZoomingAnimationDuration * 3, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.lockedImageView.transform = .identity
        }) { (_) in
            completion()
        }
    }
    
}

extension RecorderLockView {
    
    static let lockedLockSize = CGSize(width: max(shackleImage.size.width, lockBodyImage.size.width), height: shackleImage.size.height + lockBodyImage.size.height + ShackleBottomMargin.end)
    static let verticalDistance: CGFloat = 50
    
    enum BackgroundOrigin {
        static let start = CGPoint(x: 0, y: 0)
        static let end = CGPoint(x: 0, y: start.y - verticalDistance)
    }
    
    enum BackgroundSize {
        static let start = CGSize(width: backgroundImage.size.width, height: 150)
        static let end = backgroundImage.size
    }
    
    enum DirectionIndicatorTopMargin {
        static let start: CGFloat = 20
        static let end: CGFloat = 8
    }
    
    enum ShackleBottomMargin {
        static let start: CGFloat = -1
        static let end: CGFloat = -5
    }
    
    enum LockBodyCenter {
        static let start = CGPoint(x: BackgroundSize.start.width / 2, y: BackgroundSize.start.height / 2 - 20)
        static let end = CGPoint(x: BackgroundSize.end.width / 2, y: BackgroundSize.end.height - (BackgroundSize.end.height - lockedLockSize.height) / 2 - lockBodyImage.size.height / 2 - verticalDistance)
    }
    
    enum LockShackleCenter {
        static let start = CGPoint(x: BackgroundSize.start.width / 2, y: LockBodyCenter.start.y - shackleImage.size.height / 2 - lockBodyImage.size.height / 2 - ShackleBottomMargin.start)
        static let end = CGPoint(x: BackgroundSize.end.width / 2, y: (BackgroundSize.end.height - lockedLockSize.height) / 2 + shackleImage.size.height / 2 - verticalDistance)
    }
    
    enum DirectionIndicatorCenter {
        static let start = CGPoint(x: BackgroundSize.start.width / 2, y: LockBodyCenter.start.y + DirectionIndicatorTopMargin.start + directionIndicationImage.size.height / 2)
        static let end = CGPoint(x: BackgroundSize.end.width / 2, y: LockBodyCenter.end.y + DirectionIndicatorTopMargin.end + directionIndicationImage.size.height / 2)
    }
    
}
