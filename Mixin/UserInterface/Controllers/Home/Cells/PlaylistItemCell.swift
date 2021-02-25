import UIKit

class PlaylistItemCell: ModernSelectedBackgroundCell, AudioCell {
    
    let infoView = MusicInfoView()
    let statusImageView = UIImageView()
    
    var style: AudioCellStyle = .stopped {
        didSet {
            switch style {
            case .playing:
                statusImageView.image = R.image.ic_pause()
            case .stopped, .paused:
                statusImageView.image = R.image.ic_play()
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        statusImageView.contentMode = .center
        statusImageView.tintColor = .white
        addSubview(infoView)
        addSubview(statusImageView)
        infoView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(38)
            make.centerY.equalToSuperview()
        }
        statusImageView.snp.makeConstraints { (make) in
            make.edges.equalTo(infoView.imageView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
