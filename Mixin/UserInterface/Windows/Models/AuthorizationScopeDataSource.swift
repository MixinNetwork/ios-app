import MixinServices

class AuthorizationScopeDataSource {
    
    enum Modifier {
        case preview
        case confirmation
    }
    
    // Cannot be deselected by user
    let arbitraryScopes: Set<AuthorizationScope> = [.readProfile]
    
    let groups: [AuthorizationScope.Group]
    let scopes: [[AuthorizationScope]]
    
    // Modify with `Modifier.preview`
    private(set) var pendingConfirmationScopes: [AuthorizationScope]
    
    // Modify with `Modifier.confirmation`
    private(set) var confirmedScopes: Set<AuthorizationScope>
    
    init(response: AuthorizationResponse) {
        let responseScopes = response.scopes.compactMap(AuthorizationScope.init(rawValue:))
        let groups = AuthorizationScope.Group.allCases.filter { group in
            responseScopes.contains(where: group.scopes.contains)
        }
        let groupedScopes = groups.map { group in
            responseScopes.filter(group.scopes.contains)
        }
        let scopesInGroupOrder = groupedScopes.flatMap { $0 }
        
        self.groups = groups
        self.scopes = groupedScopes
        self.pendingConfirmationScopes = scopesInGroupOrder
        self.confirmedScopes = Set(scopesInGroupOrder)
    }
    
    func startConfirmation() {
        confirmedScopes = Set(pendingConfirmationScopes)
    }
    
    func isScope(_ scope: AuthorizationScope, selectedBy modifier: Modifier) -> Bool {
        switch modifier {
        case .preview:
            return pendingConfirmationScopes.contains(scope)
        case .confirmation:
            return confirmedScopes.contains(scope)
        }
    }
    
    func select(scope: AuthorizationScope, by modifier: Modifier) {
        switch modifier {
        case .preview:
            if !pendingConfirmationScopes.contains(scope) {
                var selectedScopes = Set(pendingConfirmationScopes)
                selectedScopes.insert(scope)
                pendingConfirmationScopes = self.scopes.flatMap { scopes in
                    scopes.filter(selectedScopes.contains)
                }
            }
        case .confirmation:
            confirmedScopes.insert(scope)
        }
    }
    
    // Return false if the scope cannot be deselected
    func deselect(scope: AuthorizationScope, by modifier: Modifier) -> Bool {
        if arbitraryScopes.contains(scope) {
            return false
        } else {
            switch modifier {
            case .preview:
                if let index = pendingConfirmationScopes.firstIndex(of: scope) {
                    pendingConfirmationScopes.remove(at: index)
                }
            case .confirmation:
                confirmedScopes.remove(scope)
            }
            return true
        }
    }
    
}
