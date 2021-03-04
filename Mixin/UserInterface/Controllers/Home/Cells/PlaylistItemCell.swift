import UIKit

class PlaylistItemCell: ModernSelectedBackgroundCell, AudioCell {
    
    enum FileStatus {
        case pending
        case downloading
        case ready
    }
    
    let infoView = MusicInfoView()
    let statusImageView = UIImageView()
    let indicator = ActivityIndicatorView()
    
    var id: String?
    
    var fileStatus: FileStatus = .pending {
        didSet {
            switch fileStatus {
            case .pending:
                indicator.stopAnimating()
                statusImageView.image = R.image.ic_file_download()
                statusImageView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                infoView.setImageViewBackground(isOpaque: true)
            case .downloading:
                indicator.startAnimating()
                statusImageView.image = nil
                statusImageView.backgroundColor = .clear
                infoView.setImageViewBackground(isOpaque: false)
            case .ready:
                indicator.stopAnimating()
                statusImageView.image = nil
                statusImageView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                infoView.setImageViewBackground(isOpaque: true)
            }
        }
    }
    
    var style: AudioCellStyle = .stopped {
        didSet {
            guard fileStatus == .ready else {
                return
            }
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
        
        backgroundColor = .background
        contentView.backgroundColor = .clear
        
        contentView.addSubview(infoView)
        infoView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(38)
            make.centerY.equalToSuperview()
        }
        
        statusImageView.contentMode = .center
        statusImageView.tintColor = .white
        statusImageView.layer.cornerRadius = 19
        statusImageView.clipsToBounds = true
        contentView.addSubview(statusImageView)
        statusImageView.snp.makeConstraints { (make) in
            make.edges.equalTo(infoView.imageView)
        }
        
        indicator.tintColor = UIColor(displayP3RgbValue: 0xBCBEC3)
        contentView.addSubview(indicator)
        indicator.snp.makeConstraints { (make) in
            make.edges.equalTo(infoView.imageView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
