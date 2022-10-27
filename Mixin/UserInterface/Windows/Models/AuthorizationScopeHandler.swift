import MixinServices

protocol AuthorizationScopeHandlerDelegate: AnyObject {
    
    func authorizationScopeHandlerDeselectLastScope(_ handler: AuthorizationScopeHandler)
    
}

class AuthorizationScopeHandler {
    
    weak var delegate: AuthorizationScopeHandlerDelegate?
    
    var canDeselect: Bool {
        selectedItems.count > 1
    }
    
    var selectedItems: [Scope.ItemInfo] {
        scopeGroups.map(\.items).reduce(into: []) { result, items in
            result.append(contentsOf: items.filter({ $0.isSelected }))
        }
    }
    
    private(set) var scopeGroups: [Scope.GroupInfo] = []
    
    init(scopeInfos: [Scope.GroupInfo]) {
        scopeGroups = scopeInfos
    }
    
    func selectScope(item: Scope.ItemInfo) {
        guard let index = index(for: item) else {
            return
        }
        scopeGroups[index.groupIndex].items[index.itemIndex].isSelected = true
    }
    
    func deselectScope(item: Scope.ItemInfo) {
        guard let index = index(for: item) else {
            return
        }
        scopeGroups[index.groupIndex].items[index.itemIndex].isSelected = false
    }
    
    func deselectLastScope() {
        delegate?.authorizationScopeHandlerDeselectLastScope(self)
    }
    
    private func index(for item: Scope.ItemInfo) -> (groupIndex: Int, itemIndex: Int)? {
        var groupIndex: Int?
        var itemIndex: Int?
        for gIndex in 0..<scopeGroups.count {
            if let iIndex = scopeGroups[gIndex].items.firstIndex(of: item) {
                groupIndex = gIndex
                itemIndex = iIndex
                break
            }
        }
        if let groupIndex, let itemIndex {
            return (groupIndex, itemIndex)
        } else {
            return nil
        }
    }
    
}
