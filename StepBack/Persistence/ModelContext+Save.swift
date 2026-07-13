import SwiftData

extension ModelContext {
    func saveOrRollback() throws {
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}
