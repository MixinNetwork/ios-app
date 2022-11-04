import MixinServices

class AuthorizationScopeDataSource {
    
    let groups: [AuthorizationScope.Group]
    let scopes: [AuthorizationScope.Group: [AuthorizationScope]]
    
    // Cannot be deselected by user
    let arbitraryScopes: Set<AuthorizationScope> = [.readProfile]
    
    var selectedScopes: [AuthorizationScope] {
        var authorizationScopes = [AuthorizationScope]()
        for group in groups {
            if let selected = scopes[group]?.filter(temporarilySelectedScopes.contains) {
                authorizationScopes.append(contentsOf: selected)
            }
        }
        return authorizationScopes
    }
    
    private var temporarilySelectedScopes: Set<AuthorizationScope> = []
    
    init (response: AuthorizationResponse) {
        let allScopes = response.scopes.compactMap(AuthorizationScope.init(rawValue:))
        let groups = AuthorizationScope.Group.allCases.filter { group in
            allScopes.contains(where: group.scopes.contains)
        }
        let scopes = groups.reduce(into: [:]) { partialResult, group in
            partialResult[group] = allScopes.filter(group.scopes.contains)
        }
        self.temporarilySelectedScopes = Set(allScopes)
        self.groups = groups
        self.scopes = scopes
    }
    
    func scopeDetail(at indexPath: IndexPath) -> (group: AuthorizationScope.Group, scopes: [AuthorizationScope])? {
        let group = groups[indexPath.row]
        if let groupScopes = self.scopes[group] {
            return (group, groupScopes)
        } else {
            return nil
        }
    }
    
    func select(_ scope: AuthorizationScope) {
        temporarilySelectedScopes.insert(scope)
    }
    
    func deselect(_ scope: AuthorizationScope) {
        temporarilySelectedScopes.remove(scope)
    }
    
    func isSelected(_ scope: AuthorizationScope) -> Bool {
        temporarilySelectedScopes.contains(scope)
    }
    
}
