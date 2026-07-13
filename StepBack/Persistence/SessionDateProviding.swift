import Foundation

@MainActor
protocol SessionDateProviding: AnyObject {
    var now: Date { get }
}
