# WAservix Swift client

[![tests](https://github.com/TekservixHQ/waservix-swift/actions/workflows/tests.yml/badge.svg)](https://github.com/TekservixHQ/waservix-swift/actions/workflows/tests.yml)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FTekservixHQ%2Fwaservix-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/TekservixHQ/waservix-swift)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FTekservixHQ%2Fwaservix-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/TekservixHQ/waservix-swift)

**WAservix WhatsApp API Gateway** - official Swift client: send WhatsApp messages from your own number. By Tekservix.

Swift client for the [WAservix WhatsApp API Gateway](https://tekservix.com/waservix/).

WAservix links your own WhatsApp number by QR code (the same way WhatsApp Web does) and gives you a REST API to send text, images, video, audio, documents, locations, polls and more, with webhooks for incoming messages and status updates.

- async/await, Swift 5.7+
- Linux (Vapor, Hummingbird), macOS, iOS, tvOS, watchOS
- No dependencies; webhook check built in

## Install

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/TekservixHQ/waservix-swift.git", from: "1.0.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "WAservix", package: "waservix-swift"),
    ]),
]
```

In Xcode: File -> Add Package Dependencies, then paste `https://github.com/TekservixHQ/waservix-swift`.

## Quick start

Copy your device's API key from the WAservix dashboard (Devices -> API key) and keep it on your server.

```swift
import WAservix

let wa = WAservixClient(apiKey: Environment.get("WASERVIX_KEY")!) // Vapor; or ProcessInfo.processInfo.environment

let res = try await wa.sendText(to: "+15551234567", text: "Hello Aline, your order is ready")
res["msgId"]?.intValue     // 58213
res["status"]?.stringValue // "in_progress"
```

**Don't put the API key inside an iOS or macOS app.** Anyone can pull it out of the app bundle. From an app, call your own backend, and let the backend call WAservix.

## Sending

Messages are queued and sent one at a time per number, so each call returns right away with `status: "in_progress"` and a `msgId`.

```swift
// Image with caption
try await wa.sendImage(to: "+15551234567", imageURL: "https://example.com/product.jpg", caption: "Back in stock")

// Document
try await wa.sendDocument(to: "+15551234567", documentURL: "https://example.com/inv-1042.pdf",
                          fileName: "Invoice-1042.pdf", caption: "Your invoice")

// Location
try await wa.sendLocation(to: "+15551234567", latitude: -1.9441, longitude: 30.0619, name: "Our shop")

// Anything the API supports, including groups (JID ending in @g.us)
try await wa.sendMessage(to: "120363040000000000@g.us", fields: ["text": "Team meeting at 3pm"])
```

## Status, contacts and groups

```swift
let info  = try await wa.getMessageInfo(58213)      // queued, sent, delivered, read, played or failed
let check = try await wa.onWhatsApp("+15551234567") // {"exists": true, "jid": "..."}
let conn  = try await wa.getStatus()                // {"status": "connected"}

try await wa.editMessage(58213, text: "Corrected text") // own text messages, about 15 minutes
let groups = try await wa.listGroups()
```

Results are `JSONValue`: read them with subscripts and `.stringValue`, `.intValue`, `.boolValue`, or decode into your own type with `.decode(MyType.self)`.

Anything else in the [API reference](https://tekservix.com/waservix/docs/) is one call away:

```swift
try await wa.request("POST", "/messages/read", body: ["msgId": "3EB0X123456789"])
```

## Webhooks

Set a webhook URL and events for the number in the dashboard. Each request carries `X-Webhook-Signature`, which equals the device's webhook secret. Vapor example:

```swift
app.post("wa-webhook") { req async throws -> HTTPStatus in
    guard WAservixClient.verifyWebhook(signature: req.headers.first(name: "X-Webhook-Signature"),
                                       secret: Environment.get("WASERVIX_WEBHOOK_SECRET")!) else {
        return .unauthorized
    }
    let payload = try req.content.decode(JSONValue.self)
    if payload["event"]?.stringValue == "messages.received" {
        let m = payload["data"]?["messages"]
        // m?["key"]?["cleanedSenderPn"], m?["messageBody"]
    }
    return .ok // acknowledge fast; do slow work in a background job
}
```

## Errors

Failed calls throw `WAservixError` with `status`, `message`, field `errors` and, on 429, `retryAfter` in seconds. A 503 means the device is reconnecting: retry shortly.

## Migrating from WaSender

WAservix accepts the same `/send-message` body and webhook fields as WaSender, so most integrations switch by changing the base URL and key. See the [compatibility notes](https://tekservix.com/waservix/docs/).

## Use it responsibly

WAservix is not Meta's official WhatsApp Business Platform. There's no business verification and no per-conversation fee, but WhatsApp's spam rules apply to your number directly. Message people who expect to hear from you, warm up new numbers slowly and keep the built-in account protection on.

## More from Tekservix

- [SMS Gora SMS Gateway](https://tekservix.com/smsgora/): send SMS through your own Android phones ([Swift client](https://github.com/TekservixHQ/smsgora-swift))
- [AI Sales Agent](https://tekservix.com/ai-sales-agent): answers customers on WhatsApp and SMS using your website's content
- [Website to App](https://tekservix.com/mobile-apps): turn your website into Android and iOS apps
- WAservix is also available for Node.js, Python, PHP, Go, Java/Kotlin, .NET and Ruby: see [github.com/TekservixHQ](https://github.com/TekservixHQ)

## License

MIT
