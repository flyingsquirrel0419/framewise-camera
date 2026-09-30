import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.guide") {
                    Toggle("settings.show_guide", isOn: $settings.showGuide)
                    Toggle("settings.show_target", isOn: $settings.showTarget)
                        .disabled(!settings.showGuide)
                    Toggle("settings.show_tips", isOn: $settings.showTips)
                    Toggle("settings.show_score", isOn: $settings.showScore)
                    Toggle("settings.haptics", isOn: $settings.haptics)
                }
                Section {
                    Toggle("settings.show_candidates", isOn: $settings.showCandidates)
                    Toggle("settings.auto_focus", isOn: $settings.autoFocusSubject)
                } header: {
                    Text("settings.section.subject")
                } footer: {
                    Text("settings.candidates_footer")
                }
                Section("settings.section.camera") {
                    Toggle("settings.grid", isOn: $settings.showGrid)
                    Toggle("settings.level", isOn: $settings.showLevel)
                    Toggle("settings.auto_scene", isOn: $settings.autoScene)
                }
                Section {
                    Toggle("settings.save_photos", isOn: $settings.saveToPhotos)
                    Toggle("settings.prefer_heif", isOn: $settings.preferHEIF)
                } header: {
                    Text("settings.section.saving")
                } footer: {
                    Text("settings.heif_footer")
                }
                Section {
                    LabeledContent("settings.version", value: version)
                } footer: {
                    Text("about.on_device")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }
}
