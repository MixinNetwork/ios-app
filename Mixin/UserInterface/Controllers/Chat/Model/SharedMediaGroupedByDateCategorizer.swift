import Foundation

class SharedMediaGroupedByDateCategorizer<ItemType: SharedMediaItem>: SharedMediaCategorizer<ItemType> {
    
    override func input(items: [ItemType], didLoadEarliest: Bool) {
        var allItems = items
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
            wantsMoreInput = false
        } else {
            if dates.count > 1 {
                wantsMoreInput = false
                let date = dates.removeLast()
                if let lastItemGroup = itemGroups[date] {
                    itemGroups[date] = nil
                    allItems.removeLast(lastItemGroup.count)
                }
            } else {
                wantsMoreInput = true
            }
        }
    }
    
}
