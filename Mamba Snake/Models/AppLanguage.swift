import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case system
    case tr
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.string("language.system")
        case .tr: return "Türkçe"
        case .en: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .tr: return Locale(identifier: "tr")
        case .en: return Locale(identifier: "en")
        }
    }

    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    static var effectiveCode: String {
        switch selected {
        case .tr: return "tr"
        case .en: return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("tr") ? "tr" : "en"
        }
    }
}

enum L10n {
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let code = AppLanguage.effectiveCode
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)

        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: code), arguments: arguments)
    }
}
