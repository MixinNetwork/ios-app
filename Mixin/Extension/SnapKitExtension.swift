import SnapKit

extension ConstraintPriority {
    
    static let almostRequired = ConstraintPriority(999)
    
}

extension ConstraintViewDSL {
    
    func makeEdgesEqualToSuperview() {
        makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
}
