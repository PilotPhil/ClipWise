import Foundation

struct ModelProfile: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var modelName: String
    var baseURL: String
    var apiKey: String

    init(
        id: String = UUID().uuidString,
        modelName: String = "qwen/qwen3.6-27b",
        baseURL: String = "http://127.0.0.1:1234",
        apiKey: String = ""
    ) {
        self.id = id
        self.modelName = modelName
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
}

struct AIActionProfile: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var systemImage: String
    var customIconPNGBase64: String?
    var prompt: String
    var isBuiltIn: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        systemImage: String,
        customIconPNGBase64: String? = nil,
        prompt: String,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.customIconPNGBase64 = customIconPNGBase64
        self.prompt = prompt
        self.isBuiltIn = isBuiltIn
    }

    static let defaultProfiles: [AIActionProfile] = [
        AIActionProfile(
            id: "translate",
            name: "翻译",
            systemImage: "globe",
            prompt: "请识别图片中的英文文字，并仅将英文内容翻译为自然、准确的中文。不要总结，不要解释，不要添加图片中没有的信息。如果没有英文文字，请回答：未识别到英文内容。",
            isBuiltIn: true
        ),
        AIActionProfile(
            id: "summarize",
            name: "AI 总结",
            systemImage: "text.badge.checkmark",
            prompt: "请识别图片中的文字内容，并用中文概括核心意思。要求：先给出一句话总览，再用 3-5 个短要点说明关键信息。不要逐字翻译，重点帮助我快速理解这段文字。",
            isBuiltIn: true
        ),
        AIActionProfile(
            id: "ocr",
            name: "OCR 原文",
            systemImage: "doc.text",
            prompt: "请完整识别图片中的文字，尽量保持原文语言、段落和顺序。不要总结，不要翻译，不要添加解释。",
            isBuiltIn: true
        ),
    ]
}

struct AppSettings: Codable, Equatable, Sendable {
    var showControlWindowOnStartup = true
    var resultPanelHeight = 220
    var saveDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
    var captureHotkey = HotkeySpec()
    var providerName = "OpenAI 兼容"
    var baseURL = "http://127.0.0.1:1234"
    var apiKey = ""
    var model = "qwen/qwen3.6-27b"
    var modelOptions = ["qwen/qwen3.6-27b"]
    var modelProfiles = [ModelProfile(id: "default")]
    var activeModelProfileID = "default"
    var actionProfiles = AIActionProfile.defaultProfiles
    var requestTimeoutSeconds = 120
    var hideWindowsDuringCapture = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case showControlWindowOnStartup
        case resultPanelHeight
        case saveDirectory
        case captureHotkey
        case providerName
        case baseURL
        case apiKey
        case model
        case modelOptions
        case modelProfiles
        case activeModelProfileID
        case actionProfiles
        case requestTimeoutSeconds
        case hideWindowsDuringCapture
    }

    init(from decoder: Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showControlWindowOnStartup = try container.decodeIfPresent(Bool.self, forKey: .showControlWindowOnStartup) ?? defaults.showControlWindowOnStartup
        resultPanelHeight = try container.decodeIfPresent(Int.self, forKey: .resultPanelHeight) ?? defaults.resultPanelHeight
        saveDirectory = try container.decodeIfPresent(String.self, forKey: .saveDirectory) ?? defaults.saveDirectory
        captureHotkey = try container.decodeIfPresent(HotkeySpec.self, forKey: .captureHotkey) ?? defaults.captureHotkey
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName) ?? defaults.providerName
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? defaults.baseURL
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? defaults.apiKey
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? defaults.model
        modelOptions = try container.decodeIfPresent([String].self, forKey: .modelOptions) ?? defaults.modelOptions
        modelProfiles = try container.decodeIfPresent([ModelProfile].self, forKey: .modelProfiles) ?? []
        activeModelProfileID = try container.decodeIfPresent(String.self, forKey: .activeModelProfileID) ?? ""
        actionProfiles = try container.decodeIfPresent([AIActionProfile].self, forKey: .actionProfiles) ?? defaults.actionProfiles
        requestTimeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .requestTimeoutSeconds) ?? defaults.requestTimeoutSeconds
        hideWindowsDuringCapture = try container.decodeIfPresent(Bool.self, forKey: .hideWindowsDuringCapture) ?? defaults.hideWindowsDuringCapture

        if modelProfiles.isEmpty {
            modelProfiles = Self.legacyProfiles(modelOptions: modelOptions, model: model, baseURL: baseURL, apiKey: apiKey)
        }
        if activeModelProfileID.isEmpty {
            activeModelProfileID = modelProfiles.first(where: { $0.modelName == model })?.id ?? modelProfiles[0].id
        }
        normalize()
    }

    mutating func normalize() {
        resultPanelHeight = min(max(resultPanelHeight, 120), 600)
        requestTimeoutSeconds = min(max(requestTimeoutSeconds, 10), 600)
        providerName = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        model = model.trimmingCharacters(in: .whitespacesAndNewlines)

        var seenIDs = Set<String>()
        modelProfiles = modelProfiles.compactMap { profile in
            var normalized = profile
            normalized.id = normalized.id.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.modelName = normalized.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.baseURL = normalized.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.apiKey = normalized.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.modelName.isEmpty, !normalized.baseURL.isEmpty else { return nil }
            if normalized.id.isEmpty || seenIDs.contains(normalized.id) {
                normalized.id = UUID().uuidString
            }
            seenIDs.insert(normalized.id)
            return normalized
        }

        if modelProfiles.isEmpty {
            modelProfiles = Self.legacyProfiles(modelOptions: modelOptions, model: model, baseURL: baseURL, apiKey: apiKey)
        }
        if !modelProfiles.contains(where: { $0.id == activeModelProfileID }) {
            activeModelProfileID = modelProfiles[0].id
        }

        let active = activeModelProfile
        model = active.modelName
        baseURL = active.baseURL
        apiKey = active.apiKey
        modelOptions = Self.normalizedModelNames(modelProfiles.map(\.modelName))
        actionProfiles = Self.normalizedActionProfiles(actionProfiles)
    }

    var activeModelProfile: ModelProfile {
        modelProfiles.first(where: { $0.id == activeModelProfileID }) ?? modelProfiles[0]
    }

    mutating func selectModelProfile(id: String) {
        guard modelProfiles.contains(where: { $0.id == id }) else { return }
        activeModelProfileID = id
        normalize()
    }

    private static func legacyProfiles(
        modelOptions: [String],
        model: String,
        baseURL: String,
        apiKey: String
    ) -> [ModelProfile] {
        let names = normalizedModelNames(modelOptions + [model])
        let defaultSettings = AppSettings()
        let resolvedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? defaultSettings.baseURL : baseURL
        return names.enumerated().map { index, name in
            ModelProfile(
                id: index == 0 ? "default" : "legacy-\(index)",
                modelName: name,
                baseURL: resolvedBaseURL,
                apiKey: apiKey
            )
        }
    }

    private static func normalizedModelNames(_ models: [String]) -> [String] {
        var seen = Set<String>()
        let trimmed = models.compactMap { value -> String? in
            let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty, !seen.contains(model) else { return nil }
            seen.insert(model)
            return model
        }
        return trimmed.isEmpty ? ["qwen/qwen3.6-27b"] : trimmed
    }

    private static func normalizedActionProfiles(_ profiles: [AIActionProfile]) -> [AIActionProfile] {
        var seen = Set<String>()
        let cleaned = profiles.compactMap { profile -> AIActionProfile? in
            var normalized = profile
            normalized.id = normalized.id.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.systemImage = normalized.systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.customIconPNGBase64 = normalized.customIconPNGBase64?.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.prompt = normalized.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.name.isEmpty, !normalized.prompt.isEmpty else { return nil }
            if normalized.systemImage.isEmpty {
                normalized.systemImage = "sparkles"
            }
            if normalized.id.isEmpty || seen.contains(normalized.id) {
                normalized.id = UUID().uuidString
            }
            seen.insert(normalized.id)
            return normalized
        }

        let builtInProfiles = AIActionProfile.defaultProfiles.compactMap { defaultProfile in
            cleaned.first(where: { $0.id == defaultProfile.id })
        }
        let customProfiles = cleaned.filter { profile in
            !AIActionProfile.defaultProfiles.contains(where: { $0.id == profile.id })
        }
        return builtInProfiles + customProfiles
    }
}

struct HotkeySpec: Codable, Equatable, Sendable {
    var key = "a"
    var control = true
    var shift = true
    var option = false
    var command = false
    var fn = false

    var displayText: String {
        var parts: [String] = []
        if control { parts.append("Control") }
        if shift { parts.append("Shift") }
        if option { parts.append("Option") }
        if command { parts.append("Command") }
        if fn { parts.append("Fn") }
        parts.append(key.uppercased())
        return parts.joined(separator: " + ")
    }
}

final class SettingsStore {
    private let url: URL
    private(set) var settings: AppSettings

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("ClipWise", isDirectory: true)
        let legacyFolder = base.appendingPathComponent("SnipConclude", isDirectory: true)
        self.url = folder.appendingPathComponent("settings.json")
        self.settings = Self.load(from: url, fallbackURL: legacyFolder.appendingPathComponent("settings.json"))
    }

    func save(_ settings: AppSettings) {
        var normalized = settings
        normalized.normalize()

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(normalized)
            try data.write(to: url, options: .atomic)
            self.settings = normalized
        } catch {
            NSLog("Failed to save settings: \(error)")
        }
    }

    private static func load(from url: URL, fallbackURL: URL) -> AppSettings {
        let candidateURL = FileManager.default.fileExists(atPath: url.path) ? url : fallbackURL
        do {
            let data = try Data(contentsOf: candidateURL)
            var settings = try JSONDecoder().decode(AppSettings.self, from: data)
            settings.normalize()
            return settings
        } catch {
            return AppSettings()
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
