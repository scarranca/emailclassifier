import CoveCore
import SwiftUI

/// Settings is a main-window destination, including before Gmail sign-in.
struct SettingsView: View {
  @Bindable var store: AppStore
  @State private var clientID = UserDefaults.standard.string(forKey: "googleClientID") ?? ""
  @State private var secret = ""
  @State private var key = ""
  @State private var showAdvancedGoogle = false
  @State private var gmailExpanded = true
  @State private var jevExpanded = true
  @State private var readingExpanded = true
  @State private var saved = false
  @State private var confirmErasure = false
  @State private var includeCalendar = UserDefaults.standard.bool(forKey: "calendarConnected")
  @AppStorage("reading.externalImages") private var externalImages = false

  var body: some View {
    ScrollViewReader { proxy in
      HStack(spacing: 0) {
        SettingsSidebar(store: store, section: store.settingsSection) { destination in
          store.settingsSection = destination
          if destination == "Gmail" { gmailExpanded = true }
          if destination == "Jev · Mail agent" { jevExpanded = true }
          if destination == "Reading" { readingExpanded = true }
          withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(destination == "Settings" ? "Gmail" : destination, anchor: .top)
          }
        }.frame(width: 224)
        Divider()
        VStack(spacing: 0) {
          HStack {
            Text("Settings").font(.coveTitle)
            Spacer()
            Button(gmailExpanded || jevExpanded || readingExpanded ? "Collapse all" : "Expand all") {
              let expand = !(gmailExpanded || jevExpanded || readingExpanded)
              gmailExpanded = expand
              jevExpanded = expand
              readingExpanded = expand
            }.buttonStyle(SecondaryButton())
            Text(saved ? "Credentials saved" : "Preferences saved on this Mac").font(.coveMetadata).foregroundStyle(Palette.muted)
          }.padding(.horizontal, 32).frame(height: 86)
          Divider()
          GeometryReader { geometry in
            ScrollView {
              HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 24) {
                  DisclosureGroup(isExpanded: $gmailExpanded) {
                    gmailSection
                  } label: {
                    heading("Gmail", store.auth.isConnected ? "Connected to your everyday inbox." : "Your everyday inbox, connected to Cove.")
                  }.id("Gmail")
                  Divider()
                  DisclosureGroup(isExpanded: $jevExpanded) {
                    jevSection
                  } label: {
                    heading("Jev · Mail agent", "A little help with your inbox. You stay in control.")
                  }.id("Jev · Mail agent")
                  Divider()
                  DisclosureGroup(isExpanded: $readingExpanded) {
                    ReadingSettingsView(showsHeading: false)
                  } label: {
                    Text("Reading").font(.coveSection)
                  }.id("Reading")
                  Divider()
                  privacySection
                  Divider()
                  AppUpdateSettings().id("App updates")
                  if geometry.size.width < 1040 { preview }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if geometry.size.width >= 1040 {
                  Divider()
                  preview.frame(width: 280)
                }
              }.frame(maxWidth: 1184, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading).padding(32)
            }
          }
        }.background(Palette.canvas)
      }
      .onChange(of: store.settingsSection, initial: true) { _, destination in
        if destination == "Gmail" { gmailExpanded = true }
        if destination == "Jev · Mail agent" { jevExpanded = true }
        if destination == "Reading" { readingExpanded = true }
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo(destination == "Settings" ? "Gmail" : destination, anchor: .top)
        }
      }
    }
    .disclosureGroupStyle(CoveDisclosureStyle())
    .onAppear {
      showAdvancedGoogle = !BundledGoogleOAuth.configuration.isConfigured
      do {
        secret = try Vault.read("googleClientSecret") ?? ""
        key = try Vault.read("typesafeKey") ?? ""
      } catch { store.error = error.localizedDescription }
    }
    .onChange(of: clientID) { _, _ in saved = false }
    .onChange(of: secret) { _, _ in saved = false }
    .onChange(of: key) { _, _ in saved = false }
    .alert("Remove this account’s local data?", isPresented: $confirmErasure) {
      Button("Cancel", role: .cancel) {}
      Button("Remove local data", role: .destructive) { store.eraseLocalMailbox() }
    } message: {
      Text("This permanently removes downloaded mail, unsent drafts, local contacts, local calendar events, preferences and Jev results from Cove on this Mac. Gmail and Google Calendar stay unchanged. Existing backups are not erased.")
    }
  }

  private var gmailSection: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 16) {
        copy(store.entered ? (store.isSample ? "Sample mailbox" : store.accountEmail) : "Connect your Gmail account",
             store.auth.isConnected ? "Connected · \(syncDescription)" : "Secure sign-in with Google. No separate Cove password.")
        Spacer(minLength: 0)
        if store.auth.isConnected {
          Menu("Manage account") {
            Button("Sync now") { Task { await store.sync() } }
            Button("Reconnect Gmail") { connect() }
            Button("Disconnect") { store.disconnect() }
          }.menuStyle(.borderlessButton).fixedSize().disabled(store.busy)
        } else {
          Button("Connect Gmail") { connect() }.buttonStyle(PrimaryButton())
            .disabled(store.busy || !selectedGoogleConfiguration.isConfigured)
        }
      }
      Toggle(isOn: $store.backgroundSyncEnabled) {
        copy("Sync mail in the background", "Check for new mail about every two minutes while Cove is open.")
      }.toggleStyle(CoveToggleStyle()).accessibilityLabel("Sync mail in the background")
      copy("Mail to sync", "Cove syncs your Gmail mailbox, including Inbox, Sent and Archive. Use the sidebar to choose what you read.")
      DisclosureGroup("Google connection settings", isExpanded: $showAdvancedGoogle) {
        VStack(alignment: .leading, spacing: 16) {
          Toggle("Also connect Google Calendar", isOn: $includeCalendar).toggleStyle(CoveToggleStyle())
          Text("Calendar access is applied the next time you connect Gmail.").font(.coveMetadata).foregroundStyle(Palette.body)
          Text("Optional: use your own Desktop OAuth client. Leave the client ID blank to use Cove’s included configuration. Disconnect before changing the client for an existing connection.")
            .font(.coveMetadata).foregroundStyle(Palette.body)
          TextField("Custom Google OAuth client ID", text: $clientID).textFieldStyle(CoveFieldStyle())
          SecureField("Custom desktop client secret", text: $secret).textFieldStyle(CoveFieldStyle())
          HStack {
            Button("Save credentials") { save() }.buttonStyle(SecondaryButton()).disabled(store.busy)
            Button(store.auth.isConnected ? "Reconnect Gmail" : "Connect Gmail") { connect() }
              .buttonStyle(PrimaryButton()).disabled(store.busy || !selectedGoogleConfiguration.isConfigured)
          }
        }.padding(.top, 16)
      }.font(.coveControl).disclosureGroupStyle(CoveDisclosureStyle())
      if store.busy {
        HStack {
          ProgressView().controlSize(.small)
          Text(store.status).font(.coveMetadata)
          if store.status.contains("Connecting") { Button("Cancel sign-in") { store.auth.cancel() } }
        }
      }
    }
  }

  private var jevSection: some View {
    VStack(alignment: .leading, spacing: 20) {
      Toggle(isOn: Binding(get: { store.preferences.autoClassify }, set: { store.setAutoOrganization($0) })) {
        copy("Organize new mail with Jev", "Categorize new emails, score urgency, and select a key passage.")
      }.toggleStyle(CoveToggleStyle()).disabled(!store.entered || store.isSample || store.busy)
        .accessibilityLabel("Organize new mail with Jev")
      DisclosureGroup("TypeSafe connection") {
        VStack(alignment: .leading, spacing: 14) {
          SecureField("TypeSafe API key", text: $key).textFieldStyle(CoveFieldStyle())
          Text("Running Jev sends email content and enabled preferences to TypeSafe. TypeSafe states it does not train on inputs; zero data retention is not established.")
            .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
          HStack {
            Button("Save credentials") { save() }.buttonStyle(SecondaryButton()).disabled(store.busy)
            if saved { Label("Credentials saved", systemImage: "checkmark").font(.coveMetadata) }
            Spacer()
            Link("Get a key ↗", destination: URL(string: "https://console.typesafe.ai")!)
          }
          Link("TypeSafe privacy ↗", destination: URL(string: "https://typesafe.ai/legal/privacy-policy")!)
        }.padding(.top, 16)
      }.font(.coveControl).disclosureGroupStyle(CoveDisclosureStyle())
      HStack(spacing: 16) {
        copy("Writing voice", "The tone of your reply templates.")
        Spacer()
        CoveMenuPicker("Writing voice", selection: Binding(get: { store.preferences.voice }, set: {
          store.preferences.voice = $0; store.persistPreferences()
        }), options: [("Professional", "Professional"), ("Warm", "Warm"), ("Direct", "Direct")])
          .disabled(!store.entered)
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("Instructions for Jev").font(.coveControl)
        TextField("One instruction per line", text: Binding(
          get: { store.preferences.instructions.joined(separator: "\n") },
          set: { store.preferences.instructions = $0.components(separatedBy: "\n"); store.persistPreferences() }
        ), axis: .vertical).lineLimit(2...6).textFieldStyle(.plain).disabled(!store.entered)
          .accessibilityLabel("Instructions for Jev")
      }.padding(14).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
      Text("Jev organizes and selects passages. For generated replies and summaries, choose a writing provider in Integrations.")
        .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
    }
  }

  private var privacySection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Credentials and mailbox keys stay in macOS Keychain. Real-account mail is encrypted on this Mac. Disconnect keeps the local cache.", systemImage: "lock.shield")
        .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      if store.entered {
        Button("Remove local data and disconnect…", role: .destructive) { confirmErasure = true }
          .font(.coveControl).disabled(store.busy)
      }
    }
  }

  private var preview: some View {
    VStack(alignment: .leading, spacing: 24) {
      ZStack(alignment: .topLeading) {
        if let url = Bundle.module.url(forResource: "sign-in-landscape", withExtension: "jpg"),
           let artwork = NSImage(contentsOf: url) {
          GeometryReader { geometry in
            Image(nsImage: artwork).resizable().scaledToFill()
              .frame(width: geometry.size.width, height: 206).clipped().accessibilityHidden(true)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("A Cove that\nfeels like you.").font(.cove(size: 24, weight: .medium))
          Text("Your preferences. Your pace.").font(.coveMetadata)
        }.foregroundStyle(.white).padding(20)
      }.frame(height: 206).background(.black).clipShape(RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 14) {
        Text("A preview of your voice").font(.cove(size: 17, weight: .medium))
        Text("\(store.preferences.voice) · Sample template").font(.coveMetadata).foregroundStyle(Palette.body)
        VStack(alignment: .leading, spacing: 16) {
          Text("Re: Website launch").font(.coveControl)
          Text(ReplyTemplates.reply(to: "Maya", voice: store.preferences.voice, signoff: store.preferences.signoff))
            .font(.coveBody).lineSpacing(5)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
        Text("Nothing is sent without your review.").font(.coveMetadata).foregroundStyle(Palette.body)
      }
      Divider()
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: "checkmark.shield").font(.cove(size: 21))
        Text("Read on your terms.").font(.cove(size: 15, weight: .medium))
        Text(externalImages ? "External images load in formatted emails. Senders may learn when you open a message." : "External images are off. Load them for an individual message whenever you need to.")
          .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      }
      Button("Writing and answers ↗") { store.screen = "integrations" }
        .buttonStyle(.plain).font(.coveControl).disabled(!store.entered || store.busy)
      Text("Choose your AI provider in Integrations.").font(.coveMetadata).foregroundStyle(Palette.body)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var syncDescription: String {
    store.lastSync.map { "Last synced \($0.formatted(date: .omitted, time: .shortened))" } ?? "Ready to sync"
  }
  private func heading(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.coveSection)
      Text(subtitle).font(.coveBody).foregroundStyle(Palette.body)
    }
  }
  private func copy(_ title: String, _ help: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.coveControl)
      Text(help).font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
    }
  }
  private func connect() {
    if save() { Task { await store.connect(includeCalendar: includeCalendar) } }
  }
  private var selectedGoogleConfiguration: GoogleOAuthConfiguration {
    GoogleOAuthConfiguration.selected(
      customClientID: clientID, customSecret: secret,
      bundled: BundledGoogleOAuth.configuration)
  }
  @discardableResult func save() -> Bool {
    do {
      let clean = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
      if store.auth.isConnected && selectedGoogleConfiguration.clientID != store.auth.clientID {
        throw CoveError.message("Disconnect Gmail before changing its OAuth client ID.")
      }
      try Vault.save(
        secret.trimmingCharacters(in: .whitespacesAndNewlines), name: "googleClientSecret")
      try Vault.save(key.trimmingCharacters(in: .whitespacesAndNewlines), name: "typesafeKey")
      UserDefaults.standard.set(clean, forKey: "googleClientID")
      saved = true
      return true
    } catch {
      store.error = error.localizedDescription
      return false
    }
  }
}
