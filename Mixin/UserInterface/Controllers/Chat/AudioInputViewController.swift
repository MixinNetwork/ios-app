import UIKit
import AVFoundation

class AudioInputContainerView: UIView {
    
    weak var recordView: UIView?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, let recordView = recordView else {
            return nil
        }
        let convertedPoint = convert(point, to: recordView)
        if recordView.point(inside: convertedPoint, with: event) {
            return recordView
        } else {
            return nil
        }
    }
    
}

class AudioInputViewController: UIViewController {

    @IBOutlet weak var recordingIndicatorView: UIView!
    @IBOutlet weak var recordingRedDotView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var slideToCancelView: UIView!
    @IBOutlet weak var recordImageView: UIImageView!

    @IBOutlet weak var bottomWrapperViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var slideViewCenterXConstraint: NSLayoutConstraint!
    
    @IBOutlet var recordGestureRecognizer: UILongPressGestureRecognizer!
    
    static let maxRecordDuration: TimeInterval = 60

    private let animationDuration: TimeInterval = 0.2
    private let updateTimeLabelInterval: TimeInterval = 1
    
    private var beganPoint = CGPoint.zero
    private var timer: Timer?
    private var time = 0
    private var recorder: MXNAudioRecorder?
    
    private var conversationDataSource: ConversationDataSource? {
        return (parent as? ConversationViewController)?.dataSource
    }
    
    private lazy var requestPermissionController: UIAlertController = {
        let controller = UIAlertController(title: Localized.PERMISSION_DENIED_MICROPHONE, message: nil, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        controller.addAction(UIAlertAction(title: Localized.SETTING_TITLE, style: .default, handler: { (_) in
            UIApplication.openAppSettings()
        }))
        return controller
    }()
    
    override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)
        if let container = view.superview as? AudioInputContainerView {
            container.recordView = recordImageView
        }
    }
    
    @IBAction func recordGestureRecognizingAction(_ sender: Any) {
        guard (sender as? UIGestureRecognizer) == recordGestureRecognizer else {
            return
        }
        switch recordGestureRecognizer.state {
        case .possible:
            break
        case .began:
            startRecordingIfGranted()
            beganPoint = recordGestureRecognizer.location(in: view)
        case .changed:
            let location = recordGestureRecognizer.location(in: view)
            if location.x - beganPoint.x < -80 {
                recordGestureRecognizer.isEnabled = false
                recordGestureRecognizer.isEnabled = true
            } else {
                slideViewCenterXConstraint.constant = location.x - beganPoint.x
            }
        case .ended:
            layout(isRecording: false)
            recorder?.stop()
            recorder = nil
        case .cancelled:
            layout(isRecording: false)
            recorder?.cancel()
            recorder = nil
        case .failed:
            break
        }
    }
    
    @objc func updateTimeLabelAction(_ sender: Any) {
        time += 1
        setTimeLabelValue(time)
    }
    
}

extension AudioInputViewController {
    
    private func startRecordingIfGranted() {
        switch AVAudioSession.sharedInstance().recordPermission() {
        case .denied:
            present(requestPermissionController, animated: true, completion: nil)
        case .granted:
            startRecording()
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                if granted {
                    if Thread.isMainThread {
                        self.startRecording()
                    } else {
                        DispatchQueue.main.async {
                            self.startRecording()
                        }
                    }
                }
            })
        }
    }
    
    private func startRecording() {
        layout(isRecording: true)
        time = 0
        setTimeLabelValue(0)
        let url = MixinFile.url(ofChatDirectory: .audios, filename: UUID().uuidString.lowercased() + ExtensionName.ogg.withDot)
        do {
            recorder = try MXNAudioRecorder(path: url.path)
            recorder!.record(forDuration: AudioInputViewController.maxRecordDuration, progress: { (progress) in
                switch progress {
                case .waitingForActivation:
                    break
                case .started:
                    self.timer = Timer.scheduledTimer(timeInterval: self.updateTimeLabelInterval,
                                                      target: self,
                                                      selector: #selector(AudioInputViewController.updateTimeLabelAction(_:)),
                                                      userInfo: nil,
                                                      repeats: true)
                    self.startRedDotAnimation()
                case .interrupted:
                    self.recorder?.cancel()
                }
            }) { (completion, metadata, error) in
                self.timer?.invalidate()
                self.timer = nil
                switch completion {
                case .failed:
                    break
                case .finished:
                    self.conversationDataSource?.sendMessage(type: .SIGNAL_AUDIO, value: (url, metadata))
                case .cancelled:
                    break
                }
            }
        } catch {
            UIApplication.trackError(String(reflecting: self), action: #function, userInfo: ["error": error])
        }
    }

}

extension AudioInputViewController {
    
    private func layout(isRecording: Bool) {
        let alpha: CGFloat = isRecording ? 1 : 0
        UIView.animate(withDuration: animationDuration, animations: {
            self.slideToCancelView.alpha = alpha
            self.recordingIndicatorView.alpha = alpha
        })
        if isRecording {
            slideViewCenterXConstraint.constant = 0
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
    
    private func setTimeLabelValue(_ value: Int) {
        timeLabel.text = String(value)
    }
    
}
