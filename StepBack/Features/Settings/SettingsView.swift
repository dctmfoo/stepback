import CloudKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(PlayerPreferences.voiceKey) private var voiceAnnouncements = true
    @AppStorage(PlayerPreferences.tonesKey) private var countdownTones = true
    @AppStorage(PlayerPreferences.getReadyKey) private var getReadySeconds = 5
    @State private var syncStatusModel: CloudAccountStatusModel
    #if os(macOS)
    @AppStorage(AgentBridgeSettings.allowChangesKey) private var allowAgentChanges = true
    #endif

    init(syncStatusModel: CloudAccountStatusModel = .appDefault()) {
        _syncStatusModel = State(initialValue: syncStatusModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $voiceAnnouncements) {
                        SettingsControlLabel(
                            title: L10n.settingsVoice,
                            detail: L10n.settingsVoiceDetail,
                            systemImage: "speaker.wave.2.fill"
                        )
                    }
                    .tint(Color("PulseAzure"))
                    .accessibilityIdentifier("settings.voice")

                    Toggle(isOn: $countdownTones) {
                        SettingsControlLabel(
                            title: L10n.settingsTones,
                            detail: L10n.settingsTonesDetail,
                            systemImage: "metronome.fill"
                        )
                    }
                    .tint(Color("PulseAzure"))
                    .accessibilityIdentifier("settings.tones")
                } header: {
                    settingsSectionHeader(L10n.settingsSectionAudio, identifier: "settings.section.audio")
                }

                Section {
                    Picker(selection: $getReadySeconds) {
                        ForEach(Array(stride(from: 0, through: 30, by: 5)), id: \.self) { seconds in
                            Text(DisplayFormatters.duration(seconds)).tag(seconds)
                        }
                    } label: {
                        SettingsControlLabel(
                            title: L10n.settingsGetReady,
                            detail: L10n.settingsGetReadyDetail,
                            systemImage: "figure.mind.and.body"
                        )
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.navigationLink)
                    #endif
                    .accessibilityIdentifier("settings.getReady")
                } header: {
                    settingsSectionHeader(L10n.settingsSectionPlayer, identifier: "settings.section.player")
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud")
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                        Text(L10n.settingsSync)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(syncStatusModel.statusText)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.sync")
                } header: {
                    settingsSectionHeader(L10n.settingsSectionICloud, identifier: "settings.section.icloud")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.privacy, systemImage: "lock.shield")
                            .accessibilityIdentifier("settings.privacy")
                        Text(versionText)
                            .accessibilityIdentifier("settings.version")
                    }
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
                }

                #if os(macOS)
                Section {
                    Toggle(L10n.settingsAgentBridgeToggle, isOn: $allowAgentChanges)
                        .tint(Color("PulseAzure"))
                        .accessibilityIdentifier("settings.agentBridge.toggle")

                    Button(
                        L10n.settingsAgentBridgeReveal,
                        systemImage: "folder",
                        action: AgentBridgeFolderRevealer.reveal
                    )
                    .accessibilityIdentifier("settings.agentBridge.reveal")
                } header: {
                    settingsSectionHeader(
                        L10n.settingsAgentBridgeTitle,
                        identifier: "settings.section.agentBridge"
                    )
                } footer: {
                    Text(L10n.settingsAgentBridgeFooter)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
                #endif
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(L10n.tabSettings)
            .task {
                await syncStatusModel.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                Task {
                    await syncStatusModel.accountDidChange()
                }
            }
        }
    }

    private var versionText: String {
        L10n.version(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        )
    }

    private func settingsSectionHeader(_ title: String, identifier: String) -> some View {
        Text(title)
            .foregroundStyle(PlatformColors.secondaryText)
            .accessibilityIdentifier(identifier)
    }
}
