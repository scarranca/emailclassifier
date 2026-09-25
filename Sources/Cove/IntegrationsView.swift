import CoveCore
import SwiftUI
import UniformTypeIdentifiers

struct IntegrationsView: View {
  @Bindable var store: AppStore
  @State private var settings = AIProviderSettings.shared
  @State private var connection = ChatGPTConnection.shared
  @State private var claude = ClaudeConnection.shared
  @State private var chooseClaudeExecutable = false
  @State private var selectedProvider = AIProviderSettings.shared.provider
  @State private var testedConfiguration: String?
  @State private var testingModel = false
  @State private var key = ""
  @State private var model = ""
  @State private var models: [String] = []
  @State private var notice: String?
  @State private var noticeIsError = false
  @State private var busy = false
  @State private var task: Task<Void, Never>?
  @State private var chooseExecutable = false
  @State private var checkingConnection = false
  @State private var connectionFeedback: String?
  @State private var useExactModel = false
  @AppStorage("integrations.tasksExpanded") private var tasksExpanded = true
  @AppStorage("integrations.githubExpanded") private var githubExpanded = true
  @AppStorage("integrations.writingExpanded") private var writingExpanded = true
  @State private var connectionExpanded = false

  init(store: AppStore, settings: AIProviderSettings? = nil, initialProvider: AIProvider? = nil) {
    self.store = store
    let settings = settings ?? .shared
    _settings = State(initialValue: settings)
    _claude = State(initialValue: settings.claude)
    _selectedProvider = State(initialValue: initialProvider ?? settings.provider)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Integrations").font(.coveTitle)
          Text("Connect the tools you use. Keep your work together in Cove.")
            .font(.coveBody).foregroundStyle(Palette.body)
        }
        Spacer(minLength: 0)
        Button(tasksExpanded || githubExpanded || writingExpanded ? "Collapse all" : "Expand all") {
          let expand = !(tasksExpanded || githubExpanded || writingExpanded)
          tasksExpanded = expand
          githubExpanded = expand
          writingExpanded = expand
          connectionExpanded = expand
        }.buttonStyle(SecondaryButton())
      }.padding(.horizontal, 32).padding(.vertical, 24)
      Divider()
      GeometryReader { _ in
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            landscape
            writingPanel
            HStack(alignment: .top, spacing: 16) {
              toolCard("Google Tasks", icon: "checklist", detail: "Your lists, tasks, and due dates. Always in view.")
              toolCard("GitHub", icon: "chevron.left.forwardslash.chevron.right", detail: "Assigned issues, alongside your Google tasks.")
            }
            Label("Your connections stay under your control. Disconnect an account anytime.", systemImage: "lock.shield")
              .font(.coveMetadata).foregroundStyle(Palette.body)
          }.frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading).padding(32)
        }
      }
    }.background(Palette.canvas).foregroundStyle(Palette.ink)
      .onAppear { load(selectedProvider) }
      .onDisappear { task?.cancel() }
      .onChange(of: selectedProvider) { _, provider in load(provider) }
      .onChange(of: connection.connected) { _, connected in
        if connected && selectedProvider == .chatGPT && models.isEmpty && !busy {
          run { try await refreshModels() }
        }
      }
      .fileImporter(isPresented: $chooseClaudeExecutable, allowedContentTypes: [.unixExecutable]) { result in
        if case .success(let url) = result {
          claude.executablePath = url.path
          settings.modelCatalog.clear(.claudeSubscription)
          testedConfiguration = nil
          notice = "Claude Code selected. Check the connection to continue."
        }
      }
      .onChange(of: model) { _, _ in testedConfiguration = nil }
      .fileImporter(isPresented: $chooseExecutable, allowedContentTypes: [.unixExecutable]) { result in
        if case .success(let url) = result {
          connection.executablePath = url.path
          connectionFeedback = nil
          testedConfiguration = nil
          notice = "Codex executable selected. Check the connection to continue."
        }
      }
  }

  private var landscape: some View {
    ZStack(alignment: .leading) {
      GeometryReader { geometry in
        if let url = Bundle.module.url(forResource: "integrations-landscape", withExtension: "png"),
           let artwork = NSImage(contentsOf: url) {
          Image(nsImage: artwork).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: 142).clipped().accessibilityHidden(true)
        }
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("Your tools. A little more connected.").font(.cove(size: 24, weight: .medium))
        Text("Bring your tasks, ideas, and answers into Cove.").font(.coveBody)
          .foregroundStyle(.white.opacity(0.85))
      }.foregroundStyle(.white).padding(26)
    }.frame(height: 142).background(.black).clipShape(RoundedRectangle(cornerRadius: 9))
  }

  private func toolCard(_ title: String, icon: String, detail: String) -> some View {
    DisclosureGroup(isExpanded: title == "Google Tasks" ? $tasksExpanded : $githubExpanded) {
      VStack(alignment: .leading, spacing: 14) {
      Text(detail).font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      Text("Coming later").font(.coveMetadata).foregroundStyle(Palette.body)
        .padding(.horizontal, 10).padding(.vertical, 6).background(Palette.selection, in: Capsule())
      Text(title == "Google Tasks" ? "Google Tasks is not connected yet. Gmail and Calendar are managed in Settings." : "Repository connections are not available yet. Cove has no access to your GitHub repositories.")
        .font(.coveMetadata).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
      }.padding(.top, 14)
    } label: {
      Label(title, systemImage: icon).font(.cove(size: 17))
        .frame(maxWidth: .infinity, alignment: .leading)
    }.disclosureGroupStyle(CoveDisclosureStyle())
      .frame(maxWidth: .infinity, alignment: .leading).padding(20)
      .background(Palette.surface, in: RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line))
  }

  private var writingPanel: some View {
    DisclosureGroup(isExpanded: $writingExpanded) {
      writingContent.padding(.top, 22)
    } label: {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Label("Writing and answers", systemImage: "sparkles").font(.coveSection)
          Text("Choose the AI Cove uses for drafts, summaries, and chat.").font(.coveBody).foregroundStyle(Palette.body)
        }
        Spacer(minLength: 12)

      }
    }.disclosureGroupStyle(CoveDisclosureStyle())
      .padding(24).background(Palette.canvas, in: RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line))
  }

  private var writingContent: some View {
    VStack(alignment: .leading, spacing: 24) {
      if !settings.model(settings.provider).isEmpty {
        HStack(spacing: 10) {
          Image(systemName: "checkmark.circle.fill")
          VStack(alignment: .leading, spacing: 4) {
            Text("Current default").font(.coveMetadata).foregroundStyle(Palette.body)
            Text(settings.modelLabel(settings.model(settings.provider), provider: settings.provider))
              .font(.coveControl)
            Text(settings.provider.title).font(.coveMetadata).foregroundStyle(Palette.body)
          }
          Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
          .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("AI account").font(.coveControl)
        CoveMenuPicker("AI account", selection: $selectedProvider, options: [
          (.chatGPT, "ChatGPT · subscription"), (.claudeSubscription, "Claude · subscription"),
          (.openAI, "OpenAI · API key"), (.anthropic, "Anthropic · API key"), (.openRouter, "OpenRouter · API key")
        ]).disabled(busy)
        Text(selectedProvider.isSubscription
          ? "Use your existing subscription. Your plan’s limits apply."
          : "Use an API key. Usage is billed separately by the provider.")
          .font(.coveMetadata).foregroundStyle(Palette.body)
      }
      if ready {
        HStack {
          Label(selectedProvider.isSubscription ? "Account connected" : "API key saved", systemImage: "checkmark.circle")
            .font(.coveControl)
          Spacer()
          Button(connectionExpanded ? "Done" : "Manage connection") { connectionExpanded.toggle() }
            .buttonStyle(SecondaryButton(compact: true)).disabled(busy)
        }
      }
      if !ready || connectionExpanded {
        VStack(alignment: .leading, spacing: 16) {
          if selectedProvider == .chatGPT { subscription }
          else if selectedProvider == .claudeSubscription { claudeSubscription }
          else { apiKey }
        }.disabled(busy)
      }
      Divider()
      modelConfiguration
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Button(testingModel ? "Testing model…" : isSavedConfiguration ? "Test current model" : "Test & use model") {
            testingModel = true
            testedConfiguration = nil
            run {
              defer { testingModel = false }
              try await settings.testAndUseModel(model, provider: selectedProvider)
              try Task.checkCancellation()
              testedConfiguration = configurationID
              connectionExpanded = false
              notice = "Ready. \(settings.modelLabel(model, provider: selectedProvider)) is now your default for writing and chat."
            }
          }.buttonStyle(PrimaryButton()).disabled(!canSave || busy)
          if busy {
            ProgressView().controlSize(.small)
            Button("Cancel") { task?.cancel() }.buttonStyle(SecondaryButton(compact: true))
          }
        }
        Text("Tests with a short sample, then saves your choice. No email content is sent for the test.")
          .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
        if let notice {
          Label(notice, systemImage: noticeIsError ? "exclamationmark.circle" : testedConfiguration == configurationID ? "checkmark.circle" : "info.circle")
            .font(.coveControl).foregroundStyle(noticeIsError ? Palette.danger : Palette.body)
            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
        }
      }
      Divider()
      DisclosureGroup("Privacy & email context") {
        Text("Cove shares relevant text with your chosen provider when you write or ask a question: your instructions, recipients, draft, up to 20 relevant emails (48 KB), and calendar context when lookups are enabled. Reply rules you enable also send the triggering email, readable attachment text, and writing instructions during sync. Provider usage and data policies apply. Jev organizes mail separately. You review every email before sending.")
          .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
          .padding(.top, 8)
      }.font(.coveMetadata).disclosureGroupStyle(CoveDisclosureStyle())
    }
  }

  private var modelConfiguration: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Model").font(.coveControl)
        Spacer()
        Button { run { try await refreshModels() } } label: {
          Label("Refresh list", systemImage: "arrow.clockwise")
        }.buttonStyle(SecondaryButton(compact: true)).disabled(busy || !ready)
      }
      if !ready {
        Text("Connect your account to see its models.").font(.coveBody).foregroundStyle(Palette.body)
      } else if useExactModel {
        TextField("Exact model ID", text: $model).textFieldStyle(CoveFieldStyle()).disabled(busy)
      } else if models.isEmpty {
        Text(busy ? "Loading model versions…" : "Refresh the list to choose a model.")
          .font(.coveBody).foregroundStyle(Palette.body)
      } else {
        CoveMenuPicker("Model", selection: $model,
          options: (models.contains(model) || model.isEmpty ? models : [model] + models).map {
            ($0, settings.modelLabel($0, provider: selectedProvider))
          }).disabled(busy)
        if selectedProvider == .claudeSubscription, !model.isEmpty {
          Text(!model.hasPrefix("claude-")
            ? "Automatic follows your account’s recommended model as it changes."
            : "Model ID: " + model)
            .font(.coveMetadata).foregroundStyle(Palette.body).textSelection(.enabled)
        }
      }
      if ready {
        Button(useExactModel ? "Choose from the model list" : "Use a custom model ID…") { useExactModel.toggle() }
          .buttonStyle(.plain).font(.coveMetadata).foregroundStyle(Palette.body).disabled(busy)
        Text(selectedProvider == .claudeSubscription
          ? "Versions come from Claude Code. Availability and usage credits depend on your plan; the test confirms access."
          : "Models come from your account. You can also switch models for individual chats.")
          .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      }
    }
  }
  private var ready: Bool { selectedProvider == .chatGPT ? connection.connected : selectedProvider == .claudeSubscription ? claude.connected : settings.hasKey(selectedProvider) }
  private var canSave: Bool { ready && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && key.isEmpty }
  private var configurationID: String { selectedProvider.rawValue + ":" + model }
  private var isSavedConfiguration: Bool {
    settings.provider == selectedProvider && settings.model(selectedProvider) == model
  }
  private var apiKey: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("API key").font(.coveControl)
      SecureField(
        settings.hasKey(selectedProvider) ? "Replace saved API key" : "Paste API key", text: $key
      ).textFieldStyle(CoveFieldStyle())
        .accessibilityLabel("\(selectedProvider.title) API key")
      HStack {
        Button("Save key") {
          do {
            try settings.saveKey(key, provider: selectedProvider)
            key = ""
            testedConfiguration = nil
            run { try await refreshModels() }
          } catch { noticeIsError = true; notice = error.localizedDescription }
        }.buttonStyle(PrimaryButton()).disabled(
          key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if settings.hasKey(selectedProvider) {
          Label("Key saved", systemImage: "checkmark.shield").font(.coveControl)
          Spacer()
          Button("Remove key") {
            do {
              try settings.removeKey(selectedProvider)
              testedConfiguration = nil
              notice = "API key removed."
            } catch { notice = error.localizedDescription }
          }.buttonStyle(SecondaryButton())
        }
      }
      if selectedProvider == .openAI {
        Text(
          "OpenAI API usage is billed separately from ChatGPT. To use a ChatGPT plan, choose ChatGPT subscription above."
        ).font(.coveMetadata).foregroundStyle(Palette.body)
      }
    }
  }
  private var claudeSubscription: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Sign in with Claude, then return here to choose a model.")
        .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      Text(claude.status).font(.coveControl)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { claudeActions }
        VStack(alignment: .leading, spacing: 10) { claudeActions }
      }
      DisclosureGroup("Advanced connection options") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Claude Code manages its own sign-in in a separate Cove configuration. Cove does not copy your subscription credentials. Requests use no Claude file, shell, or MCP tools; Cove supplies the relevant context.")
            .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
          Text(claude.executablePath.isEmpty ? "No Claude Code installation found" : claude.executablePath)
            .font(.coveMetadata).foregroundStyle(Palette.muted).textSelection(.enabled)
          Button("Select Claude Code…") { chooseClaudeExecutable = true }
            .buttonStyle(SecondaryButton()).disabled(busy)
          Link("Install official Claude Code", destination: URL(string: "https://code.claude.com/docs/en/setup")!)
            .font(.coveControl)
          Text("API keys use the separate Anthropic · API key connection.")
            .font(.coveMetadata).foregroundStyle(Palette.body)
        }.padding(.top, 12)
      }.font(.coveMetadata).disclosureGroupStyle(CoveDisclosureStyle())
    }
  }
  @ViewBuilder private var claudeActions: some View {
    Button(claude.connected ? "Reconnect Claude" : "Connect Claude") {
      testedConfiguration = nil
      run {
        try await claude.login()
        try await refreshModels()
      }
    }.buttonStyle(PrimaryButton()).disabled(busy)
    Button("Check connection") {
      testedConfiguration = nil
      run {
        try await claude.refresh()
        if claude.connected { try await refreshModels() }
        notice = claude.connected ? "Claude connected. Choose a model below." : "No subscription sign-in found. Choose Connect Claude to sign in."
      }
    }.buttonStyle(SecondaryButton()).disabled(busy)
    if claude.connected {
      Button("Disconnect") {
        run {
          try await claude.logout()
          settings.modelCatalog.clear(.claudeSubscription)
          testedConfiguration = nil
          notice = "Claude disconnected from Cove."
        }
      }.buttonStyle(SecondaryButton()).disabled(busy)
    }
  }
  private var subscription: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Sign in through your browser, then return here to choose a model. Plan access and usage limits apply.")
        .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
      Text(connection.status).font(.coveControl)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { subscriptionActions }
        VStack(alignment: .leading, spacing: 10) { subscriptionActions }
      }
      if let connectionFeedback {
        Label(
          connectionFeedback, systemImage: connection.connected ? "checkmark.circle" : "info.circle"
        )
        .font(.coveControl).foregroundStyle(Palette.body)
        .fixedSize(horizontal: false, vertical: true)
      }
      DisclosureGroup("Advanced connection options") {
        Text("Uses the official Codex CLI installed on this Mac. Cove keeps a separate sign-in in Keychain. Keep Codex updated to discover the latest models.")
          .font(.coveMetadata).foregroundStyle(Palette.body).fixedSize(horizontal: false, vertical: true)
        Text(connection.executablePath.isEmpty ? "No Codex installation found" : connection.executablePath)
          .font(.coveMetadata).foregroundStyle(Palette.muted).textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
        Button("Select Codex…") { chooseExecutable = true }.buttonStyle(SecondaryButton())
        Link(
          "Install official Codex",
          destination: URL(string: "https://developers.openai.com/codex/cli")!
        ).font(.coveControl)
      }.font(.coveMetadata).disclosureGroupStyle(CoveDisclosureStyle())
    }
  }
  @ViewBuilder private var subscriptionActions: some View {
        Button(connection.connected ? "Reconnect ChatGPT" : "Sign in with ChatGPT") {
          connectionFeedback = nil
          testedConfiguration = nil
          run { try await connection.login() }
        }.buttonStyle(PrimaryButton()).disabled(busy)
        Button(checkingConnection ? "Checking…" : "Check connection") {
          connectionFeedback = nil
          testedConfiguration = nil
          checkingConnection = true
          run {
            defer { checkingConnection = false }
            try await connection.refresh()
            try Task.checkCancellation()
            let time = Date().formatted(date: .omitted, time: .standard)
            if connection.connected { try await refreshModels() }
            connectionFeedback =
              connection.connected
              ? "ChatGPT sign-in confirmed at \(time)."
              : "Checked at \(time). No saved ChatGPT sign-in was found. Click Sign in with ChatGPT to connect."
          }
        }.buttonStyle(SecondaryButton()).disabled(busy)
        if connection.connected {
          Button("Disconnect") {
            connectionFeedback = nil
            testedConfiguration = nil
        run {
          try await connection.logout()
          settings.modelCatalog.clear(.chatGPT)
        }
          }.buttonStyle(
            SecondaryButton()
          ).disabled(busy)
        }
  }
  private func load(_ provider: AIProvider) {
    key = ""
    model = settings.model(provider)
    models = []
    notice = nil
    noticeIsError = false
    connectionExpanded = false
    testedConfiguration = nil
    connectionFeedback = nil
    useExactModel = false
    if provider == .claudeSubscription {
      run {
        try await claude.refresh()
        if claude.connected { try await refreshModels() }
      }
    } else if provider == .chatGPT {
      run {
        try await connection.refresh()
        if connection.connected { try await refreshModels() }
      }
    } else if settings.hasKey(provider) {
      run { try await refreshModels() }
    }
  }
  private func refreshModels() async throws {
    let available = try await settings.models(selectedProvider)
    try Task.checkCancellation()
    models = available
    if model.isEmpty, let first = models.first { model = first }
    if selectedProvider == .claudeSubscription {
      notice = nil
      return
    }
    notice = models.isEmpty
      ? "No models returned. Enter an exact model ID or update the official Codex CLI."
      : nil
  }
  private func run(_ action: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }
    busy = true
    notice = nil
    noticeIsError = false
    task = Task { @MainActor in
      defer {
        busy = false
        task = nil
      }
      do { try await action() } catch {
        if Task.isCancelled { notice = "Cancelled. Your saved default is unchanged." }
        else { noticeIsError = true; notice = error.localizedDescription }
      }
    }
  }
}
