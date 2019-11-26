import UIKit

class EmptyView: UIStackView {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var tipsLabel: UILabel!

    func render(text: String, photo: UIImage, container: UIView) {
        iconImageView.image = photo
        tipsLabel.text = text
        container.addSubview(self)
        self.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-container.frame.height / 5)
        }
    }

    class func instance() -> EmptyView {
        let view = Bundle.main.loadNibNamed("EmptyView", owner: nil, options: nil)?.first as! EmptyView
        return view
    }

}

extension UIView {

    func checkEmpty(dataCount: Int, text: String, photo: UIImage) {
        if dataCount == 0 {
            guard self.subviews.first(where: { $0 is EmptyView }) == nil else {
                return
            }
            EmptyView.instance().render(text: text, photo: photo, container: self)
        } else {
            self.subviews.first(where: { $0 is EmptyView })?.removeFromSuperview()
        }
    }

}
