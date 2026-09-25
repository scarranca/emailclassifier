import SwiftUI

// Home distinguishes work needing attention from supporting information.
// Sizes are native macOS points; stronger weights stay scoped to actionable content.
enum HomeType {
  static let primarySection = Font.cove(size: 18, weight: .semibold)
  static let supportingSection = Font.cove(size: 16, weight: .medium)
  static let itemTitle = Font.cove(size: 14, weight: .semibold)
  static let supportingTitle = Font.cove(size: 14, weight: .medium)
  static let compactBody = Font.cove(size: 12)
  static let action = Font.cove(size: 12, weight: .medium)
  static let metadata = Font.cove(size: 11)
}
