import SwiftUI

struct ContentView: View {
    @State private var store = TaskStore()

    var body: some View {
        Group {
            if store.showSettings {
                ScrollView {
                    SettingsView(store: store)
                        .padding(20)
                }
                .frame(minWidth: 520, idealWidth: 580)
                .background(Theme.bg)
            } else {
                mainView
            }
        }
        .onChange(of: store.isFloating) { _, newValue in
            applyFloating(newValue)
        }
        .onAppear {
            applyFloating(store.isFloating)
        }
    }

    // ── Main layout ───────────────────────────────────────────────
    private var mainView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Add quest form
                AddQuestView(store: store)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // Mission list
                if store.tasks.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    taskList
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 24)
            }
        }
        .frame(minWidth: 520, idealWidth: 580)
        .background(Theme.bg)
    }

    // ── Header ────────────────────────────────────────────────────
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Logo / title
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("⚡")
                        .font(.system(size: 18))
                    Text("FOCUS QUEST")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .tracking(3)
                }
                Text("Pomodoro Task Manager")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            }

            Spacer()

            // Stats chips
            statsChip(label: "ACTIVE", value: "\(store.activeTasks.count)", color: Theme.cyan)
            statsChip(label: "PENDING", value: "\(store.pendingTasks.count)", color: Theme.textFaint)

            Divider()
                .frame(height: 24)
                .overlay(Theme.border)
                .padding(.horizontal, 4)

            // Float toggle
            Button {
                store.isFloating.toggle()
                store.save()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: store.isFloating ? "pin.fill" : "pin.slash")
                        .font(.system(size: 11))
                    Text(store.isFloating ? "FLOATING" : "NORMAL")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(store.isFloating ? Theme.cyan : Theme.textFaint)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(store.isFloating ? Theme.cyanBg : Theme.bg)
                .questBorder(store.isFloating ? Theme.cyan : Theme.border, width: 1)
            }
            .buttonStyle(.plain)

            // Settings button
            Button {
                store.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 32, height: 32)
                    .background(Theme.card)
                    .questBorder(Theme.border, width: 1)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Task list with drag-reorder ───────────────────────────────
    @State private var dragTarget: UUID? = nil

    private var taskList: some View {
        VStack(spacing: 10) {
            ForEach(Array(store.tasks.enumerated()), id: \.element.id) { idx, task in
                MissionCardView(store: store, task: task, index: idx)
                    .opacity(dragTarget == task.id ? 0.4 : 1.0)
                    .onDrag {
                        NSItemProvider(object: task.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TaskDropDelegate(
                        taskId: task.id,
                        store: store,
                        dragTarget: $dragTarget
                    ))
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎮")
                .font(.system(size: 40))
            Text("NO ACTIVE MISSIONS")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(3)
            Text("Add a quest above to begin your focus session.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textFaint.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Stat chip helper ──────────────────────────────────────────
    private func statsChip(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(1)
        }
    }

    // ── Floating window ───────────────────────────────────────────
    private func applyFloating(_ floating: Bool) {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if floating {
                    window.level = .floating
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                } else {
                    window.level = .normal
                    window.collectionBehavior = [.managed]
                }
            }
        }
    }
}

// ── Drag-and-drop delegate ────────────────────────────────────────
struct TaskDropDelegate: DropDelegate {
    let taskId: UUID
    let store: TaskStore
    @Binding var dragTarget: UUID?

    func performDrop(info: DropInfo) -> Bool {
        dragTarget = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        dragTarget = taskId
        guard let sourceStr = info.itemProviders(for: [.text]).first else { return }
        sourceStr.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let idStr = String(data: data, encoding: .utf8),
                  let sourceId = UUID(uuidString: idStr),
                  sourceId != taskId,
                  let fromIdx = store.tasks.firstIndex(where: { $0.id == sourceId }),
                  let toIdx   = store.tasks.firstIndex(where: { $0.id == taskId })
            else { return }
            DispatchQueue.main.async {
                store.moveTask(from: IndexSet(integer: fromIdx), to: toIdx > fromIdx ? toIdx + 1 : toIdx)
            }
        }
    }

    func dropExited(info: DropInfo) {
        if dragTarget == taskId { dragTarget = nil }
    }

    func validateDrop(info: DropInfo) -> Bool { true }
}
