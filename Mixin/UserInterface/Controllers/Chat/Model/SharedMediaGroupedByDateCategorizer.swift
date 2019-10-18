import Foundation

class SharedMediaGroupedByDateCategorizer<ItemType: SharedMediaItem>: SharedMediaCategorizer<ItemType> {
    
    override class var itemGroupIsAscending: Bool {
        return true
    }
    
    override func input(items: [ItemType], didLoadEarliest: Bool) {
        for item in items {
            let title = type(of: self).groupTitle(for: item)
            if itemGroups[title] != nil {
                itemGroups[title]!.insert(item, at: 0)
            } else {
                dates.append(title)
                itemGroups[title] = [item]
            }
        }
        if didLoadEarliest {
            categorizedMessageIds.formUnion(items.map({ $0.messageId }))
            wantsMoreInput = false
        } else {
            if dates.count > 1 {
                let date = dates.removeLast()
                itemGroups[date] = nil
                categorizedMessageIds.formUnion(itemGroups.values.flatMap({ $0 }).map({ $0.messageId }))
                wantsMoreInput = false
            } else {
                categorizedMessageIds.formUnion(items.map({ $0.messageId }))
                wantsMoreInput = true
            }
        }
    }
    
}
