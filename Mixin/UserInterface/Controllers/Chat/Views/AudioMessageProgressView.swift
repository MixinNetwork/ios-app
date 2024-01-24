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
        
        lengthLabel.textColor = R.color.text_tertiary()!
        lengthLabel.font = MessageFontSet.cardSubtitle.scaled
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
