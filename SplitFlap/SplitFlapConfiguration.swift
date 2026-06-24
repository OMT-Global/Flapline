import AppKit
import Foundation
import ScreenSaver

enum SplitFlapDisplayMode: String, CaseIterable {
    case random
    case messages
    case clock
    case date

    var title: String {
        switch self {
        case .random: return "Random"
        case .messages: return "Messages"
        case .clock: return "Clock"
        case .date: return "Date"
        }
    }
}

enum SplitFlapMessageOrder: String, CaseIterable {
    case sequential
    case random

    var title: String {
        switch self {
        case .sequential: return "Sequential"
        case .random: return "Random"
        }
    }
}

enum SplitFlapRandomAlphabet: String, CaseIterable {
    case classic
    case latinExtended
    case cyrillic
    case greek
    case arabic
    case mixedWorld

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .latinExtended: return "Latin Extended"
        case .cyrillic: return "Cyrillic"
        case .greek: return "Greek"
        case .arabic: return "Arabic"
        case .mixedWorld: return "Mixed World"
        }
    }

    var characters: [SplitFlapCharacter] {
        switch self {
        case .classic:
            return SplitFlapCharacter.drumCharacters
        case .latinExtended:
            return Self.makeCharacters(
                " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-/:"
                + "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝ"
                + "àáâãäåæçèéêëìíîïñòóôõöøùúûüýÿ"
            )
        case .cyrillic:
            return Self.makeCharacters(
                " АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
                + "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
            )
        case .greek:
            return Self.makeCharacters(
                " ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"
                + "αβγδεζηθικλμνξοπρστυφχψω"
                + "άέήίόύώϊϋΐΰ"
            )
        case .arabic:
            return Self.makeCharacters(" ابتثجحخدذرزسشصضطظعغفقكلمنهويءآأؤإئىة")
        case .mixedWorld:
            return Self.unique(
                SplitFlapCharacter.drumCharacters
                + SplitFlapRandomAlphabet.latinExtended.characters
                + SplitFlapRandomAlphabet.cyrillic.characters
                + SplitFlapRandomAlphabet.greek.characters
                + SplitFlapRandomAlphabet.arabic.characters
            )
        }
    }

    private static func makeCharacters(_ string: String) -> [SplitFlapCharacter] {
        unique(string.map { SplitFlapCharacter(String($0)) })
    }

    private static func unique(_ characters: [SplitFlapCharacter]) -> [SplitFlapCharacter] {
        var seen = Set<SplitFlapCharacter>()
        return characters.filter { seen.insert($0).inserted }
    }
}

struct SplitFlapPalette {
    let identifier: String
    let panelBackground: CGColor
    let character: CGColor
    let divider: CGColor
    let screenBg: CGColor
}

enum SplitFlapTheme: String, CaseIterable {
    case classic
    case terminal
    case monochrome

    var title: String {
        switch self {
        case .classic: return "Classic Amber"
        case .terminal: return "Terminal Green"
        case .monochrome: return "Monochrome"
        }
    }

    var palette: SplitFlapPalette {
        switch self {
        case .classic:
            return SplitFlapPalette(
                identifier: rawValue,
                panelBackground: CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0),
                character: CGColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 1.0),
                divider: CGColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1.0),
                screenBg: CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)
            )
        case .terminal:
            return SplitFlapPalette(
                identifier: rawValue,
                panelBackground: CGColor(red: 0.02, green: 0.05, blue: 0.04, alpha: 1.0),
                character: CGColor(red: 0.35, green: 1.0, blue: 0.58, alpha: 1.0),
                divider: CGColor(red: 0.0, green: 0.02, blue: 0.015, alpha: 1.0),
                screenBg: CGColor(red: 0.01, green: 0.025, blue: 0.02, alpha: 1.0)
            )
        case .monochrome:
            return SplitFlapPalette(
                identifier: rawValue,
                panelBackground: CGColor(red: 0.08, green: 0.08, blue: 0.085, alpha: 1.0),
                character: CGColor(red: 0.94, green: 0.94, blue: 0.9, alpha: 1.0),
                divider: CGColor(red: 0.015, green: 0.015, blue: 0.018, alpha: 1.0),
                screenBg: CGColor(red: 0.035, green: 0.035, blue: 0.04, alpha: 1.0)
            )
        }
    }
}

struct SplitFlapConfiguration {
    var displayMode: SplitFlapDisplayMode = .messages
    var messageText: String = "Flapline\nUnicode OK\nHello World"
    var messageOrder: SplitFlapMessageOrder = .sequential
    var messageHoldSeconds: TimeInterval = 4
    var waveIntervalSeconds: TimeInterval = 8
    var randomAlphabet: SplitFlapRandomAlphabet = .classic
    var idleShuffleEnabled: Bool = true
    var idleDensity: Double = 0.04
    var targetRows: Int = 9
    var theme: SplitFlapTheme = .classic

    var messages: [String] {
        let lines = messageText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? ["Flapline"] : lines
    }

    func rowCount(isPreview: Bool) -> Int {
        if isPreview {
            return min(max(3, targetRows), 5)
        }
        return min(max(4, targetRows), 24)
    }
}

enum SplitFlapConfigurationStore {
    private static let moduleName = "app.flapline.screensaver"
    private static let legacyModuleName = "com.omt.SplitFlap"

    private enum Key {
        static let displayMode = "displayMode"
        static let messageText = "messageText"
        static let messageOrder = "messageOrder"
        static let messageHoldSeconds = "messageHoldSeconds"
        static let waveIntervalSeconds = "waveIntervalSeconds"
        static let randomAlphabet = "randomAlphabet"
        static let idleShuffleEnabled = "idleShuffleEnabled"
        static let idleDensity = "idleDensity"
        static let targetRows = "targetRows"
        static let theme = "theme"

        static let all = [
            displayMode,
            messageText,
            messageOrder,
            messageHoldSeconds,
            waveIntervalSeconds,
            randomAlphabet,
            idleShuffleEnabled,
            idleDensity,
            targetRows,
            theme
        ]
    }

    private static var defaults: UserDefaults {
        ScreenSaverDefaults(forModuleWithName: moduleName) ?? .standard
    }

    static func load() -> SplitFlapConfiguration {
        let fallback = SplitFlapConfiguration()
        let defaults = defaults
        migrateLegacyDefaultsIfNeeded(to: defaults)
        defaults.register(defaults: [
            Key.displayMode: fallback.displayMode.rawValue,
            Key.messageText: fallback.messageText,
            Key.messageOrder: fallback.messageOrder.rawValue,
            Key.messageHoldSeconds: fallback.messageHoldSeconds,
            Key.waveIntervalSeconds: fallback.waveIntervalSeconds,
            Key.randomAlphabet: fallback.randomAlphabet.rawValue,
            Key.idleShuffleEnabled: fallback.idleShuffleEnabled,
            Key.idleDensity: fallback.idleDensity,
            Key.targetRows: fallback.targetRows,
            Key.theme: fallback.theme.rawValue
        ])

        return SplitFlapConfiguration(
            displayMode: SplitFlapDisplayMode(rawValue: defaults.string(forKey: Key.displayMode) ?? "") ?? fallback.displayMode,
            messageText: defaults.string(forKey: Key.messageText) ?? fallback.messageText,
            messageOrder: SplitFlapMessageOrder(rawValue: defaults.string(forKey: Key.messageOrder) ?? "") ?? fallback.messageOrder,
            messageHoldSeconds: bounded(defaults.double(forKey: Key.messageHoldSeconds), min: 0, max: 30, fallback: fallback.messageHoldSeconds),
            waveIntervalSeconds: bounded(defaults.double(forKey: Key.waveIntervalSeconds), min: 2, max: 60, fallback: fallback.waveIntervalSeconds),
            randomAlphabet: SplitFlapRandomAlphabet(rawValue: defaults.string(forKey: Key.randomAlphabet) ?? "") ?? fallback.randomAlphabet,
            idleShuffleEnabled: defaults.object(forKey: Key.idleShuffleEnabled) as? Bool ?? fallback.idleShuffleEnabled,
            idleDensity: bounded(defaults.double(forKey: Key.idleDensity), min: 0, max: 0.2, fallback: fallback.idleDensity),
            targetRows: min(max(defaults.integer(forKey: Key.targetRows), 4), 24),
            theme: SplitFlapTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? fallback.theme
        )
    }

    static func save(_ configuration: SplitFlapConfiguration) {
        let defaults = defaults
        defaults.set(configuration.displayMode.rawValue, forKey: Key.displayMode)
        defaults.set(configuration.messageText, forKey: Key.messageText)
        defaults.set(configuration.messageOrder.rawValue, forKey: Key.messageOrder)
        defaults.set(configuration.messageHoldSeconds, forKey: Key.messageHoldSeconds)
        defaults.set(configuration.waveIntervalSeconds, forKey: Key.waveIntervalSeconds)
        defaults.set(configuration.randomAlphabet.rawValue, forKey: Key.randomAlphabet)
        defaults.set(configuration.idleShuffleEnabled, forKey: Key.idleShuffleEnabled)
        defaults.set(configuration.idleDensity, forKey: Key.idleDensity)
        defaults.set(configuration.targetRows, forKey: Key.targetRows)
        defaults.set(configuration.theme.rawValue, forKey: Key.theme)
        defaults.synchronize()
    }

    private static func migrateLegacyDefaultsIfNeeded(to defaults: UserDefaults) {
        guard !hasSavedConfiguration(in: defaults),
              let legacyDefaults = ScreenSaverDefaults(forModuleWithName: legacyModuleName),
              hasSavedConfiguration(in: legacyDefaults)
        else { return }

        for key in Key.all {
            if let value = legacyDefaults.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.synchronize()
    }

    private static func hasSavedConfiguration(in defaults: UserDefaults) -> Bool {
        Key.all.contains { defaults.object(forKey: $0) != nil }
    }

    private static func bounded(_ value: Double, min: Double, max: Double, fallback: Double) -> Double {
        guard value.isFinite, value >= min, value <= max else { return fallback }
        return value
    }
}

final class SplitFlapContentProvider {
    private var configuration: SplitFlapConfiguration
    private var messageIndex = 0
    private var messagePageIndex = 0

    init(configuration: SplitFlapConfiguration) {
        self.configuration = configuration
    }

    func update(configuration: SplitFlapConfiguration) {
        self.configuration = configuration
        messageIndex = min(messageIndex, max(configuration.messages.count - 1, 0))
        messagePageIndex = 0
    }

    func nextTargets(rows: Int, cols: Int, preview: Bool = false) -> [[SplitFlapCharacter]] {
        targets(rows: rows, cols: cols, preview: preview, advanceMessages: true)
    }

    func immediateTargets(
        rows: Int,
        cols: Int,
        preview: Bool = false,
        advanceMessages: Bool = false
    ) -> [[SplitFlapCharacter]] {
        targets(rows: rows, cols: cols, preview: preview, advanceMessages: advanceMessages)
    }

    private func targets(
        rows: Int,
        cols: Int,
        preview: Bool,
        advanceMessages: Bool
    ) -> [[SplitFlapCharacter]] {
        switch configuration.displayMode {
        case .random:
            if preview {
                return textTargets(["Flapline"], rows: rows, cols: cols)
            }
            return randomTargets(rows: rows, cols: cols)
        case .messages:
            return textTargets(messagePage(advance: advanceMessages, rows: rows, cols: cols), rows: rows, cols: cols)
        case .clock:
            return textTargets([Self.clockFormatter.string(from: Date())], rows: rows, cols: cols)
        case .date:
            return textTargets([Self.dateFormatter.string(from: Date())], rows: rows, cols: cols)
        }
    }

    private func messagePage(advance: Bool, rows: Int, cols: Int) -> [[SplitFlapCharacter]] {
        let messages = configuration.messages
        let message: String
        switch configuration.messageOrder {
        case .sequential:
            message = messages[messageIndex % messages.count]
        case .random:
            message = messages.randomElement() ?? "Flapline"
        }

        let pageRows = pagedLines(message, rows: rows, cols: cols)
        let currentPage = min(messagePageIndex, max(pageRows.count - 1, 0))
        let visiblePage = pageRows.isEmpty ? [[SplitFlapCharacter.space]] : pageRows[currentPage]

        if advance {
            advanceMessageCursor(pageCount: max(pageRows.count, 1))
        }

        return visiblePage
    }

    private func advanceMessageCursor(pageCount: Int) {
        switch configuration.messageOrder {
        case .sequential:
            if messagePageIndex + 1 < pageCount {
                messagePageIndex += 1
            } else {
                messagePageIndex = 0
                messageIndex = (messageIndex + 1) % configuration.messages.count
            }
        case .random:
            messagePageIndex = 0
        }
    }

    private func randomTargets(rows: Int, cols: Int) -> [[SplitFlapCharacter]] {
        (0..<rows).map { _ in
            (0..<cols).map { _ in SplitFlapCharacter.random(in: configuration.randomAlphabet) }
        }
    }

    private func textTargets(_ textLines: [String], rows: Int, cols: Int) -> [[SplitFlapCharacter]] {
        textTargets(textLines.map { SplitFlapCharacter.characters(in: $0) }, rows: rows, cols: cols)
    }

    private func textTargets(_ textLines: [[SplitFlapCharacter]], rows: Int, cols: Int) -> [[SplitFlapCharacter]] {
        var targets = Array(
            repeating: Array(repeating: SplitFlapCharacter.space, count: cols),
            count: rows
        )
        guard rows > 0, cols > 0 else { return targets }

        let inset = textInset(rows: rows, cols: cols)
        let contentRows = max(1, rows - inset * 2)
        let contentCols = max(1, cols - inset * 2)
        let wrapped = textLines.flatMap { wrappedLines($0, maxWidth: contentCols) }
        let visibleLines = Array(wrapped.prefix(contentRows))
        let startRow = inset + max(0, (contentRows - visibleLines.count) / 2)

        for (offset, line) in visibleLines.enumerated() {
            let characters = Array(line.prefix(contentCols))
            let startCol = inset + max(0, (contentCols - characters.count) / 2)
            for (index, character) in characters.enumerated() {
                targets[startRow + offset][startCol + index] = character
            }
        }

        return targets
    }

    private func pagedLines(_ text: String, rows: Int, cols: Int) -> [[[SplitFlapCharacter]]] {
        let inset = textInset(rows: rows, cols: cols)
        let contentRows = max(1, rows - inset * 2)
        let contentCols = max(1, cols - inset * 2)
        let wrapped = wrappedLines(text, maxWidth: contentCols)
        guard !wrapped.isEmpty else { return [[[.space]]] }

        return stride(from: 0, to: wrapped.count, by: contentRows).map { start in
            Array(wrapped[start..<min(start + contentRows, wrapped.count)])
        }
    }

    private func wrappedLines(_ text: String, maxWidth: Int) -> [[SplitFlapCharacter]] {
        let characters = SplitFlapCharacter.characters(in: text)
        return wrappedLines(characters, maxWidth: maxWidth)
    }

    private func wrappedLines(_ characters: [SplitFlapCharacter], maxWidth: Int) -> [[SplitFlapCharacter]] {
        guard !characters.isEmpty else { return [[.space]] }
        guard maxWidth > 0 else { return [] }

        var lines: [[SplitFlapCharacter]] = []
        var index = 0
        while index < characters.count {
            let end = min(index + maxWidth, characters.count)
            lines.append(Array(characters[index..<end]))
            index = end
        }
        return lines
    }

    private func textInset(rows: Int, cols: Int) -> Int {
        rows > 2 && cols > 2 ? 1 : 0
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
