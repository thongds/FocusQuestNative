import SwiftUI

struct ContentView: View {
    @State private var store = TaskStore()
    @State private var isWidgetHovered = false

    var body: some View {
        Group {
            if store.showSettings {
                ScrollView {
                    SettingsView(store: store)
                        .padding(20)
                }
                .frame(minWidth: 520, idealWidth: 580)
                .background(Theme.bg)
            } else if store.isFloating {
                widgetView
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

    // ── Widget mode (compact floating overlay) ────────────────────
    private var widgetView: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Top bar: pin label + exit button
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                    Text((store.activeTasks.first?.title ?? "WIDGET MODE").uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1)
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.cyan)

                Spacer()

                Button {
                    store.isFloating = false
                    store.save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9))
                        Text("EXPAND")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(isWidgetHovered ? Theme.cyan : Theme.textFaint)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.card)
                    .questBorder(Theme.border, width: 1)
                }
                .buttonStyle(.plain)
            }

            // Distraction warning banner
            if store.isDistracted {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("DISTRACTION DETECTED")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(Theme.red)

                    Text(store.distractionURL)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.red.opacity(0.8))
                        .lineLimit(1)

                    Text("Timer paused. Close the tab to resume.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.red.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.red.opacity(0.4), lineWidth: 1))
            }

            if let active = store.activeTasks.first {
                // Progress bar + percentage
                if active.targetSeconds != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Theme.card)
                                    .frame(height: 5)
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [Theme.cyan, Theme.green],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * active.progress, height: 5)
                            }
                        }
                        .frame(height: 5)
                        .questBorder(Theme.border, width: 1)

                        Text("\(Int(active.progress * 100))% complete")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                            .tracking(1)
                    }
                }

                // Countdown + phase label + pause/play
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(active.formattedPomodoroLeft)
                            .font(.system(size: 36, design: .monospaced))
                            .foregroundStyle(active.phase == .focus ? Theme.cyan : Theme.orange)

                        Text(widgetPhaseLabel(for: active))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                            .tracking(2)
                    }

                    Spacer()

                    // Pause / Resume button
                    Button {
                        store.togglePause(active.id)
                    } label: {
                        Image(systemName: active.pomodoroRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .frame(width: 36, height: 36)
                            .background(Theme.cyan)
                            .foregroundStyle(Theme.bg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                }

                // Volume slider (only when sound is enabled)
                if store.settings.soundEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: store.settings.volume < 0.01 ? "speaker.slash.fill"
                                        : store.settings.volume < 0.4  ? "speaker.fill"
                                        :                                 "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 16)

                        Slider(
                            value: Binding(
                                get: { store.settings.volume },
                                set: { newVolume in
                                    store.settings.volume = newVolume
                                    store.save()
                                    AudioPlayer.shared.setVolume(Float(newVolume))
                                }
                            ),
                            in: 0...1
                        )
                        .tint(Theme.cyan)
                        .controlSize(.mini)

                        Text("\(Int(store.settings.volume * 100))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 28, alignment: .trailing)
                    }
                }

            } else {
                // No active task
                VStack(spacing: 6) {
                    Text("🎮")
                        .font(.system(size: 22))
                    Text("NO ACTIVE MISSION")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(minWidth: 260, idealWidth: 300)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            isWidgetHovered = hovering
        }
    }

    private func widgetPhaseLabel(for task: FocusTask) -> String {
        switch task.phase {
        case .focus:      return task.pomodoroRunning ? "COUNTDOWN" : "PAUSED"
        case .shortBreak: return "☕ SHORT BREAK"
        case .longBreak:  return "🛋 LONG BREAK"
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

                // Daily summary
                DailySummaryView(store: store)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // Add quest form
                AddQuestView(store: store)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // Arrange missions by study window
                ArrangeView(store: store)
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
            guard let window = NSApp.windows.first else { return }
            if floating {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                window.isOpaque = false
                window.backgroundColor = .clear
                // Remove titlebar entirely so no grey bar appears
                window.styleMask = [.fullSizeContentView, .resizable]
                window.minSize = NSSize(width: 240, height: 80)
                window.setContentSize(NSSize(width: 300, height: 200))
            } else {
                window.level = .normal
                window.collectionBehavior = [.managed]
                window.isMovableByWindowBackground = false
                window.isOpaque = true
                window.backgroundColor = NSColor(red: 0.027, green: 0.051, blue: 0.102, alpha: 1)
                // Restore titlebar (hidden style the app normally uses)
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.minSize = NSSize(width: 520, height: 400)
                if window.frame.width < 540 {
                    window.setContentSize(NSSize(width: 560, height: 700))
                    window.center()
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
