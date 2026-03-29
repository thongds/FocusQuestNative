import SwiftUI

struct AddQuestView: View {
    @Bindable var store: TaskStore
    @State private var isExpanded = true
    @State private var title = ""
    @State private var hoursInput = ""
    @State private var error = ""

    private enum FocusField {
        case task
        case target
    }
    @FocusState private var focusedField: FocusField?

    var body: some View {
        VStack(spacing: 0) {
            // ── Header toggle ─────────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Set Your Next Quest")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .foregroundStyle(isExpanded ? Theme.green : Theme.textFaint)
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Collapsible body ──────────────────────────────────
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter task and the hours you want to finish it in.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)

                    // Input row
                    HStack(spacing: 10) {
                        fieldBlock(label: "TASK",
                                   placeholder: "e.g. Finish chapter 3 notes",
                                   binding: $title,
                                   field: .task)

                        fieldBlock(label: "TARGET (HOURS)",
                                   placeholder: "e.g. 1 or 1.5",
                                   binding: $hoursInput,
                                   field: .target,
                                   width: 160,
                                   onChange: { error = "" })
                    }

                    // Footer
                    HStack {
                        Text(error.isEmpty ? "Mission saves to your serial queue" : error)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(error.isEmpty ? Theme.textFaint.opacity(0.5) : Theme.red)
                        Spacer()
                        Button("Add Quest") { submit() }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(Theme.green)
                            .buttonStyle(.plain)
                    }

                    // History
                    if !store.taskHistory.isEmpty {
                        historySection
                    }
                }
                .padding([.horizontal, .bottom], 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.card)
        .questBorder()
        // When expanding, focus after a short delay so the view is fully in the hierarchy
        .onChange(of: isExpanded) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    focusedField = .task
                }
            } else {
                focusedField = nil
            }
        }
        // Removed onAppear auto-focus — it fights with browser/window focus on click
    }

    @ViewBuilder
    private func fieldBlock(label: String, placeholder: String,
                            binding: Binding<String>, field: FocusField, width: CGFloat? = nil,
                            onChange: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(2)

            TextField(placeholder, text: binding)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text)
                .submitLabel(.done)
                .onSubmit {
                    if field == .task {
                        focusedField = .target
                    } else {
                        submit()
                    }
                }
                // FIX: explicitly re-assert focus on tap so keystrokes don't
                // continue going to whatever had OS-level focus before (e.g. a browser input).
                // The async hop lets the click event fully resolve first.
                .onTapGesture {
                    DispatchQueue.main.async {
                        focusedField = field
                    }
                }
                .frame(minHeight: 18)
        }
        .padding(10)
        .background(Theme.bg)
        .questBorder(Theme.border, width: 1)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : width)
        .onChange(of: binding.wrappedValue) { oldValue, newValue in
            onChange?()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Theme.borderDim)
            Text("RECENT QUESTS — tap to add")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textFaint.opacity(0.5))
                .tracking(2)

            ForEach(store.taskHistory) { item in
                Button {
                    store.addFromHistory(item)
                } label: {
                    HStack(spacing: 8) {
                        Text("↺")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textFaint)
                        Text(item.title)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                        Spacer()
                        if let t = item.targetSeconds {
                            Text(TimeHelpers.formatDuration(t))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.textFaint.opacity(0.6))
                        }
                        Text("+ ADD")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.green)
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Theme.bg)
                    .questBorder(Theme.border, width: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func submit() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var seconds: Int? = nil
        if !hoursInput.isEmpty {
            guard let h = Double(hoursInput), h > 0, h <= 24 else {
                error = "Enter hours like 1 or 1.5"; return
            }
            seconds = TimeHelpers.hoursToSeconds(h)
        }
        store.addTask(title: title.trimmingCharacters(in: .whitespaces), targetSeconds: seconds)
        title = ""
        hoursInput = ""
        error = ""

        // Return focus to the task field for rapid data entry
        DispatchQueue.main.async {
            focusedField = .task
        }
    }
}
