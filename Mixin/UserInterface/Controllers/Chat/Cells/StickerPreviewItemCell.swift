import UIKit

class StickerPreviewItemCell: UICollectionViewCell {
    
    let stickerView = AnimatedStickerView()
    
    var image: UIImage? {
        stickerView.imageViewIfLoaded?.image
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stickerView.prepareForReuse()
    }
    
    private func loadSubview() {
        let selectedBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        selectedBackgroundView.backgroundColor = R.color.album_selected()
        selectedBackgroundView.layer.cornerRadius = 13
        selectedBackgroundView.clipsToBounds = true
        self.selectedBackgroundView = selectedBackgroundView
        stickerView.clipsToBounds = true
        stickerView.layer.cornerRadius = 10
        stickerView.backgroundColor = .clear
        stickerView.contentMode = .scaleAspectFit
        contentView.addSubview(stickerView)
        stickerView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        }
    }
    
}
