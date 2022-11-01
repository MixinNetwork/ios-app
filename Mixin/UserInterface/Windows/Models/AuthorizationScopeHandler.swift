import MixinServices

class AuthorizationScopeHandler {
    
    var selectedItems: [Scope.ItemInfo] {
        scopeGroups.map(\.items).reduce(into: []) { result, items in
            result.append(contentsOf: items.filter({ $0.isSelected }))
        }
    }
    
    private(set) var scopeGroups: [Scope.GroupInfo] = []
    
    init(scopeInfos: [Scope.GroupInfo]) {
        scopeGroups = scopeInfos
    }
    
    func select(item: Scope.ItemInfo) {
        guard let index = index(for: item) else {
            return
        }
        scopeGroups[index.groupIndex].items[index.itemIndex].isSelected = true
    }
    
    func deselect(item: Scope.ItemInfo) {
        guard let index = index(for: item) else {
            return
        }
        scopeGroups[index.groupIndex].items[index.itemIndex].isSelected = false
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
