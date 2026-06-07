//
//  DictionaryView.swift
//  boringNotch
//
//  Japanese dictionary tab backed by Jisho, with one-tap Anki export.
//

import AppKit
import Defaults
import SwiftUI

/// Notch panels are non-key by default; the dictionary needs keyboard focus.
protocol NotchKeyInputWindow: AnyObject {
    var allowsKeyInput: Bool { get set }
}

extension BoringNotchWindow: NotchKeyInputWindow {}
extension BoringNotchSkyLightWindow: NotchKeyInputWindow {}

struct DictionaryView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject private var manager = DictionaryManager.shared
    @FocusState private var searchFocused: Bool
    @State private var notchWindow: NSWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { vm.isHoveringDictionary = $0 }
        .background(WindowAccessor { window in
            guard notchWindow !== window else { return }
            notchWindow = window
            enableKeyInput()
        })
        .onDisappear {
            disableKeyInput()
            vm.isHoveringDictionary = false
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)
            TextField("Search kanji, word or English…", text: $manager.query)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($searchFocused)
                .onSubmit { manager.search() }
            if !manager.query.isEmpty {
                Button {
                    manager.query = ""
                    manager.search()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            if manager.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var content: some View {
        if let error = manager.errorMessage, manager.results.isEmpty {
            centeredMessage(error, icon: "exclamationmark.magnifyingglass")
        } else if manager.results.isEmpty {
            centeredMessage(
                manager.hasSearched ? "No results." : "Type a word and press return.",
                icon: "character.book.closed"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(manager.results) { entry in
                        DictionaryEntryRow(
                            entry: entry,
                            state: manager.ankiState(for: entry)
                        ) {
                            manager.addToAnki(entry)
                        }
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
                .padding(.trailing, 4)
            }
        }
    }

    private func centeredMessage(_ text: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.gray)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func enableKeyInput() {
        guard let window = notchWindow else { return }
        (window as? NotchKeyInputWindow)?.allowsKeyInput = true
        window.makeKey()
        DispatchQueue.main.async { searchFocused = true }
    }

    private func disableKeyInput() {
        (notchWindow as? NotchKeyInputWindow)?.allowsKeyInput = false
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window { onResolve(window) }
        }
    }
}

private struct DictionaryEntryRow: View {
    let entry: JishoEntry
    let state: AnkiAddState
    let onAddToAnki: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                headline
                if !entry.senses.isEmpty {
                    Text(meaningSummary)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            ankiButton
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.primaryWord)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            if let reading = entry.primaryReading {
                Text(reading)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            if entry.isCommon == true {
                badge("common", color: .green)
            }
            ForEach(entry.jlptLevels, id: \.self) { level in
                badge(level, color: .blue)
            }
        }
    }

    private var meaningSummary: String {
        entry.senses
            .prefix(3)
            .map { $0.englishDefinitions.joined(separator: ", ") }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "  ")
    }

    @ViewBuilder
    private var ankiButton: some View {
        switch state {
        case .idle:
            Button(action: onAddToAnki) {
                Label("Anki", systemImage: "plus.rectangle.on.rectangle")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
        case .adding:
            ProgressView().controlSize(.small)
        case .added:
            Label("Added", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .failed(let message):
            Button(action: onAddToAnki) {
                Label("Retry", systemImage: "exclamationmark.arrow.circlepath")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.orange)
            .help(message)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.25))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
