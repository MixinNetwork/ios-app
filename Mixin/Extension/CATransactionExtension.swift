import QuartzCore

extension CATransaction {
    
    static func perform(blockWithTransaction block: ()->(), completion: @escaping ()->()) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        block()
        CATransaction.commit()
    }
    
    static func performWithoutAnimation(_ block: (() -> ())) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        block()
        CATransaction.commit()
    }
    
}
