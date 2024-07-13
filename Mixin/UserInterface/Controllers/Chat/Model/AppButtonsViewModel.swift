import Foundation

final class AppButtonGroupViewModel {
    
    private(set) var frames: [CGRect] = []
    private(set) var buttonGroupFrame: CGRect = .zero
    
    private let maxNumberOfButtonsPerLine = 3
    
    func layout(lineWidth: CGFloat, contents: [String]) {
        var frames: [CGRect] = []
        var buttonGroupFrame: CGRect? = nil
        
        let maxNumberOfButtons = min(contents.count, maxNumberOfButtonsPerLine)
        let distributions = stride(from: maxNumberOfButtons, to: 1, by: -1).map { number in
            (number, round(lineWidth / CGFloat(number)))
        }
        let buttonSizes: [CGSize] = contents.map { content in
            AppButtonView.boundingSize(with: lineWidth, title: content)
        }
        
        var nextButtonIndex: Int = 0
        var nextLineY: CGFloat = .zero
        while nextButtonIndex < buttonSizes.count {
            let index = nextButtonIndex
            let y = nextLineY
            
            let (numberOfButtons, width) = distributions.first { (numberOfButtons, width) in
                let lastIndex = index + numberOfButtons - 1
                return if lastIndex < buttonSizes.count {
                    buttonSizes[index...lastIndex].allSatisfy { size in
                        size.width <= width
                    }
                } else {
                    false
                }
            } ?? (1, lineWidth)
            
            let newFrames = buttonSizes[index..<(index + numberOfButtons)]
                .map { size in
                    CGSize(width: width, height: size.height)
                }
                .enumerated()
                .map { (index, size) in
                    CGRect(x: CGFloat(index) * size.width, y: y, width: size.width, height: size.height)
                }
            frames.append(contentsOf: newFrames)
            
            nextButtonIndex += numberOfButtons
            if let lastFrame = newFrames.last {
                if let group = buttonGroupFrame {
                    buttonGroupFrame = group.union(lastFrame)
                } else {
                    buttonGroupFrame = newFrames.reduce(into: .zero) { result, frame in
                        result = result?.union(frame) ?? frame
                    }
                }
                nextLineY = lastFrame.maxY
            }
        }
        
        self.frames = frames
        self.buttonGroupFrame = buttonGroupFrame ?? .zero
    }
    
}
