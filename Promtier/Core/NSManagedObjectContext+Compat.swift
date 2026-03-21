@preconcurrency import CoreData

extension NSManagedObjectContext {
    /// Xcode/Swift toolchains recientes agregan overloads de `performAndWait` que a veces disparan ambigüedad.
    /// Este wrapper fuerza la firma `() -> Void`.
    @preconcurrency func performAndWaitCompat<T>(_ block: @Sendable () -> T) -> T {
        self.performAndWait(block)
    }
}

