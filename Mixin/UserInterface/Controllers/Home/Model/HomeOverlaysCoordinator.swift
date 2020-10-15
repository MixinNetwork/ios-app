import UIKit

class HomeOverlaysCoordinator {
    
    private var overlays = NSHashTable<UIView>(options: .weakMemory)
    
    func register(overlay: UIView) {
        overlays.add(overlay)
    }
    
    func unregister(overlay: UIView) {
        overlays.remove(overlay)
    }
    
    func update(center: CGPoint, for anchorOverlay: UIView) {
        anchorOverlay.center = center
        let sortedOverlays = overlays.allObjects
            .filter {
                $0.alpha != 0 && !$0.isHidden
            }
            .sorted { (one, another) -> Bool in
                one.center.y < another.center.y
            }
        guard sortedOverlays.count != 0 else {
            return
        }
        
        func moveUpwardIfIntersected(forAnyOverlayAbove index: Int) {
            guard index != 0 else {
                return
            }
            for index in stride(from: index - 1, through: 0, by: -1) {
                let overlay = sortedOverlays[index]
                let overlayBelow = sortedOverlays[index + 1]
                let diff = overlay.frame.maxY - overlayBelow.frame.minY
                if diff > 0 && !overlay.frame.intersection(overlayBelow.frame).isNull {
                    overlay.center.y -= diff
                }
            }
        }
        
        func moveDownwardIfIntersected(forAnyOverlayBelow index: Int) {
            guard index + 1 < sortedOverlays.count else {
                return
            }
            for index in (index + 1)..<sortedOverlays.count {
                let overlay = sortedOverlays[index]
                let overlayAbove = sortedOverlays[index - 1]
                let diff = overlayAbove.frame.maxY - overlay.frame.minY
                if diff > 0 && !overlay.frame.intersection(overlayAbove.frame).isNull {
                    overlay.center.y += diff
                }
            }
        }
        
        if let anchorIndex = sortedOverlays.firstIndex(of: anchorOverlay) {
            moveUpwardIfIntersected(forAnyOverlayAbove: anchorIndex)
            moveDownwardIfIntersected(forAnyOverlayBelow: anchorIndex)
        }
        
        if let superview = sortedOverlays[0].superview {
            let maxY = superview.bounds.height - superview.safeAreaInsets.bottom
            for (index, overlay) in sortedOverlays.enumerated() {
                let diff = overlay.frame.maxY - maxY
                if diff > 0 {
                    overlay.center.y -= diff
                    moveUpwardIfIntersected(forAnyOverlayAbove: index)
                }
            }
            
            let minY = superview.safeAreaInsets.top
            for (index, overlay) in sortedOverlays.enumerated() {
                let diff = minY - overlay.frame.minY
                if diff > 0 {
                    overlay.center.y += diff
                    moveDownwardIfIntersected(forAnyOverlayBelow: index)
                }
            }
        }
    }
    
}
