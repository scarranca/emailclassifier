import AppKit
import CoveCore
import Network
import SwiftUI
import WebKit
import XCTest

@testable import Cove

@MainActor
final class EmailRenderingTests: XCTestCase {
  private var window: NSWindow?

  private func render(_ html: String, images: Bool = false, inlineImages: [String: String] = [:])
    async throws -> WKWebView
  {
    _ = NSApplication.shared
    let host = NSHostingView(
      rootView: FormattedEmailView(
        html: html, loadImages: images, inlineImages: inlineImages, height: .constant(600),
        failed: .constant(false)))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 800),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    self.window = window
    host.layoutSubtreeIfNeeded()
    func find(_ view: NSView) -> WKWebView? {
      if let web = view as? WKWebView { return web }
      return view.subviews.lazy.compactMap { find($0) }.first
    }
    for _ in 0..<100 {
      if let web = find(host),
        let ready = try? await web.callAsyncJavaScript(
          "return document.querySelector('#cove-email')?.children.length > 0",
          arguments: [:], in: nil, contentWorld: .defaultClient), ready as? Bool == true
      {
        return web
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    throw NSError(
      domain: "EmailRenderingTests", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Formatted email did not render"])
  }

  private func inspect(_ web: WKWebView, _ script: String) async throws -> [String: Any] {
    let result = try await web.callAsyncJavaScript(
      script, arguments: [:], in: nil, contentWorld: .defaultClient)
    return try XCTUnwrap(result as? [String: Any])
  }

  private func renderWithBinding(_ html: String, state: RenderingState) async throws -> WKWebView {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: BoundEmailFixture(html: html, state: state))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 800),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    self.window = window
    host.layoutSubtreeIfNeeded()
    func find(_ view: NSView) -> WKWebView? {
      if let web = view as? WKWebView { return web }
      return view.subviews.lazy.compactMap { find($0) }.first
    }
    for _ in 0..<100 {
      if let web = find(host),
        let ready = try? await web.callAsyncJavaScript(
          "return document.querySelector('#cove-email')?.children.length > 0",
          arguments: [:], in: nil, contentWorld: .defaultClient), ready as? Bool == true
      {
        return web
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    throw NSError(
      domain: "EmailRenderingTests", code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Bound email fixture did not render"])
  }

  func testGlobalReadingPreferencesRemoveWebContentAndControlAutomaticImages() async throws {
    _ = NSApplication.shared
    let suite = "Cove.EmailReadingTests." + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {
      window?.close()
      window = nil
      defaults.removePersistentDomain(forName: suite)
      try? FileManager.default.removeItem(at: directory)
    }
    let database = try Database(url: directory.appendingPathComponent("reader.sqlite"))
    let store = try AppStore(
      database: database, accountEmail: "reading@example.com", gmail: GmailClient(),
      gmailTokenProvider: { throw URLError(.notConnectedToInternet) }, syncClock: Date.init)
    // Embedded-only fixture. No remote resource or real account credential is used.
    let mail = Mail(
      sender: "Reader fixture", senderEmail: "fixture@example.com",
      subject: "Reading preferences", body: "Only this readable text should remain.",
      htmlBody:
        "<p>Formatted fixture</p><img src='data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'>"
    )
    defaults.set(true, forKey: "reading.textOnly")
    defaults.set(true, forKey: "reading.externalImages")
    let host = NSHostingView(
      rootView: EmailBodyView(store: store, mail: mail).defaultAppStorage(defaults))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 800),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    self.window = window
    func findWebView(_ view: NSView) -> WKWebView? {
      if let web = view as? WKWebView { return web }
      return view.subviews.lazy.compactMap { findWebView($0) }.first
    }
    for _ in 0..<5 {
      host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(30))
    }
    XCTAssertNil(
      findWebView(host), "Text-only must not mount web content, even with automatic images enabled")

    defaults.set(false, forKey: "reading.textOnly")
    var formatted: WKWebView?
    for _ in 0..<100 {
      host.layoutSubtreeIfNeeded()
      if let web = findWebView(host),
        let ready = try? await web.callAsyncJavaScript(
          "return document.querySelector('#cove-email')?.children.length > 0",
          arguments: [:], in: nil, contentWorld: .defaultClient), ready as? Bool == true
      {
        formatted = web
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    let web = try XCTUnwrap(formatted, "Turning off text-only must restore formatted mail")
    let optedIn = try await inspect(
      web, "return {policy: document.querySelector('meta[http-equiv]').content}")
    XCTAssertTrue((optedIn["policy"] as? String)?.contains("img-src data: https:;") == true)
    XCTAssertFalse(web.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    XCTAssertFalse(web.configuration.websiteDataStore.isPersistent)

    defaults.set(false, forKey: "reading.externalImages")
    var blocksRemoteImages = false
    for _ in 0..<100 {
      host.layoutSubtreeIfNeeded()
      if let result = try? await inspect(
        web, "return {policy: document.querySelector('meta[http-equiv]').content}"),
        (result["policy"] as? String)?.contains("img-src data:;") == true
      {
        blocksRemoteImages = true
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTAssertTrue(
      blocksRemoteImages,
      "Disabling automatic images must restore the restrictive policy in the open message")

    defaults.set(true, forKey: "reading.textOnly")
    for _ in 0..<100 {
      host.layoutSubtreeIfNeeded()
      if findWebView(host) == nil { break }
      try await Task.sleep(for: .milliseconds(30))
    }
    XCTAssertNil(
      findWebView(host), "Changing the global reading preference must remove the existing web view")
  }

  func testHTTPResourcesStayBlockedBeforeAndAfterImageOptIn() async throws {
    let server = try LocalImageProbe()
    defer {
      server.stop()
      window?.close()
      window = nil
    }
    let port = try await server.readyPort()
    // Verify the listener independently before trusting a zero-request result from WebKit.
    var controlRequest = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/control")!)
    controlRequest.timeoutInterval = 2
    let (controlData, _) = try await URLSession.shared.data(for: controlRequest)
    XCTAssertFalse(controlData.isEmpty)
    XCTAssertTrue(
      server.requestPaths.contains("/control"),
      "The loopback request counter must be independently verified")
    let controlPaths = server.requestPaths
    let state = RenderingState()
    let web = try await renderWithBinding(
      """
      <p>Remote resource privacy fixture</p>
      <img id="remote-image" src="http://127.0.0.1:\(port)/pixel.gif">
      <iframe src="http://127.0.0.1:\(port)/frame"></iframe>
      """, state: state)

    // The listener observes actual requests during parsing and insertion, not just CSP markup.
    try await Task.sleep(for: .milliseconds(600))
    XCTAssertEqual(
      server.requestPaths, controlPaths,
      "Neither inert parsing nor insertion may request remote resources before opt-in")
    XCTAssertFalse(state.failed)

    state.images = true
    for _ in 0..<100 {
      window?.contentView?.layoutSubtreeIfNeeded()
      let result = try await inspect(
        web,
        "return {policy: document.querySelector('meta[http-equiv]').content}")
      if (result["policy"] as? String)?.contains("img-src data: https:;") == true { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    try await Task.sleep(for: .milliseconds(600))
    let diagnostics = try await inspect(
      web,
      """
      return {policy: document.querySelector('meta[http-equiv]').content,
        image: document.getElementById('remote-image')?.outerHTML || '',
        complete: document.getElementById('remote-image')?.complete || false};
      """)
    XCTAssertEqual(
      server.requestPaths, controlPaths,
      "Opt-in must not permit unencrypted images or frames")
    XCTAssertFalse(state.failed)
    XCTAssertTrue(
      (diagnostics["policy"] as? String)?.contains("img-src data: https:;") == true,
      "Opt-in policy did not update: \(diagnostics)")
  }

  func testCIDImageRendersLocallyWithoutExternalOptIn() async throws {
    let dataURI = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
    let web = try await render(
      "<p>Inline logo</p><img id=\"logo\" src=\"cid:logo%40cove\">",
      inlineImages: ["logo@cove": dataURI])
    defer {
      window?.close()
      window = nil
    }
    let result = try await inspect(
      web,
      """
      const image = document.getElementById('logo');
      return {src: image.src, width: image.naturalWidth,
        policy: document.querySelector('meta[http-equiv]').content};
      """)
    XCTAssertEqual(result["src"] as? String, dataURI)
    XCTAssertEqual(result["width"] as? Int, 1)
    XCTAssertTrue((result["policy"] as? String)?.contains("img-src data:;") == true)
  }

  func testViewportHeightStabilizesThroughSwiftUIBinding() async throws {
    let state = RenderingState()
    let web = try await renderWithBinding(
      "<div style=\"height:100vh; background:#eee\">Viewport-sized email</div>", state: state)
    defer {
      window?.close()
      window = nil
    }
    for _ in 0..<10 {
      window?.contentView?.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(30))
    }
    let settledHeight = state.height
    let settledUpdates = state.heightReports.count
    for _ in 0..<20 {
      window?.contentView?.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(30))
    }
    let measured = try await inspect(
      web,
      """
      return {viewport: window.innerHeight, content: document.getElementById('cove-email').getBoundingClientRect().height};
      """)
    XCTAssertFalse(state.failed)
    XCTAssertGreaterThan(
      state.heightReports.count, 0, "The test must exercise the actual height message and binding")
    XCTAssertEqual(state.height, settledHeight, accuracy: 1)
    XCTAssertLessThanOrEqual(
      state.heightReports.count - settledUpdates, 1,
      "Viewport units must not cause continuous resize feedback")
    XCTAssertLessThan(
      state.height, 1000, "A short viewport-sized email must not expand to the height cap")
    XCTAssertEqual(measured["viewport"] as? Double ?? -1, state.height, accuracy: 1)
    XCTAssertEqual(measured["content"] as? Double ?? -1, state.height, accuracy: 1)
  }

  func testWheelOverFormattedMessageScrollsTheOuterReader() async throws {
    let state = RenderingState()
    let html = (0..<100).map { "<p>Long message paragraph \($0)</p>" }.joined()
    let web = try await renderWithBinding(html, state: state)
    defer { window?.close(); window = nil }
    for _ in 0..<20 {
      window?.contentView?.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(20))
    }
    let scrollView = try XCTUnwrap(web.enclosingScrollView)
    XCTAssertGreaterThan(state.height, scrollView.contentView.bounds.height)
    let before = scrollView.contentView.bounds.origin.y
    let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
      wheelCount: 1, wheel1: -180, wheel2: 0, wheel3: 0))
    let wheel = try XCTUnwrap(NSEvent(cgEvent: event))
    // Hit-test inside the actual rendered web content; a header-only wheel test would
    // miss WebKit swallowing events above the nested reader scroll view.
    let point = web.convert(NSPoint(x: 80, y: 80), to: web.superview)
    let target = try XCTUnwrap(web.hitTest(point))
    target.scrollWheel(with: wheel)
    for _ in 0..<20 {
      try await Task.sleep(for: .milliseconds(20))
      if scrollView.contentView.bounds.origin.y > before { break }
    }
    XCTAssertGreaterThan(scrollView.contentView.bounds.origin.y, before,
      "A wheel gesture over \(type(of: target)) must move the surrounding reader")
  }

  func testVeryLongEmailKeepsItsCappedOverflowScrollable() async throws {
    let state = RenderingState()
    let web = try await renderWithBinding(
      "<div style='height:30000px'>Start of a very long newsletter</div><p>Final paragraph</p>",
      state: state)
    defer { window?.close(); window = nil }
    for _ in 0..<50 {
      window?.contentView?.layoutSubtreeIfNeeded()
      if let view = web as? EmailWebView, view.innerScrollRange > 9000 { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    let view = try XCTUnwrap(web as? EmailWebView)
    XCTAssertEqual(state.height, 20_000)
    XCTAssertGreaterThan(view.innerScrollRange, 9000)
    let outer = try XCTUnwrap(web.enclosingScrollView)
    let event = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
      wheelCount: 1, wheel1: -180, wheel2: 0, wheel3: 0))
    let wheel = try XCTUnwrap(NSEvent(cgEvent: event))
    let point = web.convert(NSPoint(x: 80, y: 80), to: web.superview)
    let target = try XCTUnwrap(web.hitTest(point))
    target.scrollWheel(with: wheel)
    for _ in 0..<50 {
      if view.innerScrollOffset > 0 { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertGreaterThan(view.innerScrollOffset, 0,
      "A capped message must retain access to all of its formatted content")
    _ = try await inspect(web, "window.scrollTo(0, document.documentElement.scrollHeight); return {}")
    for _ in 0..<50 {
      if view.innerScrollOffset >= view.innerScrollRange - 1 { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    let before = outer.contentView.bounds.origin.y
    target.scrollWheel(with: wheel)
    for _ in 0..<50 {
      if outer.contentView.bounds.origin.y > before { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertGreaterThan(outer.contentView.bounds.origin.y, before,
      "At the end of a long message, scrolling must continue to the native reply controls")
  }

  func testPreservesLayoutAndReadableText() async throws {
    let web = try await render(
      """
      <html><head><style>.highlight { color: rgb(170, 0, 0); }</style></head><body>
      <h2>Project update</h2><p>Hello <strong>María</strong>.</p>
      <p class="highlight">The next steps:</p><ul><li>Review the proposal</li><li>Meet Tuesday</li></ul>
      <table><tr><th>Item</th><th>Price</th></tr><tr><td>Design</td><td>$50</td></tr></table>
      <blockquote>Earlier conversation</blockquote><a href="https://example.com/review">Review details</a>
      </body></html>
      """)
    defer {
      window?.close()
      window = nil
    }
    let result = try await inspect(
      web,
      """
      return {bold: getComputedStyle(document.querySelector('strong')).fontWeight,
        color: getComputedStyle(document.querySelector('.highlight')).color,
        rows: document.querySelectorAll('tr').length, items: document.querySelectorAll('li').length,
        text: document.body.innerText, link: document.querySelector('a').href,
        height: document.getElementById('cove-email').getBoundingClientRect().height};
      """)
    XCTAssertEqual(result["bold"] as? String, "700")
    XCTAssertEqual(result["color"] as? String, "rgb(170, 0, 0)")
    XCTAssertEqual(result["rows"] as? Int, 2)
    XCTAssertEqual(result["items"] as? Int, 2)
    XCTAssertTrue((result["text"] as? String)?.contains("María") == true)
    XCTAssertEqual(result["link"] as? String, "https://example.com/review")
    XCTAssertGreaterThan(result["height"] as? Double ?? 0, 150)
  }

  func testRemovesActiveContentAndKeepsRemoteImagesBlockedByDefault() async throws {
    let web = try await render(
      """
      <script>document.body.dataset.executed='yes'</script>
      <meta http-equiv="refresh" content="0;url=https://example.com/redirect">
      <iframe src="https://example.com/frame"></iframe>
      <form action="https://example.com/form"><input value="send"></form>
      <p onclick="document.body.dataset.executed='yes'">Readable message</p>
      <a href="javascript:alert(1)" ping="https://example.com/ping">Bad link</a>
      <a href="file:///etc/passwd">Local file</a>
      <img src="https://example.com/pixel.png" onerror="document.body.dataset.executed='yes'">
      """)
    defer {
      window?.close()
      window = nil
    }
    let result = try await inspect(
      web,
      """
      return {active: document.querySelectorAll('#cove-email script, iframe, form, input, #cove-email meta').length,
        handler: document.querySelector('p').hasAttribute('onclick'),
        unsafeLinks: [...document.querySelectorAll('a')].filter(a => a.hasAttribute('href')).length,
        executed: document.body.dataset.executed || '',
        policy: document.querySelector('meta[http-equiv]').content,
        text: document.body.innerText};
      """)
    XCTAssertEqual(result["active"] as? Int, 0)
    XCTAssertEqual(result["handler"] as? Bool, false)
    XCTAssertEqual(result["unsafeLinks"] as? Int, 0)
    XCTAssertEqual(result["executed"] as? String, "")
    XCTAssertTrue((result["policy"] as? String)?.contains("img-src data:;") == true)
    XCTAssertTrue((result["text"] as? String)?.contains("Readable message") == true)
    XCTAssertFalse(web.configuration.defaultWebpagePreferences.allowsContentJavaScript)
    XCTAssertFalse(web.configuration.websiteDataStore.isPersistent)
  }

  func testImageOptInRetainsScriptAndFrameRestrictions() async throws {
    let web = try await render("<p>Newsletter</p>", images: true)
    defer {
      window?.close()
      window = nil
    }
    let result = try await inspect(
      web,
      "return {policy: document.querySelector('meta[http-equiv]').content, referrer: document.querySelector('meta[name=referrer]').content}"
    )
    XCTAssertEqual(result["referrer"] as? String, "no-referrer")
    let policy = result["policy"] as? String ?? ""
    XCTAssertTrue(policy.contains("img-src data: https:;"))
    XCTAssertTrue(policy.contains("script-src 'none'"))
    XCTAssertTrue(policy.contains("frame-src 'none'"))
  }
}

@MainActor
private final class RenderingState: ObservableObject {
  @Published var height: CGFloat = 80 {
    didSet { heightReports.append(height) }
  }
  @Published var failed = false
  @Published var images = false
  var heightReports: [CGFloat] = []
}

private struct BoundEmailFixture: View {
  let html: String
  @ObservedObject var state: RenderingState
  var body: some View {
    ScrollView {
      FormattedEmailView(
        html: html, loadImages: state.images, height: $state.height, failed: $state.failed
      )
      .frame(height: state.height)
    }
  }
}

/// Loopback-only synthetic server. No requests leave the test machine.
private final class LocalImageProbe: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "Cove.EmailRenderingTests.ImageProbe")
  private let lock = NSLock()
  private var paths: [String] = []
  var requestPaths: [String] {
    lock.lock()
    defer { lock.unlock() }
    return paths
  }

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else {
        connection.cancel()
        return
      }
      connection.start(queue: self.queue)
      self.receive(connection, accumulated: Data())
    }
    listener.start(queue: queue)
  }

  func readyPort() async throws -> UInt16 {
    for _ in 0..<100 {
      if let port = listener.port, port.rawValue != 0 { return port.rawValue }
      try await Task.sleep(for: .milliseconds(20))
    }
    throw NSError(
      domain: "LocalImageProbe", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Loopback image server did not start"])
  }

  func stop() { listener.cancel() }

  private func receive(_ connection: NWConnection, accumulated: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
      [weak self] bytes, _, finished, error in
      guard let self else {
        connection.cancel()
        return
      }
      var request = accumulated
      if let bytes { request.append(bytes) }
      if let text = String(data: request, encoding: .utf8), text.contains("\r\n\r\n") {
        let path =
          text.components(separatedBy: "\r\n").first?.split(separator: " ").dropFirst().first.map(
            String.init) ?? "invalid"
        self.lock.lock()
        self.paths.append(path)
        self.lock.unlock()
        let gif = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")!
        var response = Data(
          "HTTP/1.1 200 OK\r\nContent-Type: image/gif\r\nContent-Length: \(gif.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            .utf8)
        response.append(gif)
        connection.send(
          content: response, completion: .contentProcessed { _ in connection.cancel() })
      } else if finished || error != nil || request.count > 32_768 {
        connection.cancel()
      } else {
        self.receive(connection, accumulated: request)
      }
    }
  }
}
