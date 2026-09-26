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
  @State private var cloudExpanded = true
  @State private var privacyExpanded = false
  @State private var updatesExpanded = false
  var readSecret: (String) throws -> String? = { try Vault.read($0) }

  private var anyExpanded: Bool {
    gmailExpanded || jevExpanded || readingExpanded || (store.cloudConfigured && cloudExpanded) || privacyExpanded || updatesExpanded
  }
  private func reveal(_ destination: String) {
    if destination == "Settings" || destination == "Gmail" { gmailExpanded = true }
    if destination == "Jev · Mail agent" { jevExpanded = true }
    if destination == "Reading" { readingExpanded = true }
    if destination == "Cloud sync" { cloudExpanded = true }
    if destination == "Privacy" { privacyExpanded = true }
    if destination == "App updates" { updatesExpanded = true }
  }

  var body: some View {
    ScrollViewReader { proxy in
      HStack(spacing: 0) {
        SettingsSidebar(store: store, section: store.settingsSection) { destination in
          store.settingsSection = destination
          reveal(destination)
          withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(destination == "Settings" ? "Gmail" : destination, anchor: .top)
          }
        }.frame(width: 224)
        Divider()
        VStack(spacing: 0) {
          HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
              Text("Settings").font(.cove(size: 26, weight: .medium))
              Text(saved ? "Credentials saved." : "Make Cove work your way.")
                .font(.coveBody).foregroundStyle(Palette.body)
            }
            Spacer(minLength: 0)
            Button(anyExpanded ? "Collapse all" : "Expand all") {
              let expand = !anyExpanded
              gmailExpanded = expand; jevExpanded = expand; readingExpanded = expand
              cloudExpanded = expand; privacyExpanded = expand; updatesExpanded = expand
            }.buttonStyle(SecondaryButton())
          }.padding(.horizontal, 32).padding(.vertical, 24)
          Divider()
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              DisclosureGroup(isExpanded: $gmailExpanded) {
                gmailSection
              } label: {
                heading("Gmail", store.auth.isConnected ? "Connected · \(store.accountEmail)" : "Connect your inbox and calendar.", icon: "envelope")
              }.id("Gmail")
              DisclosureGroup(isExpanded: $jevExpanded) {
                jevSection
              } label: {
                heading("Jev · Mail agent", store.preferences.autoClassify ? "Automatic organization is on" : "Automatic organization is off", icon: "sparkles")
              }.id("Jev · Mail agent")
              DisclosureGroup(isExpanded: $readingExpanded) {
                ReadingSettingsView(showsHeading: false)
              } label: {
                heading("Reading", "Message appearance and image privacy", icon: "text.alignleft")
              }.id("Reading")
              if store.cloudConfigured {
                CloudSyncSettings(store: store, expansion: $cloudExpanded).id("Cloud sync")
              }
              DisclosureGroup(isExpanded: $privacyExpanded) {
                privacySection
              } label: {
                heading("Privacy & local data", "Storage and account removal", icon: "lock.shield")
              }.id("Privacy")
              DisclosureGroup(isExpanded: $updatesExpanded) {
                AppUpdateSettings()
              } label: {
                heading("App updates", "Keep Cove up to date", icon: "arrow.down.circle")
              }.id("App updates")
              Text("Preferences save automatically on this Mac. Connection credentials have their own Save button.")
                .font(.cove(size: 13)).foregroundStyle(Palette.body)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }.disclosureGroupStyle(SettingsSectionDisclosureStyle())
              .frame(maxWidth: 800, alignment: .leading)
              .frame(maxWidth: .infinity, alignment: .leading).padding(32)
          }

        }.background(Palette.canvas)
      }
      .onChange(of: store.settingsSection, initial: true) { _, destination in
        reveal(destination)
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo(destination == "Settings" ? "Gmail" : destination, anchor: .top)
        }
      }
    }
    .disclosureGroupStyle(CoveDisclosureStyle())
    .onAppear {
      showAdvancedGoogle = !BundledGoogleOAuth.configuration.isConfigured
      do {
        secret = try readSecret("googleClientSecret") ?? ""
        key = try readSecret("typesafeKey") ?? ""
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

      DisclosureGroup("Google connection settings", isExpanded: $showAdvancedGoogle) {
        VStack(alignment: .leading, spacing: 16) {
          Toggle("Also connect Google Calendar", isOn: $includeCalendar).toggleStyle(CoveToggleStyle())
          Text("Calendar access is applied the next time you connect Gmail.").font(.cove(size: 13)).foregroundStyle(Palette.body)
          Text("Optional: use your own Desktop OAuth client. Leave the client ID blank to use Cove’s included configuration. Disconnect before changing the client for an existing connection.")
            .font(.cove(size: 13)).foregroundStyle(Palette.body)
          TextField("Custom Google OAuth client ID", text: $clientID).textFieldStyle(CoveFieldStyle())
          SecureField("Custom desktop client secret", text: $secret).textFieldStyle(CoveFieldStyle())
          HStack {
            Button("Save credentials") { save() }.buttonStyle(SecondaryButton()).disabled(store.busy)
            Button(store.auth.isConnected ? "Reconnect Gmail" : "Connect Gmail") { connect() }
              .buttonStyle(PrimaryButton()).disabled(store.busy || !selectedGoogleConfiguration.isConfigured)
          }
        }.padding(.top, 16)
      }.font(.cove(size: 14, weight: .medium)).disclosureGroupStyle(CoveDisclosureStyle())
      if store.busy {
        HStack {
          ProgressView().controlSize(.small)
          Text(store.status).font(.cove(size: 13))
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
      DisclosureGroup(key.isEmpty ? "TypeSafe connection · Add a key" : "TypeSafe connection · Manage key") {
        VStack(alignment: .leading, spacing: 14) {
          SecureField("TypeSafe API key", text: $key).textFieldStyle(CoveFieldStyle())
          Text("Running Jev sends email content and enabled preferences to TypeSafe. TypeSafe states it does not train on inputs; zero data retention is not established.")
            .font(.cove(size: 13)).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
          HStack {
            Button("Save credentials") { save() }.buttonStyle(SecondaryButton()).disabled(store.busy)
            if saved { Label("Credentials saved", systemImage: "checkmark").font(.cove(size: 13)) }
            Spacer()
            Link("Get a key ↗", destination: URL(string: "https://console.typesafe.ai")!)
          }
          Link("TypeSafe privacy ↗", destination: URL(string: "https://typesafe.ai/legal/privacy-policy")!)
        }.padding(.top, 16)
      }.font(.cove(size: 14, weight: .medium)).disclosureGroupStyle(CoveDisclosureStyle())
      Divider()
      HStack(spacing: 16) {
        copy("Writing voice", "The tone of your reply templates.")
        Spacer()
        CoveMenuPicker("Writing voice", selection: Binding(get: { store.preferences.voice }, set: {
          store.preferences.voice = $0; store.persistPreferences()
        }), options: [("Professional", "Professional"), ("Warm", "Warm"), ("Direct", "Direct")])
          .disabled(!store.entered)
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("Instructions for Jev").font(.cove(size: 14, weight: .medium))
        TextField("One instruction per line", text: Binding(
          get: { store.preferences.instructions.joined(separator: "\n") },
          set: { store.preferences.instructions = $0.components(separatedBy: "\n"); store.persistPreferences() }
        ), axis: .vertical).lineLimit(2...6).textFieldStyle(.plain).disabled(!store.entered)
          .accessibilityLabel("Instructions for Jev")
      }.padding(14).overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
      Button { store.screen = "integrations" } label: {
        Label("Set up AI writing & chat in Integrations", systemImage: "arrow.up.right")
      }.buttonStyle(SecondaryButton()).disabled(!store.entered || store.busy)
    }
  }

  private var privacySection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Credentials and mailbox keys stay in macOS Keychain. Real-account mail is encrypted on this Mac. Disconnect keeps the local cache.", systemImage: "lock.shield")
        .font(.cove(size: 13)).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      if store.entered {
        Button("Remove local data and disconnect…", role: .destructive) { confirmErasure = true }
          .font(.cove(size: 14, weight: .medium)).disabled(store.busy)
      }
    }
  }

  private var syncDescription: String {
    store.lastSync.map { "Last synced \($0.formatted(date: .omitted, time: .shortened))" } ?? "Ready to sync"
  }
  private func heading(_ title: String, _ subtitle: String, icon: String) -> some View {
    SettingsSectionHeading(title: title, subtitle: subtitle, icon: icon)
  }
  private func copy(_ title: String, _ help: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.cove(size: 14, weight: .medium))
      Text(help).font(.cove(size: 13)).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
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
