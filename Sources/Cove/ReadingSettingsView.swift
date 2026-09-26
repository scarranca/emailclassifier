import SwiftUI

struct ReadingSettingsView: View {
  var showsHeading = true
  @AppStorage("reading.textOnly") private var textOnly = false
  @AppStorage("reading.externalImages") private var externalImages = false

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      if showsHeading { Text("Reading").font(.coveSection) }
      Toggle(isOn: $textOnly) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Text-only reading").font(.cove(size: 13, weight: .medium))
          Text("Read the message without images, decorative layouts or sender styling. You can still show the original formatting in any email.")
            .font(.cove(size: 12)).foregroundStyle(Palette.body)
            .fixedSize(horizontal: false, vertical: true)
        }
      }.toggleStyle(CoveToggleStyle())
        .accessibilityLabel("Text-only reading")
      Toggle(isOn: $externalImages) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Load external images automatically").font(.cove(size: 13, weight: .medium))
          Text("In formatted emails, load HTTPS images when you open the message. Senders may learn that you opened it. Text-only reading never loads images.")
            .font(.cove(size: 12)).foregroundStyle(Palette.body)
            .fixedSize(horizontal: false, vertical: true)
        }
      }.toggleStyle(CoveToggleStyle())
        .accessibilityLabel("Load external images automatically")
      Text("Reading preferences are saved automatically on this Mac.")
        .font(.cove(size: 12)).foregroundStyle(Palette.muted)
    }
  }
}
