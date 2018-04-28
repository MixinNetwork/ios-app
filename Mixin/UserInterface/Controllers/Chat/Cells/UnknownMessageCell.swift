import UIKit

class UnknownMessageCell: TextMessageCell {

    override func prepare() {
        super.prepare()
        timeLabel.textColor = .white
    }

}
