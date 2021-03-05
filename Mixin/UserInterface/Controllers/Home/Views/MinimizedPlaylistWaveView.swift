import UIKit

class MinimizedPlaylistWaveView: UIView {
    
    var isAnimating: Bool {
        get {
            return _isAnimating
        }
        set(wantsAnimation) {
            if wantsAnimation {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    private let interbarSpace: CGFloat = 2
    private let barWidth: CGFloat = 2
    private let barHeights: [CGFloat] = [4, 10, 14, 10, 4]
    private let barBackgroundLayer = CALayer()
    private let minBarHeight: CGFloat
    private let maxBarHeight: CGFloat
    
    private var barLayers: [CAShapeLayer] = []
    private var _isAnimating = false
    
    required init?(coder: NSCoder) {
        minBarHeight = barHeights.min()!
        maxBarHeight = barHeights.max()!
        super.init(coder: coder)
        layer.addSublayer(barBackgroundLayer)
        setupLayers()
        updateWaveBarColor()
        registerForNotifications()
    }
    
    override init(frame: CGRect) {
        minBarHeight = barHeights.min()!
        maxBarHeight = barHeights.max()!
        super.init(frame: frame)
        layer.addSublayer(barBackgroundLayer)
        setupLayers()
        updateWaveBarColor()
        registerForNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        barBackgroundLayer.position = CGPoint(x: layer.bounds.width / 2,
                                              y: layer.bounds.height / 2)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            updateWaveBarColor()
        }
    }
    
    func startAnimating() {
        guard !_isAnimating else {
            return
        }
        setupAnimation()
        _isAnimating = true
    }
    
    func stopAnimating() {
        guard _isAnimating else {
            return
        }
        for (index, layer) in barLayers.enumerated() {
            let presentationPath = layer.presentation()?.path
            let stopPath = barPath(for: barHeights[index])
            layer.removeAllAnimations()
            layer.path = stopPath
            let anim = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
            anim.fromValue = presentationPath
            anim.toValue = stopPath
            anim.duration = 0.2
            barLayers[index].add(anim, forKey: "path")
        }
        _isAnimating = false
    }
    
}

extension MinimizedPlaylistWaveView {
    
    private func setupLayers() {
        let backgroundWidth = CGFloat(barHeights.count) * barWidth
            + CGFloat(barHeights.count - 1) * interbarSpace
        barBackgroundLayer.bounds.size = CGSize(width: backgroundWidth, height: maxBarHeight)
        barBackgroundLayer.backgroundColor = UIColor.clear.cgColor
        
        barLayers.reserveCapacity(barHeights.count)
        for (index, height) in barHeights.enumerated() {
            let layer = CAShapeLayer()
            layer.bounds.size = CGSize(width: barWidth, height: maxBarHeight)
            layer.path = barPath(for: height)
            layer.position = CGPoint(x: CGFloat(index) * (barWidth + interbarSpace),
                                     y: barBackgroundLayer.bounds.height / 2)
            barBackgroundLayer.addSublayer(layer)
            barLayers.append(layer)
        }
    }
    
    private func updateWaveBarColor() {
        let color = R.color.icon_tint()!.cgColor
        for layer in barLayers {
            layer.fillColor = color
        }
    }
    
    private func registerForNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(applicationDidEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(applicationWillEnterForeground),
                           name: UIApplication.willEnterForegroundNotification,
                           object: nil)
    }
    
    private func setupAnimation() {
        guard window != nil else {
            return
        }
        for (index, height) in barHeights.enumerated() {
            let anim = CABasicAnimation(keyPath: #keyPath(CAShapeLayer.path))
            if height == minBarHeight {
                anim.fromValue = barPath(for: minBarHeight)
                anim.toValue = barPath(for: maxBarHeight)
            } else if height == maxBarHeight {
                anim.fromValue = barPath(for: maxBarHeight)
                anim.toValue = barPath(for: minBarHeight)
            } else {
                anim.fromValue = barPath(for: minBarHeight)
                anim.toValue = barPath(for: maxBarHeight)
                anim.timeOffset = CFTimeInterval(height / maxBarHeight)
            }
            anim.duration = 1
            anim.repeatCount = .infinity
            anim.autoreverses = true
            barLayers[index].add(anim, forKey: "path")
        }
    }
    
    private func barPath(for height: CGFloat) -> CGPath {
        let rect = CGRect(x: 0,
                          y: (maxBarHeight - height) / 2,
                          width: barWidth,
                          height: height)
        return CGPath(roundedRect: rect,
                      cornerWidth: barWidth / 2,
                      cornerHeight: barWidth / 2,
                      transform: nil)
    }
    
}

extension MinimizedPlaylistWaveView {
    
    @objc private func applicationDidEnterBackground() {
        barLayers.forEach {
            $0.removeAllAnimations()
        }
    }
    
    @objc private func applicationWillEnterForeground() {
        if _isAnimating {
            setupAnimation()
        }
    }
    
}
