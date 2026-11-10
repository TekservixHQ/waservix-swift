import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import WAservix

final class Recorder {
    var last: URLRequest?
    var status = 200
    var reply = #"{"success":true,"data":{"msgId":58213,"jid":"15551234567@s.whatsapp.net","status":"in_progress"}}"#

    var lastBody: [String: Any]? {
        guard let data = last?.httpBody else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

final class WAservixTests: XCTestCase {
    func makeClient(_ r: Recorder) -> WAservixClient {
        WAservixClient(apiKey: "wpk_test", baseURL: "https://example.test/api", transport: { req in
            r.last = req
            let res = HTTPURLResponse(url: req.url!, statusCode: r.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            return (Data(r.reply.utf8), res)
        })
    }

    func testSendText() async throws {
        let r = Recorder()
        let res = try await makeClient(r).sendText(to: "+1555", text: "hi")
        XCTAssertEqual(res["msgId"]?.intValue, 58213)
        XCTAssertEqual(res["status"]?.stringValue, "in_progress")
        XCTAssertEqual(r.last?.httpMethod, "POST")
        XCTAssertEqual(r.last?.url?.absoluteString, "https://example.test/api/send-message")
        XCTAssertEqual(r.last?.value(forHTTPHeaderField: "Authorization"), "Bearer wpk_test")
        XCTAssertEqual(r.lastBody?["to"] as? String, "+1555")
        XCTAssertEqual(r.lastBody?["text"] as? String, "hi")
    }

    func testMediaAndPaths() async throws {
        let r = Recorder()
        let c = makeClient(r)
        _ = try await c.sendImage(to: "+1", imageURL: "https://x/y.jpg")
        XCTAssertEqual(r.lastBody?["imageUrl"] as? String, "https://x/y.jpg")
        XCTAssertNil(r.lastBody?["text"])
        _ = try await c.sendDocument(to: "+1", documentURL: "https://x/a.pdf", fileName: "a.pdf", caption: "c")
        XCTAssertEqual(r.lastBody?["fileName"] as? String, "a.pdf")
        XCTAssertEqual(r.lastBody?["text"] as? String, "c")
        _ = try await c.sendLocation(to: "+1", latitude: -1.9441, longitude: 30.0619, name: "Shop")
        XCTAssertEqual((r.lastBody?["location"] as? [String: Any])?["name"] as? String, "Shop")
        _ = try await c.getMessageInfo(5)
        XCTAssertEqual(r.last?.url?.path, "/api/messages/5/info")
        _ = try await c.editMessage(5, text: "t")
        XCTAssertEqual(r.last?.httpMethod, "PUT")
        XCTAssertEqual(r.lastBody?["text"] as? String, "t")
        _ = try await c.onWhatsApp("+1555")
        XCTAssertEqual(r.last?.url?.absoluteString, "https://example.test/api/on-whatsapp/%2B1555")
        _ = try await c.getGroupMetadata("1203@g.us")
        XCTAssertEqual(r.last?.url?.absoluteString, "https://example.test/api/groups/1203%40g.us/metadata")
        _ = try await c.connectSession(3)
        XCTAssertEqual(r.lastBody?["method"] as? String, "qr")
        XCTAssertNil(r.lastBody?["phone"])
        _ = try await c.connectSession(3, method: "code", phone: "+1555")
        XCTAssertEqual(r.lastBody?["phone"] as? String, "+1555")
    }

    func testErrors() async {
        let r = Recorder()
        r.status = 503
        r.reply = #"{"success":false,"message":"Device reconnecting"}"#
        do {
            _ = try await makeClient(r).getStatus()
            XCTFail("expected error")
        } catch let e as WAservixError {
            XCTAssertEqual(e.status, 503)
            XCTAssertEqual(e.message, "Device reconnecting")
        } catch {
            XCTFail("wrong error \(error)")
        }

        r.status = 200
        r.reply = #"{"success":false,"message":"Invalid number"}"#
        do {
            _ = try await makeClient(r).sendText(to: "+1", text: "x")
            XCTFail("expected error")
        } catch let e as WAservixError {
            XCTAssertEqual(e.message, "Invalid number")
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testVerifyWebhook() {
        XCTAssertTrue(WAservixClient.verifyWebhook(signature: "abc", secret: "abc"))
        XCTAssertFalse(WAservixClient.verifyWebhook(signature: "abd", secret: "abc"))
        XCTAssertFalse(WAservixClient.verifyWebhook(signature: "abcd", secret: "abc"))
        XCTAssertFalse(WAservixClient.verifyWebhook(signature: nil, secret: "abc"))
    }

    func testJSONValue() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a":[1,"x",true,null],"b":{"c":2.5}}"#.utf8))
        XCTAssertEqual(v["a"]?[0]?.intValue, 1)
        XCTAssertEqual(v["a"]?[1]?.stringValue, "x")
        XCTAssertEqual(v["a"]?[2]?.boolValue, true)
        XCTAssertEqual(v["a"]?[3]?.isNull, true)
        XCTAssertEqual(v["b"]?["c"]?.doubleValue, 2.5)
        XCTAssertNil(v["missing"])
        struct B: Decodable { let c: Double }
        XCTAssertEqual(try v["b"]?.decode(B.self).c, 2.5)
    }
}
