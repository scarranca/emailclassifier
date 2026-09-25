import Foundation

public enum Samples {
  public static var mail: [Mail] {
    let launchChecklist = Data(
      """
      Website launch — review checklist

      - Review the final staging site.
      - Check the new case studies and mobile layouts.
      - Send Maya your sign-off by 3 PM today for Thursday’s launch.

      Sample attachment for Cove. No live account is needed to save this file.
      """.utf8)
    let rows: [(String, String, String, String, MailCategory, Double)] = [
      (
        "Maya Chen", "maya@studiofield.example", "Website launch — final sign-off",
        "Hi Alex,\n\nWe’ve wrapped up the final updates to the website. The new case studies are in, and the mobile layouts are looking great.\n\nCould you give the staging site one last look and send your sign-off by 3 PM today? That keeps us on track for Thursday’s launch.\n\nThanks for all of your help on this one!\nMaya",
        .work, 0.97
      ),
      (
        "Oliver at Linear", "oliver@linear.example", "Your workspace, a little faster",
        "A few updates we think you’ll love.\n\nThis month we’ve improved search, simplified project updates, and made your workspace feel a little faster.",
        .updates, 0.1
      ),
      (
        "Daniel Kim", "daniel@example.com", "Coffee next week?",
        "Hey Alex,\n\nI’ll be in your neighborhood on Tuesday. Would you like to grab a coffee and catch up?\n\nDaniel",
        .people, 0.94
      ),
      (
        "Priya Shah", "priya@studiofield.example", "Q3 brand exploration",
        "Hi Alex,\n\nSharing the first round of directions for Q3. Could you send your thoughts on the typography and the new color palette?\n\nThank you,\nPriya",
        .work, 0.89
      ),
      (
        "Figma", "news@figma.example", "Your weekly design digest",
        "This week: a closer look at variables, thoughtful design systems, and the people building them.",
        .newsletters, 0.01
      ),
      (
        "Notion", "billing@notion.example", "Your receipt from Notion",
        "Your payment of $18.00 was successful.\n\nThanks for being part of Notion. Your next payment is due next month.",
        .purchases, 0.02
      ),
      (
        "Sam Rivera", "sam@example.com", "A few photos from the weekend",
        "That was a good one. Here are my favorites from our walk by the coast. Let’s do it again soon.",
        .people, 0.25
      ),
      (
        "The Creative Independent", "weekly@creative.example", "Making space for good work",
        "On slowing down, protecting your attention, and building a practice that lasts.",
        .newsletters, 0.01
      ),
    ]
    return rows.enumerated().map { index, row in
      Mail(
        id: "sample-\(index)", threadID: "sample-thread-\(index)", sender: row.0,
        senderEmail: row.1, to: "alex@example.com", subject: row.2, body: row.3,
        date: Date().addingTimeInterval(Double(-index * 780)),
        labels: index == 1 || index > 3 ? ["INBOX"] : ["INBOX", "UNREAD"],
        decision: Decision(
          category: row.4, confidence: 0.96, needsReply: row.5, urgent: index == 0 ? 0.95 : 0.1,
          excerpt: row.3.components(separatedBy: "\n\n").dropFirst().first, model: "Sample decision"
        ),
        attachments: index == 0
          ? [
            MailAttachment(
              id: "sample-launch-checklist", filename: "Website launch checklist.txt",
              mimeType: "text/plain", byteCount: launchChecklist.count,
              data: launchChecklist.base64URL
            )
          ] : nil, isBulkOrAutomated: ![.people, .work].contains(row.4))
    }
  }
}
