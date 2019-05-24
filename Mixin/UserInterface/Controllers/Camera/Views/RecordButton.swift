import UIKit

class RecordButton: UIButton {
    private let borderWidth: CGFloat = 7
    private let maxDuration: Double = 15 * 1000

    private lazy var centerPoint: CGPoint = { return CGPoint(x: self.bounds.width / 2, y: self.bounds.width / 2) }()
    private lazy var circleRadius: CGFloat = { return self.bounds.width / 2 - self.borderWidth / 2 }()

    private var circleBorder: CALayer!
    private var innerCircleView: UIView!
    private var progressCircleBorder: CAShapeLayer!
    private var progressTimer: CADisplayLink?
    private var progressLastTime: CFAbsoluteTime!
    private var autoStopTimer: Timer?

    var longPressRecognizer: UILongPressGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawButton()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawButton()
    }

    fileprivate func drawButton() {
        self.backgroundColor = UIColor.clear

        circleBorder = CALayer()
        circleBorder.backgroundColor = UIColor.clear.cgColor
        circleBorder.borderWidth = borderWidth
        circleBorder.borderColor = UIColor.white.cgColor
        circleBorder.bounds = self.bounds
        circleBorder.shadowColor = UIColor.black.cgColor
        circleBorder.shadowOffset = CGSize(width: 0.0, height: 0.0)
        circleBorder.shadowRadius = 1.0
        circleBorder.shadowOpacity = 0.4
        circleBorder.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        circleBorder.cornerRadius = circleBorder.bounds.width / 2
        layer.insertSublayer(circleBorder, at: 0)

        progressCircleBorder = CAShapeLayer()
        progressCircleBorder.strokeColor = UIColor.systemTint.cgColor
        progressCircleBorder.fillColor = UIColor.clear.cgColor
        progressCircleBorder.lineWidth = 6.0
        progressCircleBorder.strokeStart = 0
        progressCircleBorder.strokeEnd = 1
        progressCircleBorder.bounds = self.bounds
        progressCircleBorder.position = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        progressCircleBorder.cornerRadius = self.frame.size.width / 2

        innerCircleView = UIView()
        innerCircleView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        innerCircleView.backgroundColor = UIColor.systemTint
        innerCircleView.clipsToBounds = true
        innerCircleView.layer.masksToBounds = true
    }

    func startAnimation(animationBlock: @escaping () -> Void) {
        innerCircleView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        innerCircleView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        innerCircleView.layer.cornerRadius = innerCircleView.frame.size.width / 2
        addSubview(innerCircleView)

        progressCircleBorder.path = UIBezierPath(arcCenter: centerPoint, radius: circleRadius, startAngle: 1.5 * CGFloat.pi, endAngle: 1.5 * CGFloat.pi, clockwise: true).cgPath
        layer.addSublayer(progressCircleBorder)


        progressTimer = CADisplayLink(target: self, selector: #selector(updateProgress))
        autoStopTimer = Timer.scheduledTimer(timeInterval: maxDuration / 1000, target: self, selector: #selector(autoStopAction), userInfo: nil, repeats: false)

        self.progressLastTime = CFAbsoluteTimeGetCurrent()
        self.progressTimer?.add(to: .main, forMode: .default)

        let scaleX = self.bounds.width * 0.8
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.innerCircleView.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
            self.circleBorder.setAffineTransform(CGAffineTransform(scaleX: 1.2, y: 1.2))
            self.progressCircleBorder.setAffineTransform(CGAffineTransform(scaleX: 1.2, y: 1.2))
            animationBlock()
        }, completion: nil)
    }

    @objc func autoStopAction() {
        longPressRecognizer?.isEnabled = false
        longPressRecognizer?.isEnabled = true
    }

    func resetAnimation(animationBlock: @escaping () -> Void) {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
        self.progressCircleBorder?.removeFromSuperlayer()

        self.autoStopTimer?.invalidate()
        self.autoStopTimer = nil

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
            self.innerCircleView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.circleBorder.setAffineTransform(CGAffineTransform(scaleX: 1.0, y: 1.0))
            self.circleBorder.opacity = 1
            animationBlock()
        }, completion: { (success) in
            self.innerCircleView?.backgroundColor = UIColor.systemTint
            self.innerCircleView?.removeFromSuperview()
        })
    }

    @objc func updateProgress() {
        var progress = (CFAbsoluteTimeGetCurrent() - progressLastTime) * 1000.0 / maxDuration
        if progress > 1 {
            progress = 1
        }

        var endAngle = progress * 2.0 + 1.5
        if endAngle > 2.0 {
            endAngle -= 2.0
        }
        progressCircleBorder.path = UIBezierPath(arcCenter: centerPoint, radius: circleRadius, startAngle: 1.5 * CGFloat.pi, endAngle: CGFloat(endAngle) *  CGFloat.pi, clockwise: true).cgPath
    }

}

