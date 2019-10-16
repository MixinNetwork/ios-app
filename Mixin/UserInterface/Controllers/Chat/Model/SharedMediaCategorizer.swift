import Foundation

class SharedMediaCategorizer<ItemType: SharedMediaItem> {
    
    var categorizedItems = [ItemType]()
    var dates = [String]()
    var itemGroups = [String: [ItemType]]()
    var wantsMoreInput = true
    
    required init() {
        
    }
    
    static func groupTitle(for item: ItemType) -> String {
        let date = item.createdAt.toUTCDate()
        return DateFormatter.dateSimple.string(from: date)
    }
    
    func input(items: [ItemType], didLoadEarliest: Bool) {
        self.categorizedItems = items
        for item in items {
            let title = type(of: self).groupTitle(for: item)
            if itemGroups[title] != nil {
                itemGroups[title]!.append(item)
            } else {
                dates.append(title)
                itemGroups[title] = [item]
            }
        }
        wantsMoreInput = false
    }
    
}
