import UIKit
import MixinServices

protocol ImageCropViewControllerDelegate: AnyObject {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage)
    
}

class ImageCropViewController: UIViewController {
    
    weak var delegate: ImageCropViewControllerDelegate?
    
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let highlightingLayer = CAShapeLayer()
    
    private let highlightMargin: CGFloat = 15
    
    private var highlightPath: UIBezierPath!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        scrollView.snp.makeEdgesEqualToSuperview()
        
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
    }
    
    func load(image: UIImage) {
        loadViewIfNeeded()
        
        let imageSize = image.size * image.scale
        let fittingSize = view.bounds.size
        let imageFrame = imageSize.rect(fittingSize: fittingSize)
        let fittingScale: CGFloat
        if imageSize.width / imageSize.height > 1 {
            fittingScale = max(1, fittingSize.height / imageFrame.height)
        } else {
            fittingScale = max(1, fittingSize.width / imageFrame.width)
        }
        imageView.frame = imageFrame
        scrollView.contentSize = imageFrame.size
        scrollView.maximumZoomScale = max(fittingScale, 3)
        scrollView.contentOffset = .zero
        UIGraphicsBeginImageContextWithOptions(imageFrame.size, false, UIScreen.main.scale)
        image.draw(in: CGRect(origin: .zero, size: imageFrame.size))
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        centerZoomView()
    }
    
}

extension ImageCropViewController {
    
    @objc private func performCropping() {
        if let image = imageView.image {
            let area = {
                let factor = max(image.size.height * image.scale / view.frame.height, image.size.width * image.scale / view.frame.width)
                let scale = 1 / scrollView.zoomScale
                let imageFrame = imageView.frame
                let x: CGFloat
                if imageFrame.width <= highlightPath.bounds.width {
                    x = scrollView.contentOffset.x * scale * factor
                } else {
                    x = (scrollView.contentOffset.x + highlightPath.bounds.origin.x - imageFrame.origin.x) * scale * factor
                }
                let y: CGFloat
                if imageFrame.height <= highlightPath.bounds.height {
                    y = scrollView.contentOffset.y * scale * factor
                } else {
                    y = (scrollView.contentOffset.y + highlightPath.bounds.origin.y - imageFrame.origin.y) * scale * factor
                }
                let width = highlightPath.bounds.width * scale * factor
                let height = highlightPath.bounds.height * scale * factor
                return CGRect(x: x, y: y, width: width, height: height)
            }()
            guard let croppedCGImage = image.cgImage?.cropping(to: area) else {
                return
            }
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            delegate?.imageCropViewController(self, didCropImage: croppedImage)
        }
        dismiss(animated: true)
    }
    
    @objc private func cancelCropping() {
        dismiss(animated: true)
    }
    
}

extension ImageCropViewController: UIScrollViewDelegate {
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
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
        centerZoomView()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
    
}

extension ImageCropViewController {
    
    private func layoutHightlightingLayer() {
        let diameter = view.bounds.width - highlightMargin * 2
        let highlightBounds = CGRect(x: highlightMargin, y: (view.bounds.height - diameter) / 2, width: diameter, height: diameter)
        highlightPath = UIBezierPath(ovalIn: highlightBounds)
        let path = UIBezierPath(rect: view.bounds)
        path.usesEvenOddFillRule = true
        path.append(highlightPath)
        highlightingLayer.path = path.cgPath
    }
    
    private func centerZoomView() {
        let verticalInset: CGFloat
        let horizontalInset: CGFloat
        if scrollView.contentSize.width >= view.bounds.width {
            horizontalInset = highlightMargin
        } else {
            horizontalInset = 0
        }
        if scrollView.contentSize.height >= view.bounds.height {
            verticalInset = (view.bounds.height - highlightPath.bounds.height) / 2
        } else {
            verticalInset = 0
        }
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }
    
}
