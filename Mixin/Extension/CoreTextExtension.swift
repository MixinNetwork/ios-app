import CoreText

extension CTLine {
    
    func frame(forRange range: NSRange, lineOrigin: CGPoint) -> CGRect? {
        var highlightRect: CGRect?
        let runs = CTLineGetGlyphRuns(self) as! [CTRun]
        for run in runs {
            let cfRunRange = CTRunGetStringRange(run)
            let runRange = NSRange(cfRange: cfRunRange)
            if let intersection = runRange.intersection(range) {
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let highlightRange = CFRange(location: intersection.location - runRange.location, length: intersection.length)
                let width = CGFloat(CTRunGetTypographicBounds(run, highlightRange, &ascent, &descent, &leading))
                let offsetX = CTLineGetOffsetForStringIndex(self, intersection.location, nil)
                let newRect = CGRect(x: lineOrigin.x + offsetX - leading,
                                     y: lineOrigin.y - descent,
                                     width: width + leading,
                                     height: ascent + descent)
                if let oldRect = highlightRect {
                    highlightRect = oldRect.union(newRect)
                } else {
                    highlightRect = newRect
                }
            }
        }
        return highlightRect
    }
    
}
