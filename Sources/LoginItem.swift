import Foundation

// Автозапуск для скачанной сборки: тот же LaunchAgent, что ставит build.sh --install.
// launchd подхватит файл при следующем входе в систему.
enum LoginItem {
    static func install() {
        // Из карантина macOS запускает временную копию: ее путь после перезагрузки нерабочий.
        guard let label = Bundle.main.bundleIdentifier,
              let executable = Bundle.main.executablePath,
              !executable.contains("/AppTranslocation/") else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
        if let data = try? Data(contentsOf: url),
           let current = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           (current["ProgramArguments"] as? [String])?.first == executable { return }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "LimitLoadToSessionType": "Aqua",
            "ProcessType": "Interactive",
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
