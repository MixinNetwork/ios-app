import UIKit

class CountDownButton: StateResponsiveButton {
    
    @IBInspectable var normalTitle: String = ""
    @IBInspectable var pendingTitleTemplate: String = ""
    
    var onCountDownFinished: (() -> Void)?
    
    private var timer: Timer?
    private var countDown: Int = -1
    private var countDownInterval: TimeInterval = 1

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func updateWithIsEnabled() {
        setTitleColor(isEnabled ? enabledColor : disabledColor, for: .normal)
    }
    
    override func updateWithIsBusy() {
        if isBusy {
            isUserInteractionEnabled = false
            activityIndicator.startAnimating()
            setTitleColor(.clear, for: .normal)
        } else {
            isUserInteractionEnabled = true
            activityIndicator.stopAnimating()
            updateWithIsEnabled()
        }
    }
    
    func beginCountDown(_ countDown: Int) {
        assert(countDown > 1)
        releaseTimer()
        isBusy = false
        isEnabled = false
        self.countDown = countDown
        restartTimerIfNeeded()
    }
    
    func releaseTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func restartTimerIfNeeded() {
        guard timer == nil, countDown > 0 else {
            return
        }
        count()
        timer = Timer.scheduledTimer(timeInterval: countDownInterval, target: self, selector: #selector(count), userInfo: nil, repeats: true)
    }
    
    @objc func count() {
        let title: String
        if countDown > 0 {
            title = String(format: pendingTitleTemplate, mmssString(from: countDown))
            countDown -= 1
        } else {
            title = normalTitle
            isEnabled = true
            timer?.invalidate()
            timer = nil
            onCountDownFinished?()
        }
        UIView.performWithoutAnimation {
            setTitle(title, for: .normal)
            layoutIfNeeded()
        }
    }
    
    private func prepare() {
        enabledColor = .theme
        disabledColor = .gray
    }
    
    private func mmssString(from totalSeconds: Int) -> String {
        let seconds: Int = totalSeconds % 60
        let minutes: Int = totalSeconds / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
}
