@preconcurrency import CoreData

extension NSManagedObjectContext {
    /// Xcode/Swift toolchains recientes agregan overloads de `performAndWait` que a veces disparan ambigüedad.
    /// Este wrapper fuerza la firma `() -> Void`.
    func performAndWaitCompat(_ block: @escaping () -> Void) {
        let perform: (@escaping () -> Void) -> Void = self.performAndWait
        perform(block)
    }
}

