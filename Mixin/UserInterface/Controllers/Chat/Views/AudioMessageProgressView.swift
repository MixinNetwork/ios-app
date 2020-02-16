import UIKit

class AudioMessageProgressView: UIStackView {
    
    let waveformWrapperView = UIView()
    let waveformView = WaveformView()
    let highlightedWaveformView = WaveformView()
    let lengthLabel = UILabel()
    
    init() {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .leading
        spacing = 4
        
        lengthLabel.textColor = .accessoryText
        lengthLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        lengthLabel.adjustsFontForContentSizeCategory = true
        
        highlightedWaveformView.tintColor = R.color.audio_waveform_progress()!
        
        for view in [waveformView, highlightedWaveformView] {
            waveformWrapperView.addSubview(view)
            view.snp.makeEdgesEqualToSuperview()
        }
        
        waveformWrapperView.snp.makeConstraints { (make) in
            make.height.equalTo(23)
        }
        [waveformWrapperView, lengthLabel].forEach(addArrangedSubview(_:))
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
