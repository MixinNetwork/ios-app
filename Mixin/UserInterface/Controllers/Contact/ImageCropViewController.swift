import UIKit
import MixinServices

#if DEBUG
fileprivate var debugCropping = false
fileprivate var orientation: UIImage.Orientation = .up {
    didSet {
        Logger.general.debug(category: "ImageCropViewController", message: "Testing orientation: \(orientation)")
    }
}
#endif

protocol ImageCropViewControllerDelegate: AnyObject {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage)
    
}

class ImageCropViewController: UIViewController {
    
    weak var delegate: ImageCropViewControllerDelegate?
    
    private let scrollView = ScrollView()
    private let imageView = UIImageView()
    private let highlightingLayer = CAShapeLayer()
    
    private let highlightMargin: CGFloat = 15
    private let maximumZoomScale: CGFloat = 3
    
    private var lastScrollViewFrameWhenReset: CGRect?
    
    private var highlightBounds: CGRect {
        let diameter = view.bounds.width - highlightMargin * 2
        return CGRect(x: highlightMargin,
                      y: (view.bounds.height - diameter) / 2,
                      width: diameter,
                      height: diameter)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        view.backgroundColor = .black
        imageView.contentMode = .scaleToFill
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        scrollView.addSubview(imageView)
        scrollView.clipsToBounds = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.equalToSuperview().offset(highlightMargin)
            make.trailing.equalToSuperview().offset(-highlightMargin)
            make.width.equalTo(scrollView.snp.height)
        }
        
        highlightingLayer.fillRule = .evenOdd
        highlightingLayer.fillColor = UIColor.black.withAlphaComponent(0.7).cgColor
        highlightingLayer.lineWidth = 1
        view.layer.addSublayer(highlightingLayer)
        layoutHightlightingLayer()
        
        let instructionLabel = UILabel()
        instructionLabel.text = R.string.localizable.move_and_scale()
        instructionLabel.textColor = .white
        view.addSubview(instructionLabel)
        instructionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
        }
        
        let cancelButton = UIButton()
        cancelButton.setTitle(R.string.localizable.cancel(), for: .normal)
        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.width.height.greaterThanOrEqualTo(44)
        }
        cancelButton.addTarget(self, action: #selector(cancelCropping), for: .touchUpInside)
        
        let confirmButton = UIButton()
        confirmButton.setTitle(R.string.localizable.confirm(), for: .normal)
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.width.height.greaterThanOrEqualTo(44)
        }
        confirmButton.addTarget(self, action: #selector(performCropping), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHightlightingLayer()
        layoutImageView()
        resetScrollView(force: false)
    }
    
    func load(image: UIImage) {
        loadViewIfNeeded()
#if DEBUG
        var image = image
        if debugCropping {
            image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: orientation)
        }
#endif
        imageView.image = image
        imageView.bounds.size = image.size.sizeThatFills(highlightBounds.size)
        imageView.center = .zero
        scrollView.zoomScale = 1
        scrollView.contentSize = imageView.frame.size
        resetScrollView(force: true)
    }
    
}

extension ImageCropViewController {
    
    @objc private func performCropping() {
        if let image = imageView.image {
            let visibleRect = scrollView.convert(scrollView.bounds, to: imageView)
            let mirrorTransform: CGAffineTransform = .identity
                .translatedBy(x: image.size.width, y: 0)
                .scaledBy(x: -1, y: 1)
            let rotatedMirrorTransform: CGAffineTransform = .identity
                .translatedBy(x: image.size.height, y: 0)
                .scaledBy(x: -1, y: 1)
            var transform = CGAffineTransform(scaleX: image.size.width / imageView.bounds.width,
                                              y: image.size.height / imageView.bounds.height)
            switch image.imageOrientation {
            case .up:
                break
            case .down:
                let t = CGAffineTransform(rotationAngle: -.pi)
                    .translatedBy(x: -image.size.width, y: -image.size.height)
                transform = transform.concatenating(t)
            case .left:
                let t = CGAffineTransform(rotationAngle: .pi / 2)
                    .translatedBy(x: 0, y: -image.size.height)
                transform = transform.concatenating(t)
            case .right:
                let t = CGAffineTransform(rotationAngle: -.pi / 2)
                    .translatedBy(x: -image.size.width, y: 0)
                transform = transform.concatenating(t)
            case .upMirrored:
                transform = transform.concatenating(mirrorTransform)
            case .downMirrored:
                let t = CGAffineTransform(rotationAngle: -.pi)
                    .translatedBy(x: -image.size.width, y: -image.size.height)
                transform = transform.concatenating(mirrorTransform).concatenating(t)
            case .leftMirrored:
                let t = CGAffineTransform(rotationAngle: .pi / 2)
                    .translatedBy(x: 0, y: -image.size.height)
                transform = transform.concatenating(t).concatenating(rotatedMirrorTransform)
            case .rightMirrored:
                let t = CGAffineTransform(rotationAngle: -.pi / 2)
                    .translatedBy(x: -image.size.width, y: 0)
                transform = transform.concatenating(t).concatenating(rotatedMirrorTransform)
            @unknown default:
                break
            }
            let croppingRect = visibleRect.applying(transform)
            if let cgImage = image.cgImage?.cropping(to: croppingRect) {
                let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
#if DEBUG
                if debugCropping {
                    let debugImageView = UIImageView(image: cropped)
                    view.addSubview(debugImageView)
                    debugImageView.snp.makeConstraints { make in
                        make.width.equalTo(debugImageView.snp.height)
                        make.leading.equalToSuperview().offset(highlightMargin)
                        make.trailing.equalToSuperview().offset(-highlightMargin)
                        make.center.equalToSuperview()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        debugImageView.removeFromSuperview()
                        var next = orientation.rawValue + 1
                        if next > UIImage.Orientation.rightMirrored.rawValue {
                            next = UIImage.Orientation.up.rawValue
                        }
                        orientation = UIImage.Orientation(rawValue: next) ?? .up
                        self.load(image: image)
                    }
                    return
                }
#endif
                delegate?.imageCropViewController(self, didCropImage: cropped)
            }
        }
        dismiss(animated: true)
    }
    
    @objc private func cancelCropping() {
        dismiss(animated: true)
    }
    
}

extension ImageCropViewController: UIScrollViewDelegate {
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        layoutImageView()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
}

extension ImageCropViewController {
    
    private class ScrollView: UIScrollView {
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            true
        }
        
    }
    
    private func layoutHightlightingLayer() {
        let highlightPath = UIBezierPath(ovalIn: highlightBounds)
        let path = UIBezierPath(rect: view.bounds)
        path.usesEvenOddFillRule = true
        path.append(highlightPath)
        highlightingLayer.path = path.cgPath
    }
    
    private func layoutImageView() {
        let visibleSize = scrollView.frame.size
        if scrollView.contentSize.width < visibleSize.width {
            imageView.center.x = visibleSize.width / 2
        } else {
            imageView.center.x = scrollView.contentSize.width / 2
        }
        if scrollView.contentSize.height < visibleSize.height {
            imageView.center.y = visibleSize.height / 2
        } else {
            imageView.center.y = scrollView.contentSize.height / 2
        }
    }
    
    private func resetScrollView(force: Bool) {
        guard force || scrollView.frame != lastScrollViewFrameWhenReset else {
            return
        }
        scrollView.maximumZoomScale = {
            let verticalScale = max(1, view.bounds.height / imageView.frame.height)
            let horizontalScale = max(1, view.bounds.width / imageView.frame.width)
            return max(maximumZoomScale, verticalScale, horizontalScale)
        }()
        scrollView.contentOffset = CGPoint(x: (scrollView.contentSize.width - scrollView.frame.width) / 2,
                                           y: (scrollView.contentSize.height - scrollView.frame.height) / 2)
        lastScrollViewFrameWhenReset = scrollView.frame
    }
    
}
