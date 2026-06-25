import Foundation

enum ResultUtilityAction: String, CaseIterable {
    case copy
    case save

    var tooltip: String {
        switch self {
        case .copy: return "复制最近一次结果"
        case .save: return "保存当前截图为 PNG"
        }
    }

    var systemImage: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .save: return "square.and.arrow.down"
        }
    }
}

struct OpenAICompatibleClient: Sendable {
    func process(action: AIActionProfile, imagePNG: Data, settings: AppSettings) async throws -> String {
        let dataURL = "data:image/png;base64,\(imagePNG.base64EncodedString())"
        let payload = ChatRequest(
            model: settings.model,
            messages: [
                ChatMessage(
                    role: "system",
                    content: .text("你是一个精确、克制的图片文字识别助手。你只能根据图片中可见内容回答，不要编造。")
                ),
                ChatMessage(
                    role: "user",
                    content: .parts([
                        .init(type: "text", text: action.prompt, imageURL: nil),
                        .init(type: "image_url", text: nil, imageURL: .init(url: dataURL)),
                    ])
                ),
            ],
            temperature: 0.2,
            maxTokens: 1400
        )

        var request = URLRequest(url: chatCompletionsURL(baseURL: settings.baseURL))
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(settings.requestTimeoutSeconds)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIClientError.http(status: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let error = decoded.error {
            throw OpenAIClientError.service(String(describing: error))
        }
        guard let firstChoice = decoded.choices?.first else {
            throw OpenAIClientError.missingContent
        }
        let rawText = firstChoice.message?.content?.textValue ?? firstChoice.text ?? ""
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw OpenAIClientError.emptyContent
        }
        return text
    }

    private func chatCompletionsURL(baseURL: String) -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)!
        }
        if trimmed.hasSuffix("/v1") {
            return URL(string: "\(trimmed)/chat/completions")!
        }
        return URL(string: "\(trimmed)/v1/chat/completions")!
    }
}

enum OpenAIClientError: LocalizedError {
    case http(status: Int, body: String)
    case service(String)
    case missingContent
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .http(let status, let body):
            return "AI 服务返回 HTTP \(status)：\(body)"
        case .service(let message):
            return "AI 服务返回错误：\(message)"
        case .missingContent:
            return "AI 服务响应中没有可读取的文本内容。"
        case .emptyContent:
            return "模型返回了空结果。"
        }
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Encodable {
    let role: String
    let content: MessageContent
}

private enum MessageContent: Encodable, Decodable {
    case text(String)
    case parts([ContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .text(value)
        } else {
            self = .parts((try? container.decode([ContentPart].self)) ?? [])
        }
    }

    var textValue: String {
        switch self {
        case .text(let value):
            return value
        case .parts(let parts):
            return parts.compactMap(\.text).joined(separator: "\n")
        }
    }
}

private struct ContentPart: Codable {
    let type: String
    let text: String?
    let imageURL: ImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct ImageURL: Codable {
    let url: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]?
    let error: JSONValue?
}

private struct Choice: Decodable {
    let message: ResponseMessage?
    let text: String?
}

private struct ResponseMessage: Decodable {
    let content: MessageContent?
}

private indirect enum JSONValue: Decodable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array((try? container.decode([JSONValue].self)) ?? [])
        }
    }

    var description: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        case .object(let value): return value.description
        case .array(let value): return value.description
        case .null: return "null"
        }
    }
}
