import Foundation

enum WidgetStorage {
    static var appGroupIdentifier: String {
        if let configuredIdentifier = Bundle.main.object(
            forInfoDictionaryKey: "StressWatchAppGroupIdentifier"
        ) as? String, !configuredIdentifier.isEmpty {
            return configuredIdentifier
        }

        return fallbackAppGroupIdentifier
    }

    private static let fallbackAppGroupIdentifier = "group.com.stresswatch.demo"
    private static let fileName = "widget_snapshot.json"

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func save(_ snapshot: WidgetSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: try snapshotURL(), options: [.atomic])
    }

    static func load() -> WidgetSnapshot? {
        guard let url = try? snapshotURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    private static func snapshotURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw WidgetStorageError.missingAppGroupContainer(appGroupIdentifier)
        }

        return containerURL.appendingPathComponent(fileName, isDirectory: false)
    }
}

enum WidgetStorageError: LocalizedError {
    case missingAppGroupContainer(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroupContainer(let identifier):
            return "App Group container is unavailable: \(identifier)"
        }
    }
}
