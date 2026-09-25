import CoveCore
import Foundation

/// A callback code is not a completed connection. Keep its browser response pending
/// until the account and mailbox commit, and never replace a terminal outcome.
@MainActor final class OAuthBrowserReply {
  private var send: ((Data) -> Void)?
  private var deadline: Task<Void, Never>?

  init(timeout: Duration = .seconds(75), send: @escaping (Data) -> Void) {
    self.send = send
    deadline = Task { [weak self] in
      do {
        try await Task.sleep(for: timeout)
        self?.finish(.failed)
      } catch {}
    }
  }

  func finish(_ page: OAuthCallbackPage) {
    guard let send else { return }
    self.send = nil
    deadline?.cancel()
    deadline = nil
    send(page.httpResponse)
  }
}
