//
//  DictionarySettings.swift
//  boringNotch
//
//  Settings for the Japanese dictionary tab and its Anki integration.
//

import Defaults
import SwiftUI

struct DictionarySettings: View {
    @Default(.ankiConnectURL) var ankiConnectURL
    @Default(.ankiDeckName) var ankiDeckName
    @Default(.ankiNoteType) var ankiNoteType
    @Default(.ankiFrontField) var ankiFrontField
    @Default(.ankiBackField) var ankiBackField

    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var decks: [String] = []
    @State private var models: [String] = []
    @State private var fields: [String] = []
    @State private var isLoading = false

    private enum ConnectionStatus: Equatable {
        case unknown
        case connected
        case failed(String)
    }

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showDictionaryTab) {
                    Text("Show dictionary tab")
                }
            } footer: {
                Text("Adds a Japanese dictionary tab (powered by Jisho) to the open notch.")
            }

            Section(header: Text("Anki integration")) {
                Text("Requires the Anki desktop app to be running with the AnkiConnect add-on installed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("AnkiConnect URL", text: $ankiConnectURL)

                HStack {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        Text(isLoading ? "Connecting…" : "Test connection")
                    }
                    .disabled(isLoading)

                    Spacer()
                    statusLabel
                }
            }

            Section(header: Text("Card mapping")) {
                deckField
                modelField
                frontField
                backField
            }
        }
        .formStyle(.grouped)
        .task { await testConnection() }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch connectionStatus {
        case .unknown:
            EmptyView()
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var deckField: some View {
        if decks.isEmpty {
            TextField("Deck", text: $ankiDeckName)
        } else {
            Picker("Deck", selection: $ankiDeckName) {
                ForEach(decks, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    @ViewBuilder
    private var modelField: some View {
        if models.isEmpty {
            TextField("Note type", text: $ankiNoteType)
        } else {
            Picker("Note type", selection: $ankiNoteType) {
                ForEach(models, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: ankiNoteType) { _, newValue in
                Task { await loadFields(for: newValue) }
            }
        }
    }

    @ViewBuilder
    private var frontField: some View {
        if fields.isEmpty {
            TextField("Front field", text: $ankiFrontField)
        } else {
            Picker("Front field", selection: $ankiFrontField) {
                ForEach(fields, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    @ViewBuilder
    private var backField: some View {
        if fields.isEmpty {
            TextField("Back field", text: $ankiBackField)
        } else {
            Picker("Back field", selection: $ankiBackField) {
                ForEach(fields, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private func testConnection() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await AnkiConnectService.checkConnection()
            decks = (try? await AnkiConnectService.deckNames())?.sorted() ?? []
            models = (try? await AnkiConnectService.modelNames())?.sorted() ?? []
            await loadFields(for: ankiNoteType)
            connectionStatus = .connected
        } catch {
            decks = []
            models = []
            fields = []
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    private func loadFields(for model: String) async {
        guard !model.isEmpty else { fields = []; return }
        fields = (try? await AnkiConnectService.fieldNames(for: model)) ?? []
    }
}
