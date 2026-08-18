import UIKit

final class PerpMarketFundingRateCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpMarketFundingRateCellDidRequestInfo(_ cell: PerpMarketFundingRateCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var progressView: CircularProgressView!
    @IBOutlet weak var countDownLabel: UILabel!
    
    weak var delegate: Delegate?
    
    private var nextFundingDate: Date?
    private var totalInterval: TimeInterval?
    
    private weak var countDownTimer: Timer?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        countDownLabel.setFont(
            scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        countDownTimer?.invalidate()
    }
    
    deinit {
        countDownTimer?.invalidate()
    }
    
    @IBAction func requestInfo(_ sender: Any) {
        delegate?.perpMarketFundingRateCellDidRequestInfo(self)
    }
    
    func startCountDown(nextFundingDate: Date, totalInterval: TimeInterval) {
        countDownTimer?.invalidate()
        self.nextFundingDate = nextFundingDate
        self.totalInterval = totalInterval
        let countDownTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] timer in
            if let self {
                self.countDown(timer)
            } else {
                timer.invalidate()
            }
        }
        self.countDownTimer = countDownTimer
        countDown(countDownTimer)
    }
    
    private func countDown(_ timer: Timer) {
        guard let nextFundingDate, let totalInterval else {
            timer.invalidate()
            return
        }
        let remaining = max(0, nextFundingDate.timeIntervalSinceNow)
        countDownLabel.text = PerpsFundingRateDurationFormatter.string(from: remaining)
        let progress = min(1, max(0, remaining / totalInterval))
        progressView.setProgress(progress, animationDuration: nil)
        if remaining <= 0 {
            timer.invalidate()
        }
    }
    
}
