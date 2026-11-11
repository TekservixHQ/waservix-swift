import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends a request and returns the raw body and response. Swap it out in tests
/// or to add your own logging, retries or proxy.
public typealias WAservixTransport = (URLRequest) async throws -> (Data, HTTPURLResponse)

/// Thrown when the API answers with an error. A 503 means the device is reconnecting: retry shortly.
public struct WAservixError: Error, LocalizedError, CustomStringConvertible {
    /// HTTP status (0 when the request never reached the API).
    public let status: Int
    public let message: String
    /// Field errors, when the API sends them.
    public let errors: JSONValue?
    /// Parsed JSON body, or the raw text in `.string` when it was not JSON.
    public let body: JSONValue?
    /// Seconds to wait before retrying (sent with 429).
    public let retryAfter: Double?

    public var description: String { "WAservix: \(message) (HTTP \(status))" }
    public var errorDescription: String? { description }
}

/// Swift client for the WAservix WhatsApp API Gateway (https://tekservix.com/waservix/).
///
///     let wa = WAservixClient(apiKey: ProcessInfo.processInfo.environment["WASERVIX_KEY"]!)
///     let res = try await wa.sendText(to: "+15551234567", text: "Hello Aline, your order is ready")
///
/// Keep the key on your server. Never ship it inside an iOS or macOS app.
public final class WAservixClient {
    public static let version = "1.0.1"
    public static let defaultBaseURL = "https://tekservix.com/waservix/api"

    public let baseURL: String
    private let apiKey: String
    private let timeout: TimeInterval
    private let transport: WAservixTransport

    /// - Parameters:
    ///   - apiKey: device API key (Devices -> API key), or a personal access token for session management.
    ///   - baseURL: change only for testing.
    ///   - timeout: seconds per request.
    ///   - transport: custom HTTP sender; defaults to `URLSession.shared`.
    public init(apiKey: String, baseURL: String = WAservixClient.defaultBaseURL, timeout: TimeInterval = 30, transport: WAservixTransport? = nil) {
        precondition(!apiKey.isEmpty, "WAservix: apiKey is required (Devices -> API key in the WAservix dashboard)")
        self.apiKey = apiKey
        var url = baseURL
        while url.hasSuffix("/") { url.removeLast() }
        self.baseURL = url
        self.timeout = timeout
        self.transport = transport ?? WAservixClient.urlSessionTransport(.shared)
    }

    /// Default transport built on URLSession (works on Apple platforms and Linux).
    public static func urlSessionTransport(_ session: URLSession) -> WAservixTransport {
        return { request in
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let http = response as? HTTPURLResponse {
                        continuation.resume(returning: (data ?? Data(), http))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                task.resume()
            }
        }
    }

    // MARK: - Any endpoint

    /// Call any documented endpoint, e.g. `request("GET", "/groups")`. Returns the `data` field.
    @discardableResult
    public func request(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> JSONValue {
        guard let url = URL(string: baseURL + path) else {
            throw WAservixError(status: 0, message: "Invalid URL: \(baseURL + path)", errors: nil, body: nil, retryAfter: nil)
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method.uppercased()
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("waservix-swift/\(WAservixClient.version)", forHTTPHeaderField: "User-Agent")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }

        let (data, response) = try await transport(req)
        let status = response.statusCode
        let json: JSONValue? = data.isEmpty ? nil : try? JSONDecoder().decode(JSONValue.self, from: data)

        if status >= 400 || json?["success"] == .bool(false) {
            throw WAservixError(
                status: status,
                message: json?["message"]?.stringValue ?? "HTTP \(status)",
                errors: json?["errors"],
                body: json ?? .string(String(decoding: data, as: UTF8.self)),
                retryAfter: header(response, "Retry-After").flatMap { Double($0) }
            )
        }
        if let inner = json?["data"] { return inner }
        return json ?? .null
    }

    // MARK: - Sending

    /// Send any message type to a number or a group JID (`...@g.us`). Field names follow the API:
    /// text, imageUrl, videoUrl, audioUrl, documentUrl, fileName, stickerUrl, contact, location,
    /// poll, replyTo, mentions, viewOnce.
    /// - Returns: `{"msgId": ..., "jid": ..., "status": "in_progress"}`.
    @discardableResult
    public func sendMessage(to: String, fields: [String: Any]) async throws -> JSONValue {
        precondition(!to.isEmpty, "sendMessage: \"to\" is required (international number or group JID)")
        var body = fields
        body["to"] = to
        return try await request("POST", "/send-message", body: body)
    }

    @discardableResult
    public func sendText(to: String, text: String) async throws -> JSONValue {
        try await sendMessage(to: to, fields: ["text": text])
    }

    @discardableResult
    public func sendImage(to: String, imageURL: String, caption: String? = nil) async throws -> JSONValue {
        var fields: [String: Any] = ["imageUrl": imageURL]
        if let caption = caption { fields["text"] = caption }
        return try await sendMessage(to: to, fields: fields)
    }

    @discardableResult
    public func sendDocument(to: String, documentURL: String, fileName: String? = nil, caption: String? = nil) async throws -> JSONValue {
        var fields: [String: Any] = ["documentUrl": documentURL]
        if let fileName = fileName { fields["fileName"] = fileName }
        if let caption = caption { fields["text"] = caption }
        return try await sendMessage(to: to, fields: fields)
    }

    @discardableResult
    public func sendLocation(to: String, latitude: Double, longitude: Double, name: String? = nil) async throws -> JSONValue {
        var location: [String: Any] = ["latitude": latitude, "longitude": longitude]
        if let name = name { location["name"] = name }
        return try await sendMessage(to: to, fields: ["location": location])
    }

    // MARK: - Messages

    /// Status: queued, sent, delivered, read, played or failed.
    public func getMessageInfo(_ msgId: CustomStringConvertible) async throws -> JSONValue {
        try await request("GET", "/messages/\(escape(msgId))/info")
    }

    /// Edit one of your own text messages (about 15 minutes after sending).
    @discardableResult
    public func editMessage(_ msgId: CustomStringConvertible, text: String) async throws -> JSONValue {
        try await request("PUT", "/messages/\(escape(msgId))", body: ["text": text])
    }

    @discardableResult
    public func deleteMessage(_ msgId: CustomStringConvertible) async throws -> JSONValue {
        try await request("DELETE", "/messages/\(escape(msgId))")
    }

    @discardableResult
    public func resendMessage(_ msgId: CustomStringConvertible) async throws -> JSONValue {
        try await request("POST", "/messages/\(escape(msgId))/resend")
    }

    // MARK: - Number, contacts and groups

    /// Is this number on WhatsApp? Returns `{"exists": true/false, "jid": ...}`.
    public func onWhatsApp(_ phone: String) async throws -> JSONValue {
        try await request("GET", "/on-whatsapp/\(escape(phone))")
    }

    /// connected, connecting, need_scan, disconnected, logged_out or expired.
    public func getStatus() async throws -> JSONValue {
        try await request("GET", "/status")
    }

    public func getUser() async throws -> JSONValue {
        try await request("GET", "/user")
    }

    public func listContacts() async throws -> JSONValue {
        try await request("GET", "/contacts")
    }

    public func getContact(_ phone: String) async throws -> JSONValue {
        try await request("GET", "/contacts/\(escape(phone))")
    }

    @discardableResult
    public func saveContact(phone: String, name: String) async throws -> JSONValue {
        try await request("PUT", "/contacts", body: ["phone": phone, "name": name])
    }

    public func listGroups() async throws -> JSONValue {
        try await request("GET", "/groups")
    }

    public func getGroupMetadata(_ groupJID: String) async throws -> JSONValue {
        try await request("GET", "/groups/\(escape(groupJID))/metadata")
    }

    // MARK: - Sessions (need a personal access token, not a device key)

    public func listSessions() async throws -> JSONValue {
        try await request("GET", "/whatsapp-sessions")
    }

    public func getSession(_ id: CustomStringConvertible) async throws -> JSONValue {
        try await request("GET", "/whatsapp-sessions/\(escape(id))")
    }

    @discardableResult
    public func createSession(_ params: [String: Any]) async throws -> JSONValue {
        try await request("POST", "/whatsapp-sessions", body: params)
    }

    /// method: "qr", or "code" together with `phone` for a pairing code.
    @discardableResult
    public func connectSession(_ id: CustomStringConvertible, method: String = "qr", phone: String? = nil) async throws -> JSONValue {
        var body: [String: Any] = ["method": method]
        if let phone = phone { body["phone"] = phone }
        return try await request("POST", "/whatsapp-sessions/\(escape(id))/connect", body: body)
    }

    public func getSessionQRCode(_ id: CustomStringConvertible) async throws -> JSONValue {
        try await request("GET", "/whatsapp-sessions/\(escape(id))/qrcode")
    }

    // MARK: - Webhooks

    /// Constant-time check of the `X-Webhook-Signature` header against your device's webhook secret.
    public static func verifyWebhook(signature: String?, secret: String) -> Bool {
        guard let signature = signature, !signature.isEmpty, !secret.isEmpty else { return false }
        let a = Array(signature.utf8), b = Array(secret.utf8)
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }

    // MARK: - Helpers

    private func escape(_ value: CustomStringConvertible) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let s = value.description
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func header(_ response: HTTPURLResponse, _ name: String) -> String? {
        for (key, value) in response.allHeaderFields {
            if let k = key as? String, k.caseInsensitiveCompare(name) == .orderedSame { return "\(value)" }
        }
        return nil
    }
}
