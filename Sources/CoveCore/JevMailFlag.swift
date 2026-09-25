import Foundation

/// Derived from stored Jev assessments; never changes the user's Gmail star.
public enum JevMailFlag: String, CaseIterable, Identifiable, Sendable {
  case needsAction, timeSensitive, reviewCategory
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .needsAction: "Needs action"
    case .timeSensitive: "Time-sensitive"
    case .reviewCategory: "Review category"
    }
  }
  public var icon: String {
    switch self {
    case .needsAction: "arrowshape.turn.up.left"
    case .timeSensitive: "clock"
    case .reviewCategory: "questionmark.circle"
    }
  }
  public func matches(_ decision: Decision?) -> Bool {
    guard let decision else { return false }
    switch self {
    case .needsAction: return decision.needsReply.isFinite && decision.needsReply >= 0.65
    case .timeSensitive: return decision.urgent.isFinite && decision.urgent >= 0.65
    case .reviewCategory: return decision.confidence.isFinite && decision.confidence < 0.55
    }
  }
  public func detail(_ decision: Decision) -> String {
    switch self {
    case .needsAction: return "Jev: \(Int(decision.needsReply * 100))% likelihood of needing a reply or action."
    case .timeSensitive: return "Jev: \(Int(decision.urgent * 100))% likelihood of needing action within 24 hours."
    case .reviewCategory: return "Jev is uncertain about this email’s category."
    }
  }
}
extension Mail {
  public var jevFlags: [JevMailFlag] { JevMailFlag.allCases.filter { $0.matches(decision) } }
}
