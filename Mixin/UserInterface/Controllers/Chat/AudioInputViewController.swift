import UIKit
import AVFoundation

class AudioInputViewController: UIViewController {

    @IBOutlet weak var recordingIndicatorView: UIView!
    @IBOutlet weak var recordingRedDotView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var slideToCancelView: UIView!
    @IBOutlet weak var slideToCancelContentView: UIStackView!
    @IBOutlet weak var recordImageView: UIImageView!
    @IBOutlet weak var lockView: RecorderLockView!
    @IBOutlet weak var lockedActionsView: UIView!

    @IBOutlet weak var slideViewCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var lockViewVisibleConstraint: NSLayoutConstraint!
    @IBOutlet weak var lockViewHiddenConstraint: NSLayoutConstraint!
    
    @IBOutlet var recordGestureRecognizer: UILongPressGestureRecognizer!
    @IBOutlet var tapGestureRecognizer: UITapGestureRecognizer!
    
    static let maxRecordDuration: TimeInterval = 60

    private let animationDuration: TimeInterval = 0.2
    private let updateTimeLabelInterval: TimeInterval = 1
    private let slideToCancelDistance: CGFloat = 80
    private let longPressHintVisibleDuration: TimeInterval = 2
    private let longPressHintRightMargin: CGFloat = 13
    private let lockDistance: CGFloat = 100
    
    private(set) var isShowingLongPressHint = false
    
    private var recordGestureBeganPoint = CGPoint.zero
    private var recordDurationTimer: Timer?
    private var recordDuration: TimeInterval = 0
    private var recorder: MXNAudioRecorder?
    private var isShowingLockView = false
    private var isLocked = false {
        didSet {
            lockView.isLocked = isLocked
            lockedActionsView.isHidden = !isLocked
        }
    }
    private var conversationViewController: ConversationViewController? {
        return parent as? ConversationViewController
    }
    private var conversationDataSource: ConversationDataSource? {
        return conversationViewController?.dataSource
    }
    
    private lazy var longPressHintView = RecorderLongPressHintView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordGestureRecognizer.delegate = self
    }
    
    @IBAction func tapAction(_ sender: Any) {
        if !isShowingLongPressHint {
            animateShowLongPressHintAndScheduleAutoHiding()
        }
    }
    
    @IBAction func recordGestureRecognizingAction(_ sender: Any) {
        guard (sender as? UIGestureRecognizer) == recordGestureRecognizer else {
            return
        }
        switch recordGestureRecognizer.state {
        case .began:
            isLocked = false
            lockView.progress = 0
            if isShowingLongPressHint {
                animateHideLongPressHint()
            }
            recordImageView.image = #imageLiteral(resourceName: "ic_chat_microphone_highlighted")
            startRecordingIfGranted()
            recordGestureBeganPoint = recordGestureRecognizer.location(in: view)
            slideToCancelContentView.alpha = 1
        case .changed:
            let location = recordGestureRecognizer.location(in: view)
            let horizontalDistance = max(0, recordGestureBeganPoint.x - location.x)
            slideToCancelContentView.alpha = 1 - horizontalDistance / slideToCancelDistance
            if horizontalDistance > slideToCancelDistance {
                recordGestureRecognizer.isEnabled = false
                recordGestureRecognizer.isEnabled = true
            } else {
                slideViewCenterXConstraint.constant = -horizontalDistance
            }
            let verticalDistance = recordGestureBeganPoint.y - location.y
            if !isLocked {
                let lockProgress = Float(verticalDistance / lockDistance)
                if lockProgress >= 1 {
                    isLocked = true
                    lockView.performLockedIconZoomAnimation {
                        self.fadeOutLockView()
                    }
                } else {
                    lockView.progress = lockProgress
                }
            }
        case .ended:
            if !isLocked {
                finishAction(sender)
            }
        case .cancelled:
            cancelAction(sender)
        case .possible, .failed:
            break
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        layoutForStopping()
        recorder?.cancel()
        animateHideLockView()
    }
    
    @IBAction func finishAction(_ sender: Any) {
        layoutForStopping()
        recorder?.stop()
        animateHideLockView()
    }
    
    @objc func updateTimeLabelAction(_ sender: Any) {
        recordDuration += 1
        setTimeLabelValue(recordDuration)
    }
    
    @objc func animateHideLongPressHint() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.longPressHintView.alpha = 0
        }) { (_) in
            self.longPressHintView.removeFromSuperview()
            self.longPressHintView.alpha = 1
            self.isShowingLongPressHint = false
        }
    }
    
    func animateShowLongPressHintAndScheduleAutoHiding() {
        isShowingLongPressHint = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(animateHideLongPressHint), object: nil)
        perform(#selector(animateHideLongPressHint), with: nil, afterDelay: longPressHintVisibleDuration)
        longPressHintView.alpha = 0
        longPressHintView.frame.origin = CGPoint(x: view.bounds.maxX - longPressHintView.frame.width - longPressHintRightMargin,
                                                 y: view.bounds.minY - longPressHintView.frame.height)
        longPressHintView.autoresizingMask = [.flexibleLeftMargin]
        view.addSubview(longPressHintView)
        UIView.animate(withDuration: animationDuration, animations: {
            self.longPressHintView.alpha = 1
        })
    }
    
}

extension AudioInputViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return recorder == nil
    }

}

extension AudioInputViewController {
    
    private func startRecordingIfGranted() {
        switch AVAudioSession.sharedInstance().recordPermission() {
        case .denied:
            alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        case .granted:
            startRecording()
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (_) in })
        }
    }
    
    private func startRecording() {
        layoutForRecording()
        recordDuration = 0
        setTimeLabelValue(0)
        let tempUrl = URL.createTempUrl(fileExtension: ExtensionName.ogg.rawValue)
        do {
            recorder = try MXNAudioRecorder(path: tempUrl.path)
            recorder!.record(forDuration: AudioInputViewController.maxRecordDuration, progress: { (progress) in
                switch progress {
                case .waitingForActivation:
                    break
                case .started:
                    let timer = Timer(timeInterval: self.updateTimeLabelInterval,
                                      target: self,
                                      selector: #selector(AudioInputViewController.updateTimeLabelAction(_:)),
                                      userInfo: nil,
                                      repeats: true)
                    RunLoop.main.add(timer, forMode: .commonModes)
                    self.recordDurationTimer = timer
                    self.startRedDotAnimation()
                case .interrupted:
                    self.recorder?.cancel()
                }
            }) { (completion, metadata, error) in
                self.recordDurationTimer?.invalidate()
                self.recordDurationTimer = nil
                switch completion {
                case .failed:
                    break
                case .finished:
                    self.layoutForStopping()
                    if let duration = metadata?.duration, Double(duration) > millisecondsPerSecond {
                        self.conversationDataSource?.sendMessage(type: .SIGNAL_AUDIO, value: (tempUrl, metadata))
                    } else {
                        try? FileManager.default.removeItem(at: tempUrl)
                        self.animateShowLongPressHintAndScheduleAutoHiding()
                    }
                case .cancelled:
                    break
                }
                self.recorder = nil
            }
        } catch {
            UIApplication.trackError(String(reflecting: self), action: #function, userInfo: ["error": error])
        }
    }

}

extension AudioInputViewController {
    
    private func layoutForRecording() {
        if isShowingLongPressHint {
            animateHideLongPressHint()
        }
        animateShowLockView()
        conversationViewController?.setInputWrapperHidden(true)
        slideViewCenterXConstraint.constant = 0
        preferredContentSize.width = UIScreen.main.bounds.width
        UIView.animate(withDuration: animationDuration) {
            self.slideToCancelView.alpha = 1
            self.recordingIndicatorView.alpha = 1
        }
    }
    
    private func layoutForStopping() {
        conversationViewController?.setInputWrapperHidden(false)
        recordImageView.image = #imageLiteral(resourceName: "ic_chat_microphone")
        if isLocked {
            slideToCancelView.alpha = 0
        } else {
            fadeOutLockView()
        }
        UIView.animate(withDuration: animationDuration, animations: {
            if self.isLocked {
                self.lockedActionsView.alpha = 0
            } else {
                self.slideToCancelView.alpha = 0
            }
            self.recordingIndicatorView.alpha = 0
        }) { (_) in
            self.lockView.progress = 0
            self.preferredContentSize.width = self.view.frame.height
            self.lockedActionsView.alpha = 1
            self.lockedActionsView.isHidden = true
        }
    }
    
    private func animateShowLockView() {
        isShowingLockView = true
        lockViewVisibleConstraint.priority = .defaultHigh
        lockViewHiddenConstraint.priority = .defaultLow
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func animateHideLockView() {
        lockViewVisibleConstraint.priority = .defaultLow
        lockViewHiddenConstraint.priority = .defaultHigh
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.layoutIfNeeded()
        }) { (_) in
            self.isShowingLockView = false
        }
    }
    
    private func fadeOutLockView() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.lockView.alpha = 0
        }) { (_) in
            self.lockViewVisibleConstraint.priority = .defaultLow
            self.lockViewHiddenConstraint.priority = .defaultHigh
            self.view.layoutIfNeeded()
            self.lockView.alpha = 1
        }
    }
    
    private func startRedDotAnimation() {
        UIView.animate(withDuration: 1, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.recordingRedDotView.alpha = 1
        }, completion: nil)
    }
    
    private func stopRedDotAnimation() {
        recordingRedDotView.layer.removeAllAnimations()
        recordingRedDotView.alpha = 0
    }
    
    private func setTimeLabelValue(_ value: TimeInterval) {
        timeLabel.text = mediaDurationFormatter.string(from: value)
    }
    
}
