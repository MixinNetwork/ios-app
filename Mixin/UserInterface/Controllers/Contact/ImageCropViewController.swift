import UIKit
import MixinServices

protocol ImageCropViewControllerDelegate: AnyObject {
    
    func imageCropViewController(_ controller: ImageCropViewController, didCropImage croppedImage: UIImage)
    
}

class ImageCropViewController: UIViewController {
    
    weak var delegate: ImageCropViewControllerDelegate?
    
    var image: UIImage!
    
    private var imageView: UIImageView!
    private var scrollView: UIScrollView!
    private var circlePath: UIBezierPath!
    
    private let marginForCirclePath: CGFloat = 15
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
}

extension ImageCropViewController {
    
    private func setupUI() {
        view.backgroundColor = .black
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        scrollView.snp.makeEdgesEqualToSuperview()
        
        let diameter = view.bounds.width - marginForCirclePath * 2
        let rectForCirclePath = CGRect(x: marginForCirclePath, y: (view.bounds.height - diameter) / 2, width: diameter, height: diameter)
        circlePath = UIBezierPath(ovalIn: rectForCirclePath)
        let path = UIBezierPath(rect: view.bounds)
        path.append(circlePath)
        path.usesEvenOddFillRule = true
        let fillLayer = CAShapeLayer()
        fillLayer.fillRule = .evenOdd
        fillLayer.fillColor = UIColor.black.withAlphaComponent(0.7).cgColor
        fillLayer.lineWidth = 1
        fillLayer.path = path.cgPath
        view.layer.addSublayer(fillLayer)
        
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
        
        let hitLabel = UILabel()
        hitLabel.text = R.string.localizable.move_and_scale()
        hitLabel.textColor = .white
        view.addSubview(hitLabel)
        hitLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
        }
        let cancelButton = UIButton()
        cancelButton.setTitle(R.string.localizable.cancel(), for: .normal)
        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        let confirmButton = UIButton()
        confirmButton.setTitle(R.string.localizable.confirm(), for: .normal)
        view.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        confirmButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
    }
    
    private func centerZoomView() {
        let verticalInset: CGFloat
        let horizontalInset: CGFloat
        if scrollView.contentSize.width >= view.bounds.width {
            horizontalInset = marginForCirclePath
        } else {
            horizontalInset = 0
        }
        if scrollView.contentSize.height >= view.bounds.height {
            verticalInset = (view.bounds.height - circlePath.bounds.height) / 2
        } else {
            verticalInset = 0
        }
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }
    
    private func cropImage() {
        guard let image = imageView.image else {
            return
        }
        let area = cropArea(for: image)
        guard let croppedCGImage = image.cgImage?.cropping(to: area) else {
            return
        }
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        delegate?.imageCropViewController(self, didCropImage: croppedImage)
    }
    
    private func cropArea(for image: UIImage) -> CGRect {
        let factor = max(image.size.height * image.scale / view.frame.height, image.size.width * image.scale / view.frame.width)
        let scale = 1 / scrollView.zoomScale
        let imageFrame = imageView.frame
        let x: CGFloat
        if imageFrame.width <= circlePath.bounds.width {
            x = scrollView.contentOffset.x * scale * factor
        } else {
            x = (scrollView.contentOffset.x + circlePath.bounds.origin.x - imageFrame.origin.x) * scale * factor
        }
        let y: CGFloat
        if imageFrame.height <= circlePath.bounds.height {
            y = scrollView.contentOffset.y * scale * factor
        } else {
            y = (scrollView.contentOffset.y + circlePath.bounds.origin.y - imageFrame.origin.y) * scale * factor
        }
        let width = circlePath.bounds.width * scale * factor
        let height = circlePath.bounds.height * scale * factor
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
}

extension ImageCropViewController {
    
    @objc private func confirmAction() {
        cropImage()
        dismiss(animated: true)
    }
    
    @objc private func cancelAction() {
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
