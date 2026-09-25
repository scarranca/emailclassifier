import Foundation

/// Self-contained browser responses. No credentials, remote assets, analytics, or scripts.
public enum OAuthCallbackPage: CaseIterable {
  case connected, denied, failed, invalid

  public var html: String {
    let title: String
    let detail: String
    let status: String
    switch self {
    case .connected:
      title = "Thank you. You’re in."
      detail = "Gmail is connected. Your inbox is ready for a little more calm."
      status = "Connected to Cove"
    case .denied:
      title = "No changes made."
      detail = "Google sign-in wasn’t approved. Return to Cove whenever you’re ready to try again."
      status = "Sign-in cancelled"
    case .failed:
      title = "Let’s try that again."
      detail = "Cove couldn’t finish connecting Gmail. Return to the app for details and try signing in again."
      status = "Connection incomplete"
    case .invalid:
      title = "This link isn’t active."
      detail = "Return to Cove and start sign-in there. If you already have a sign-in tab open, continue in that tab."
      status = "Sign-in link not recognized"
    }
    let success = self == .connected
    let symbol = success
      ? "<path class='check' d='m8 16 5 5 11-11'/>"
      : "<path d='M16 9v9m0 5v.1'/>"
    return """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light">
    <meta name="referrer" content="no-referrer">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
    <title>\(status) · Cove</title>
    <style>
    :root { color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #303030; background: #fafafa; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; min-height: 100svh; display: flex; flex-direction: column; }
    header { display: flex; align-items: center; gap: 10px; padding: 30px 40px; font-size: 22px; font-weight: 600; letter-spacing: -.025em; }
    .brand { width: 29px; height: 29px; fill: currentColor; }
    main { flex: 1; display: grid; place-content: center; padding: 12px 24px 80px; text-align: center; }
    .content { width: min(100%, 560px); margin: 0 auto; }
    .scene { position: relative; width: min(100%, 480px); height: 184px; margin: 0 auto 22px; }
    .tide { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; color: #a1a1a1; }
    .dot { transform-box: fill-box; transform-origin: center; }
    .success .dot { animation: settle 1600ms cubic-bezier(.16,1,.3,1) both; animation-delay: var(--delay); }
    .seal { position: absolute; left: calc(50% - 35px); top: 57px; display: grid; place-items: center; width: 70px; height: 70px; border-radius: 50%; background: #303030; color: white; outline: 12px solid #fafafa; }
    .seal svg { width: 32px; height: 32px; fill: none; stroke: currentColor; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
    .success .seal { animation: arrive 900ms cubic-bezier(.16,1,.3,1); }
    .check { stroke-dasharray: 28; animation: confirm 800ms ease-out both; }
    .status { font-size: 14px; color: #4b4b4b; margin: 0 0 18px; }
    h1 { font-size: 42px; line-height: 1.13; letter-spacing: -.035em; font-weight: 550; text-wrap: balance; margin: 0 0 20px; }
    .detail { font-size: 18px; line-height: 1.55; max-width: 42ch; margin: 0 auto; color: #4b4b4b; text-wrap: pretty; }
    .return { margin: 40px 0 0; font-size: 15px; font-weight: 550; }
    .hint { margin: 8px 0 0; font-size: 13px; line-height: 1.6; color: #626262; }
    .shortcut { white-space: nowrap; }
    footer { padding: 20px 24px 28px; text-align: center; font-size: 12px; color: #626262; }
    @keyframes settle { from { opacity: .15; transform: translateY(var(--drift)) scale(.35); } to { opacity: 1; transform: translateY(0) scale(1); } }
    @keyframes arrive { from { transform: scale(.88); } to { transform: scale(1); } }
    @keyframes confirm { from { stroke-dashoffset: 28; } to { stroke-dashoffset: 0; } }
    @media (max-width: 520px) { header { padding: 24px; } main { padding-bottom: 40px; } h1 { font-size: 34px; } .detail { font-size: 16px; } .scene { height: 160px; } .seal { top: 45px; } }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
    </style></head>
    <body class="\(success ? "success" : "notice")">
    <header><svg class="brand" aria-hidden="true" viewBox="0 0 14 14"><path d="M5.31836 2.35156q-0.58789 0.02734-1.07666 0.32129-0.16748 0.09912-0.51611 0.36572-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.50927 0.0752-0.32129 0-0.50586-0.06153-0.18115-0.06494-0.43067-0.25976-0.23926-0.16748-0.31103-0.20166-0.06836-0.0376-0.22217-0.0376-0.15381 0-0.23926 0.04102-0.18115 0.09912-0.28027 0.28027-0.04102 0.08545-0.04785 0.12647-0.00684 0.04102-0.00684 0.12646 0 0.16748 0.06152 0.28027 0.06494 0.11279 0.2461 0.25293 0.43408 0.34863 0.81689 0.48877 0.38623 0.14014 0.90576 0.14014 0.2666 0 0.44776-0.02734 0.18115-0.02734 0.41015-0.10254 0.23242-0.07861 0.42041-0.19141 0.19141-0.11279 0.57081-0.39307 0.23584-0.19482 0.34863-0.25634 0.11279-0.06494 0.23926-0.10596 0.18115-0.07178 0.43066-0.07861 0.25293-0.00684 0.46484 0.04785 0.16748 0.04443 0.29395 0.12304 0.12646 0.0752 0.42041 0.29737 0.40332 0.32129 0.68359 0.46142 0.43408 0.19824 0.96729 0.22559 0.5332 0.02734 1.0083-0.12647 0.22217-0.08203 0.43066-0.21533 0.21191-0.1333 0.60498-0.42724 0.32129-0.23926 0.50928-0.30762 0.19141-0.07178 0.50586-0.07178 0.31445 0 0.4956 0.06494 0.18457 0.06152 0.44776 0.25635 0.22559 0.16748 0.29394 0.20508 0.07178 0.03418 0.21192 0.03418 0.11279 0 0.16064-0.01367 0.04785-0.01367 0.10596-0.04102 0.18115-0.08545 0.28027-0.29394 0.04101-0.09912 0.04102-0.22559 0-0.19482-0.11279-0.3418-0.11279-0.14697-0.44776-0.37256-0.30762-0.2085-0.60156-0.31445-0.29395-0.10596-0.65967-0.11963-0.71094-0.04102-1.27148 0.19483-0.23926 0.09912-0.75537 0.49218-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.52295 0.0752-0.28027 0-0.40673-0.02735-0.18115-0.05811-0.30762-0.14013-0.12646-0.08545-0.51611-0.39307-0.29395-0.22217-0.53321-0.3418-0.23926-0.11963-0.5332-0.1914-0.18115-0.02734-0.54688-0.05469-0.0957 0-0.29394 0.01367z m0 3.5q-0.58789 0.02734-1.07666 0.32129-0.16748 0.09912-0.51611 0.36572-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.50927 0.0752-0.32129 0-0.50586-0.06153-0.18115-0.06494-0.43067-0.25976-0.23926-0.16748-0.31103-0.20166-0.06836-0.0376-0.22217-0.0376-0.15381 0-0.23926 0.04102-0.18115 0.09912-0.28027 0.28027-0.04102 0.08545-0.04785 0.12647-0.00684 0.04102-0.00684 0.12646 0 0.16748 0.06152 0.28027 0.06494 0.11279 0.2461 0.25293 0.43408 0.34863 0.81689 0.48877 0.38623 0.14014 0.90576 0.14014 0.2666 0 0.44776-0.02734 0.18115-0.02734 0.41015-0.10254 0.23242-0.07861 0.42041-0.19141 0.19141-0.11279 0.57081-0.39307 0.23584-0.19482 0.34863-0.25634 0.11279-0.06494 0.23926-0.10596 0.18115-0.07178 0.43066-0.07861 0.25293-0.00684 0.46484 0.04785 0.16748 0.04443 0.29395 0.12304 0.12646 0.0752 0.42041 0.29737 0.40332 0.32129 0.68359 0.46142 0.43408 0.19824 0.96729 0.22559 0.5332 0.02734 1.0083-0.12647 0.22217-0.08203 0.43066-0.21533 0.21191-0.1333 0.60498-0.42724 0.32129-0.23926 0.50928-0.30762 0.19141-0.07178 0.50586-0.07178 0.31445 0 0.4956 0.06494 0.18457 0.06152 0.44776 0.25635 0.22559 0.16748 0.29394 0.20508 0.07178 0.03418 0.21192 0.03418 0.11279 0 0.16064-0.01367 0.04785-0.01367 0.10596-0.04102 0.18115-0.08545 0.28027-0.29394 0.04101-0.09912 0.04102-0.22559 0-0.19482-0.11279-0.3418-0.11279-0.14697-0.44776-0.37256-0.30762-0.2085-0.60156-0.31445-0.29395-0.10596-0.65967-0.11963-0.71094-0.04102-1.27148 0.19483-0.23926 0.09912-0.75537 0.49218-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.52295 0.0752-0.28027 0-0.40673-0.02735-0.18115-0.05811-0.30762-0.14013-0.12646-0.08545-0.51611-0.39307-0.29395-0.22217-0.53321-0.3418-0.23926-0.11963-0.5332-0.1914-0.18115-0.02734-0.54688-0.05469-0.0957 0-0.29394 0.01367z m0 3.5q-0.58789 0.02734-1.07666 0.32129-0.16748 0.09912-0.51611 0.36572-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.50927 0.0752-0.32129 0-0.50586-0.06153-0.18115-0.06494-0.43067-0.25976-0.23926-0.16748-0.31103-0.20166-0.06836-0.0376-0.22217-0.0376-0.15381 0-0.23926 0.04102-0.18115 0.09912-0.28027 0.28027-0.04102 0.08545-0.04785 0.12647-0.00684 0.04102-0.00684 0.12646 0 0.16748 0.06152 0.28027 0.06494 0.11279 0.2461 0.25293 0.43408 0.34863 0.81689 0.48877 0.38623 0.14014 0.90576 0.14014 0.2666 0 0.44776-0.02734 0.18115-0.02734 0.41015-0.10254 0.23242-0.07861 0.42041-0.19141 0.19141-0.11279 0.57081-0.39307 0.23584-0.19482 0.34863-0.25634 0.11279-0.06494 0.23926-0.10596 0.18115-0.07178 0.43066-0.07861 0.25293-0.00684 0.46484 0.04785 0.16748 0.04443 0.29395 0.12304 0.12646 0.0752 0.42041 0.29737 0.40332 0.32129 0.68359 0.46142 0.43408 0.19824 0.96729 0.22559 0.5332 0.02734 1.0083-0.12646 0.22217-0.08203 0.43066-0.21534 0.21191-0.1333 0.60498-0.42724 0.32129-0.23926 0.50928-0.30762 0.19141-0.07178 0.50586-0.07178 0.31445 0 0.4956 0.06494 0.18457 0.06152 0.44776 0.25635 0.22559 0.16748 0.29394 0.20508 0.07178 0.03418 0.21192 0.03418 0.11279 0 0.16064-0.01367 0.04785-0.01367 0.10596-0.04102 0.18115-0.08545 0.28027-0.29394 0.04101-0.09912 0.04102-0.22559 0-0.19482-0.11279-0.3418-0.11279-0.14697-0.44776-0.37256-0.30762-0.2085-0.60156-0.31445-0.29395-0.10596-0.65967-0.11963-0.71094-0.04102-1.27148 0.19483-0.23926 0.09912-0.75537 0.49218-0.39307 0.29395-0.58448 0.37256-0.18799 0.0752-0.52295 0.0752-0.28027 0-0.40673-0.02735-0.18115-0.0581-0.30762-0.14013-0.12646-0.08545-0.51611-0.39307-0.29395-0.22217-0.53321-0.3418-0.23926-0.11963-0.5332-0.1914-0.18115-0.02734-0.54688-0.05469-0.0957 0-0.29394 0.01367z"/></svg><span>Cove</span></header>
    <main><div class="content">
      <div class="scene" aria-hidden="true"><svg class="tide" viewBox="0 0 480 184">\(Self.dots)</svg><div class="seal"><svg viewBox="0 0 32 32">\(symbol)</svg></div></div>
      <p class="status">\(status)</p>
      <h1>\(title)</h1><p class="detail">\(detail)</p>
      <p class="return">Return to Cove to continue.</p>
      <p class="hint">Switch to Cove from your Dock or with <span class="shortcut">⌘ Tab</span>.<br>You can close this browser tab.</p>
    </div></main>
    <footer>A quieter place for your inbox.</footer>
    </body></html>
    """
  }

  public var httpResponse: Data {
    let body = html
    let status: String
    switch self {
    case .connected: status = "200 OK"
    case .denied: status = "200 OK"
    case .failed: status = "503 Service Unavailable"
    case .invalid: status = "400 Bad Request"
    }
    return Data(("HTTP/1.1 \(status)\r\n"
      + "Content-Type: text/html; charset=utf-8\r\n"
      + "Content-Length: \(body.utf8.count)\r\n"
      + "Cache-Control: no-store\r\nPragma: no-cache\r\n"
      + "Referrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\n"
      + "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'\r\n"
      + "Connection: close\r\n\r\n" + body).utf8)
  }

  private static let dots: String = {
    // A finite arrival wave: dots settle into three ribbons around the connection seal.
    (0..<3).flatMap { row in
      (0..<35).map { column in
        let x = 12 + column * 13
        let y = 65 + row * 24 + Int(sin(Double(column) * .pi / 12) * 17)
        let delay = abs(17 - column) * 22 + row * 65
        let drift = (column % 2 == 0 ? -1 : 1) * (10 + row * 4)
        return "<circle class='dot' cx='\(x)' cy='\(y)' r='2' fill='currentColor' style='--delay:\(delay)ms;--drift:\(drift)px'/>"
      }
    }.joined()
  }()
}
