import UIKit

final class ShareObiSurroundedView<ContentView: UIView>: UIView {
    
    enum Spacing {
        case normal
        case compact
    }
    
    let contentView: ContentView
    let obiView = ShareObiView()
    
    init(contentView: ContentView, spacing: Spacing) {
        self.contentView = contentView
        super.init(frame: .zero)
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(54)
            make.leading.equalToSuperview().offset(18)
            make.trailing.equalToSuperview().offset(-18)
        }
        addSubview(obiView)
        obiView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            switch spacing {
            case .normal:
                switch ScreenHeight.current {
                case .short:
                    make.top.equalTo(contentView.snp.bottom).offset(24)
                case .medium:
                    make.top.equalTo(contentView.snp.bottom).offset(32)
                default:
                    make.top.equalTo(contentView.snp.bottom).offset(36)
                }
            case .compact:
                switch ScreenHeight.current {
                case .short:
                    make.top.equalTo(contentView.snp.bottom).offset(4)
                case .medium:
                    make.top.equalTo(contentView.snp.bottom).offset(8)
                default:
                    make.top.equalTo(contentView.snp.bottom).offset(36)
                }
            }
            make.height.equalTo(100)
        }
        obiView.load(content: .installMixin(gradient: true))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}

