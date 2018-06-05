import UIKit

class EmptyView: UIStackView {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var tipsLabel: UILabel!

    func render(text: String, photo: UIImage, superView: UIView) {
        iconImageView.image = photo
        tipsLabel.text = text

        superView.addSubview(self)
        self.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    class func instance() -> EmptyView {
        let view = Bundle.main.loadNibNamed("EmptyView", owner: nil, options: nil)?.first as! EmptyView
        return view
    }

}

extension UITableView {

    func checkEmpty(dataCount: Int, text: String, photo: UIImage) {
        guard let superView = self.superview else {
            return
        }
        if dataCount == 0 {
            guard self.subviews.first(where: { $0 is EmptyView }) == nil else {
                return
            }
            EmptyView.instance().render(text: text, photo: photo, superView: superView)
        } else {
            self.subviews.first(where: { $0 is EmptyView })?.removeFromSuperview()
        }
    }

}
