import AppKit
import CoveCore
import WebKit
import XCTest

@MainActor final class OAuthCallbackRenderingTests: XCTestCase {
  func testBrowserPagesRemainReadableAtDesktopAndNarrowWidths() async throws {
    _ = NSApplication.shared
    for (page, width) in [(OAuthCallbackPage.connected, 1000.0), (.connected, 320.0), (.denied, 320.0)] {
      let frame = NSRect(x: 0, y: 0, width: width, height: 800)
      let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      defer { window.close() }
      let configuration = WKWebViewConfiguration()
      configuration.websiteDataStore = .nonPersistent()
      let web = WKWebView(frame: frame, configuration: configuration)
      window.contentView = web
      web.loadHTMLString(page.html, baseURL: nil)
      var ready = false
      for _ in 0..<100 {
        ready = (try? await web.callAsyncJavaScript("return !!document.querySelector('h1')", arguments: [:], in: nil, contentWorld: .defaultClient)) as? Bool == true
        if ready { break }
        try await Task.sleep(for: .milliseconds(30))
      }
      XCTAssertTrue(ready)
      let metrics = try await web.callAsyncJavaScript("""
        const h = document.querySelector('h1'), detail = document.querySelector('.detail');
        return { overflow: document.documentElement.scrollWidth > window.innerWidth,
          title: h.textContent, size: parseFloat(getComputedStyle(h).fontSize),
          contentVisible: getComputedStyle(detail).opacity === '1',
          requests: performance.getEntriesByType('resource').length,
          animations: document.getAnimations().length,
          reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches };
        """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
      XCTAssertEqual(metrics?["overflow"] as? Bool, false)
      XCTAssertEqual(metrics?["contentVisible"] as? Bool, true)
      XCTAssertEqual(metrics?["requests"] as? Int, 0)
      XCTAssertGreaterThanOrEqual(metrics?["size"] as? Double ?? 0, 34)
      XCTAssertEqual(metrics?["title"] as? String, page == .connected ? "Thank you. You’re in." : "No changes made.")
      if page == .connected && metrics?["reducedMotion"] as? Bool != true {
        XCTAssertGreaterThan(metrics?["animations"] as? Int ?? 0, 0)
      }
      // Settle animation on the private offscreen page without touching the user's desktop.
      _ = try await web.callAsyncJavaScript("document.getAnimations().forEach(a => a.finish()); return true", arguments: [:], in: nil, contentWorld: .defaultClient)
      let snapshot = try await web.takeSnapshot(configuration: nil)
      let tiff = try XCTUnwrap(snapshot.tiffRepresentation)
      let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
      let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
      let name = page == .connected ? "success" : "denied"
      try png.write(to: URL(fileURLWithPath: "/tmp/cove-oauth-\(name)-\(Int(width)).png"))
      try page.html.write(toFile: "/tmp/cove-oauth-\(name).html", atomically: true, encoding: .utf8)
      let reducedAnimation = try await web.callAsyncJavaScript("""
        // Exercise the shipped media-rule body without changing the Mac's preference.
        for (const sheet of document.styleSheets) for (const rule of sheet.cssRules) {
          if (rule.conditionText === '(prefers-reduced-motion: reduce)') rule.media.mediaText = 'all';
        }
        return getComputedStyle(document.querySelector('.dot')).animationName;
        """, arguments: [:], in: nil, contentWorld: .defaultClient)
      XCTAssertEqual(reducedAnimation as? String, "none")
    }
  }
}
