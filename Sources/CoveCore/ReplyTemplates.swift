import Foundation

/// Deliberately deterministic starting text, never presented as AI-generated prose.
public enum ReplyTemplates {
  public static func reply(
    to name: String, voice: String, signoff: String, askForDetail: Bool = false
  ) -> String {
    let first = name.split(separator: " ").first.map(String.init) ?? "there"
    let greeting: String
    let body: String
    switch voice {
    case "Professional":
      greeting = "Hello \(first),"
      body =
        askForDetail
        ? "Thank you for your message. Could you please share additional details?"
        : "Thank you for your message. I’m confirming that I have received it."
    case "Direct":
      greeting = "Hi \(first),"
      body = askForDetail ? "Could you share more details?" : "Received, thank you."
    default:
      greeting = "Hi \(first),"
      body =
        askForDetail
        ? "Thanks for reaching out. Could you share a little more detail?"
        : "Thanks for sending this over. I’ve received your message."
    }
    return "\(greeting)\n\n\(body)\n\n\(signoff)"
  }
}
