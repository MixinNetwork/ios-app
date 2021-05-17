import UIKit
import AVFoundation
import MixinServices

class AudioInputViewController: UIViewController, ConversationInputAccessible {
    
    static let maxRecordDuration: TimeInterval = 60
    
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
    
    var isRecording: Bool {
        if let recorder = recorder {
            return recorder.isRecording
        } else {
            return false
        }
    }
    
    private let animationDuration: TimeInterval = 0.2
    private let updateTimeLabelInterval: TimeInterval = 1
    private let slideToCancelDistance: CGFloat = 80
    private let longPressHintVisibleDuration: TimeInterval = 2
    private let longPressHintRightMargin: CGFloat = 10
    private let lockDistance: CGFloat = 100
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    private(set) var isShowingLongPressHint = false
    
    private var recordGestureBeganPoint = CGPoint.zero
    private var recordDuration: TimeInterval = 0
    private var recorder: OggOpusRecorder?
    private var displayAwakeningToken: DisplayAwakener.Token?
    private var isShowingLockView = false
    private var isLocked = false {
        didSet {
            lockView.isLocked = isLocked
            lockedActionsView.isHidden = !isLocked
        }
    }
    
    private weak var recordDurationTimer: Timer?
    
    private lazy var longPressHintView = R.nib.recorderLongPressHintView(owner: nil)!
    
    deinit {
        recorder?.cancel(for: .userInitiated)
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordGestureRecognizer.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(cancelAction(_:)), name: CallService.willStartCallNotification, object: nil)
    }
    
    @IBAction func tapAction(_ sender: Any) {
        if !isShowingLongPressHint {
            flashLongPressHint()
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
            hideLongPressHint()
            recordImageView.tintColor = .theme
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
            if !isLocked {
                cancelAction(sender)
            }
        case .possible, .failed:
            break
        @unknown default:
            break
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        layoutForStopping()
        recorder?.cancel(for: .userInitiated)
        animateHideLockView()
    }
    
    @IBAction func finishAction(_ sender: Any) {
        layoutForStopping()
        recorder?.stop()
        animateHideLockView()
    }
    
    @discardableResult @objc
    func hideLongPressHint() -> Bool {
        guard isShowingLongPressHint else {
            return false
        }
        UIView.animate(withDuration: animationDuration, animations: {
            self.longPressHintView.alpha = 0
        }) { (_) in
            self.longPressHintView.removeFromSuperview()
            self.longPressHintView.alpha = 1
            self.isShowingLongPressHint = false
        }
        return true
    }
    
    func flashLongPressHint() {
        isShowingLongPressHint = true
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideLongPressHint), object: nil)
        perform(#selector(hideLongPressHint), with: nil, afterDelay: longPressHintVisibleDuration)
        longPressHintView.alpha = 0
        view.addSubview(longPressHintView)
        longPressHintView.snp.makeConstraints { (make) in
            make.right.equalToSuperview().offset(-longPressHintRightMargin)
            make.bottom.equalTo(view.snp.top)
        }
        UIView.animate(withDuration: animationDuration, animations: {
            self.longPressHintView.alpha = 1
        })
    }
    
    func cancelIfRecording() {
        guard isRecording else {
            return
        }
        cancelAction(self)
    }
    
}

extension AudioInputViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return recorder == nil
    }
    
}

extension AudioInputViewController: OggOpusRecorderDelegate {
    
    func oggOpusRecorderIsWaitingForActivation(_ recorder: OggOpusRecorder) {
        
    }
    
    func oggOpusRecorderDidStartRecording(_ recorder: OggOpusRecorder) {
        let timer = Timer(timeInterval: updateTimeLabelInterval, repeats: true) { [weak self] (_) in
            self?.updateTimeLabel()
        }
        RunLoop.main.add(timer, forMode: .common)
        recordDurationTimer = timer
        startRedDotAnimation()
    }
    
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didCancelRecordingForReason reason: OggOpusRecorder.CancelledReason, userInfo: [String : Any]?) {
        resetTimerAndRecorder()
        layoutForStopping()
        stopRedDotAnimation()
        if reason != .userInitiated {
            var userInfo = userInfo ?? [:]
            userInfo["reason"] = reason.rawValue
            Logger.write(errorMsg: "[OggOpusRecorderDidCancelRecording]...reason:\(reason.rawValue)")
            reporter.report(event: .cancelAudioRecording, userInfo: userInfo)
        }
    }
    
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didFailRecordingWithError error: Error) {
        resetTimerAndRecorder()
        layoutForStopping()
        stopRedDotAnimation()
        reporter.report(error: error)
        Logger.write(error: error)
    }
    
    func oggOpusRecorder(_ recorder: OggOpusRecorder, didFinishRecordingWithMetadata metadata: AudioMetadata) {
        resetTimerAndRecorder()
        layoutForStopping()
        stopRedDotAnimation()
        let url = URL(fileURLWithPath: recorder.path)
        if Double(metadata.duration) > millisecondsPerSecond {
            conversationInputViewController?.sendAudio(url: url, metadata: metadata)
        } else {
            try? FileManager.default.removeItem(at: url)
            flashLongPressHint()
        }
    }
    
    func oggOpusRecorderDidDetectAudioSessionInterruptionEnd(_ recorder: OggOpusRecorder) {
        Logger.write(errorMsg: "[OggOpusRecorderDidCancelRecording]...detect interruption end")
    }
    
}

extension AudioInputViewController {
    
    private func startRecordingIfGranted() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        case .granted:
            if CallService.shared.hasCall {
                alert(R.string.localizable.chat_voice_record_on_call())
            } else {
                startRecording()
            }
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (_) in })
        @unknown default:
            alertSettings(Localized.PERMISSION_DENIED_MICROPHONE)
        }
    }
    
    private func startRecording() {
        feedback.prepare()
        layoutForRecording()
        recordDuration = 0
        setTimeLabelValue(0)
        let tempUrl = URL.createTempUrl(fileExtension: ExtensionName.ogg.rawValue)
        do {
            let recorder = try OggOpusRecorder(path: tempUrl.path)
            recorder.delegate = self
            recorder.record(for: AudioInputViewController.maxRecordDuration)
            self.recorder = recorder
            self.feedback.impactOccurred()
            if displayAwakeningToken == nil {
                displayAwakeningToken = DisplayAwakener.shared.retain()
            }
        } catch {
            reporter.report(error: error)
        }
    }
    
    private func updateTimeLabel() {
        recordDuration += 1
        setTimeLabelValue(recordDuration)
    }
    
    private func resetTimerAndRecorder() {
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
            displayAwakeningToken = nil
        }
        recordDurationTimer?.invalidate()
        recordDurationTimer = nil
        recorder = nil
    }
    
}

extension AudioInputViewController {
    
    private func layoutForRecording() {
        hideLongPressHint()
        animateShowLockView()
        slideViewCenterXConstraint.constant = 0
        preferredContentSize.width = UIScreen.main.bounds.width
        UIView.animate(withDuration: animationDuration) {
            self.slideToCancelView.alpha = 1
            self.recordingIndicatorView.alpha = 1
        }
    }
    
    private func layoutForStopping() {
        recordImageView.tintColor = R.color.icon_tint()!
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
