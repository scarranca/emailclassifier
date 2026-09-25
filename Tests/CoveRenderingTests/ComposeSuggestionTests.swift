import CoveCore
import XCTest

@testable import Cove

final class ComposeSuggestionTests: XCTestCase {
  func testFullDraftRequiresExplicitApplicationAndPreservesOriginal() throws {
    let original = "Hi Maya,\n\nI’ll review at 3 PM."
    let suggestion = ComposeSuggestion(original: original, text: "Hi Maya,\n\nI’ll review by 3 PM.")
    XCTAssertEqual(suggestion.original, original)
    XCTAssertEqual(suggestion.sourceText, original)
    XCTAssertEqual(try suggestion.applying(to: original), suggestion.text)
    XCTAssertEqual(suggestion.original, original, "Review must not mutate the user's draft")
  }

  func testSelectedRewritePreservesSurroundingTextAndUnicode() throws {
    let original = "Hi 👋 Maya,\n\nThis is really quite long.\n\nThanks, Santi"
    let range = (original as NSString).range(of: "This is really quite long.")
    let suggestion = ComposeSuggestion(original: original, selection: range, text: "This is long.")
    XCTAssertEqual(suggestion.sourceText, "This is really quite long.")
    XCTAssertEqual(try suggestion.applying(to: original), "Hi 👋 Maya,\n\nThis is long.\n\nThanks, Santi")
  }

  func testSuggestionRejectsChangesMadeDuringGenerationOrReview() {
    let suggestion = ComposeSuggestion(original: "Original", text: "AI rewrite")
    XCTAssertThrowsError(try suggestion.applying(to: "Original plus my new details")) { error in
      XCTAssertTrue(error.localizedDescription.contains("draft changed"))
    }
  }

  func testBlankSuggestionCannotReplaceDraft() {
    let suggestion = ComposeSuggestion(original: "Keep this", text: " \n ")
    XCTAssertThrowsError(try suggestion.applying(to: "Keep this"))
  }

  func testRefinementKeepsOriginalSnapshotAndSelectedRange() throws {
    let original = "Greeting. Long section. Closing."
    let range = (original as NSString).range(of: "Long section.")
    let first = ComposeSuggestion(original: original, selection: range, text: "Shorter section.")
    let refined = ComposeSuggestion(original: first.original, selection: first.selection, text: "Brief section.")
    XCTAssertEqual(try refined.applying(to: original), "Greeting. Brief section. Closing.")
  }

  func testWritingRequestIncludesOnlyExplicitPreferencesAndSelectedScope() throws {
    let instruction = ComposeSuggestion.instruction("Shorten", voice: "Warm",
      instructions: ["Ask before committing to deadlines."], selection: true)
    let prompt = try AIPrompt(intent: .write, instruction: instruction, mails: [], draft: "Selected text")
    XCTAssertTrue(prompt.user.contains("Writing voice: Warm"))
    XCTAssertTrue(prompt.user.contains("Ask before committing to deadlines."))
    XCTAssertTrue(prompt.user.contains("Rewrite only the supplied selected passage"))
    XCTAssertTrue(prompt.user.contains("Current draft (text to edit):\nSelected text"))
    XCTAssertEqual(prompt.emails, "[]")
    XCTAssertTrue(prompt.system.contains("cannot send mail"))
  }
  func testNestedRefinementPreservesBothOriginalAndUnselectedPreviewText() throws {
    let original = "Hi 👋 Maya,\n\nA very long paragraph.\n\nThanks, Santi"
    let outer = (original as NSString).range(of: "A very long paragraph.")
    let base = ComposeSuggestion(original: original, selection: outer, text: "A shorter 👋 paragraph.")
    let inner = (base.text as NSString).range(of: "shorter 👋")
    let rewrite = try ComposeRefinement(base: base, selection: inner)
    XCTAssertEqual(rewrite.sourceText, "shorter 👋")
    let result = try rewrite.merging("clearer")
    XCTAssertEqual(result.text, "A clearer paragraph.")
    XCTAssertEqual(result.original, original)
    XCTAssertEqual(result.selection, outer)
    XCTAssertEqual(try result.applying(to: original), "Hi 👋 Maya,\n\nA clearer paragraph.\n\nThanks, Santi")
    XCTAssertThrowsError(try result.applying(to: original + "edited"))
    XCTAssertThrowsError(try rewrite.merging("  "))
  }

  func testInvalidRefinementSelectionCannotBecomeFullDraftRewrite() {
    let base = ComposeSuggestion(original: "Original", text: "Hello 👋")
    for range in [NSRange(location: 500, length: 2), NSRange(location: 6, length: 1), NSRange(location: 0, length: 0)] {
      XCTAssertThrowsError(try ComposeRefinement(base: base, selection: range))
    }
  }

  func testRetrySnapshotRejectsChangedDraftOrSuggestion() {
    let attempt = WritingAttempt(request: "Shorten", draft: "Original", preview: "Pending", selection: NSRange(location: 0, length: 3), refining: true)
    XCTAssertTrue(attempt.matches(draft: "Original", preview: "Pending"))
    XCTAssertFalse(attempt.matches(draft: "Edited", preview: "Pending"))
    XCTAssertFalse(attempt.matches(draft: "Original", preview: "Edited"))
    XCTAssertFalse(attempt.matches(draft: "Original", preview: nil))
  }

}
