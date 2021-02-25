import UIKit

final class PlaylistSlider: UISlider {
    
    var percentage: Double {
        percentage(for: value)
    }
    
    private let trackHeight: CGFloat = 4
    private let hitTestAreaHeight: CGFloat = 44
    private let knobSize = R.image.playlist.ic_knob()!.size
    
    private lazy var knobShapePaddingWidth = (knobSize.width - 12) / 2
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: 0,
               y: (bounds.height - trackHeight) / 2,
               width: bounds.width,
               height: trackHeight)
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        CGRect(x: bounds.width * percentage(for: value) - knobShapePaddingWidth,
               y: (bounds.height - knobSize.height) / 2,
               width: knobSize.width,
               height: knobSize.height)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitTestBounds = CGRect(x: bounds.origin.x,
                                   y: bounds.origin.y - (hitTestAreaHeight - bounds.height) / 2,
                                   width: bounds.width,
                                   height: hitTestAreaHeight)
        return hitTestBounds.contains(point)
    }
    
    private func prepare() {
        setThumbImage(R.image.playlist.ic_knob(), for: .normal)
        setThumbImage(R.image.playlist.ic_knob(), for: .highlighted)
    }
    
    private func percentage<Percentage: BinaryFloatingPoint>(for value: Float) -> Percentage {
        Percentage(value - minimumValue) / Percentage(maximumValue - minimumValue)
    }
    
}
