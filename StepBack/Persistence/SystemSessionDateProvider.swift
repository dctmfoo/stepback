import Foundation

@MainActor
final class SystemSessionDateProvider: SessionDateProviding {
    var now: Date { .now }
}
