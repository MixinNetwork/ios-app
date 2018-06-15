import UIKit

class RecorderLongPressHintView: UIImageView {

    static let labelHorizontalMargin: CGFloat = 8
    static let labelFont = UIFont.systemFont(ofSize: 15)
    static let contentSize: CGSize = {
        let textSize = (Localized.CHAT_VOICE_RECORD_LONGPRESS_HINT as NSString)
            .size(withAttributes: [.font: RecorderLongPressHintView.labelFont])
        let textWidth = ceil(textSize.width)
        return CGSize(width: textWidth + labelHorizontalMargin * 2, height: #imageLiteral(resourceName: "bg_recorder_longpress_hint").size.height)
    }()
    
    let label = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    init() {
        let frame = CGRect(origin: .zero, size: RecorderLongPressHintView.contentSize)
        super.init(frame: frame)
        prepare()
    }
    
    override var intrinsicContentSize: CGSize {
        return RecorderLongPressHintView.contentSize
    }
    
    private func prepare() {
        image = #imageLiteral(resourceName: "bg_recorder_longpress_hint")
        label.preferredMaxLayoutWidth = UIScreen.main.bounds.width - RecorderLongPressHintView.labelHorizontalMargin * 2
        label.numberOfLines = 0
        label.text = Localized.CHAT_VOICE_RECORD_LONGPRESS_HINT
        label.textColor = .white
        label.font = RecorderLongPressHintView.labelFont
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-4)
        }
    }

}
