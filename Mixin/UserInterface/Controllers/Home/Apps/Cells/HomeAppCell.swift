import Foundation

protocol HomeAppCell: ShakableCell {
    var imageContainerView: UIView! { get }
    var label: UILabel? { get }
    var snapshotView: HomeAppsSnapshotView? { get }
    var generalItem: AppItem? { get set }
}
