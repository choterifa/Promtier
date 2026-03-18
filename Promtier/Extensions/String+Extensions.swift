//
//  String+Extensions.swift
//  Promtier
//
//  EXTENSIONES: Extensiones para String
//

import Foundation

extension String {
    /// Localiza un string basado en un idioma específico (AppLanguage)
    func localized(for language: AppLanguage) -> String {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
}
