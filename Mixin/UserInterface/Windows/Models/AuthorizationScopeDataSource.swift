import MixinServices

class AuthorizationScopeDataSource {
    
    // Cannot be deselected by user
    let arbitraryScopes: Set<AuthorizationScope> = [.readProfile]
    
    let groups: [AuthorizationScope.Group]
    let groupedScopes: [[AuthorizationScope]]
    let scopes: [AuthorizationScope]
    
    private(set) var selectedScopes: Set<AuthorizationScope>
    
    init(response: AuthorizationResponse) {
        let responseScopes = response.scopes.compactMap(AuthorizationScope.init(rawValue:))
        let groups = AuthorizationScope.Group.allCases.filter { group in
            responseScopes.contains(where: group.scopes.contains)
        }
        let groupedScopes = groups.map { group in
            responseScopes.filter(group.scopes.contains)
        }
        
        self.groups = groups
        self.groupedScopes = groupedScopes
        self.scopes = groupedScopes.flatMap { $0 }
        self.selectedScopes = Set(responseScopes)
    }
    
    func select(scope: AuthorizationScope) {
        selectedScopes.insert(scope)
    }
    
    // Return false if the scope cannot be deselected
    func deselect(scope: AuthorizationScope) -> Bool {
        if arbitraryScopes.contains(scope) {
            return false
        } else {
            selectedScopes.remove(scope)
            return true
        }
    }
    
}
