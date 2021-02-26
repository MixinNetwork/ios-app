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
    
    var fileStatus: FileStatus = .pending {
        didSet {
            switch fileStatus {
            case .pending:
                indicator.stopAnimating()
                statusImageView.image = R.image.ic_file_download()
            case .downloading:
                indicator.startAnimating()
                statusImageView.image = nil
            case .ready:
                indicator.stopAnimating()
                statusImageView.image = nil
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
        statusImageView.contentMode = .center
        statusImageView.tintColor = .white
        indicator.tintColor = .white
        contentView.addSubview(infoView)
        contentView.addSubview(statusImageView)
        contentView.addSubview(indicator)
        infoView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(38)
            make.centerY.equalToSuperview()
        }
        statusImageView.snp.makeConstraints { (make) in
            make.edges.equalTo(infoView.imageView)
        }
        indicator.snp.makeConstraints { (make) in
            make.edges.equalTo(infoView.imageView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
