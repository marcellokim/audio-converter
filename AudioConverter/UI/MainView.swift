import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            let layout = MainViewLayout(windowWidth: proxy.size.width)
            let presentation = WorkspacePresentation(appState: appState)
            let contentHeight = max(
                proxy.size.height
                    - (WorkspaceChrome.pagePadding * 2)
                    - WorkspaceChrome.commandBarHeight
                    - WorkspaceChrome.pageSpacing,
                0
            )

            VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
                commandBar(using: presentation)
                    .frame(height: WorkspaceChrome.commandBarHeight)

                studioWorkspace(
                    for: layout,
                    contentHeight: contentHeight,
                    presentation: presentation
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(WorkspaceChrome.pagePadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .background(WorkspaceChrome.windowBackground)
        }
    }

    private func studioWorkspace(
        for layout: MainViewLayout,
        contentHeight: CGFloat,
        presentation: WorkspacePresentation
    ) -> some View {
        let deckWidths = layout.deckColumnWidths
        let stripWidths = layout.operationsStripColumnWidths
        let stripHeight = layout.operationsStripHeight(for: contentHeight)
        let deckHeight = max(contentHeight - stripHeight - WorkspaceChrome.pageSpacing, 0)

        return VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                sourceDeck
                    .frame(width: deckWidths.source, height: deckHeight, alignment: .topLeading)

                controlTower
                    .frame(width: deckWidths.controls, height: deckHeight, alignment: .topLeading)

                launchConsole(using: presentation.action)
                    .frame(width: deckWidths.launch, height: deckHeight, alignment: .topLeading)
            }
            .frame(height: deckHeight, alignment: .topLeading)

            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                queueTelemetrySection
                    .frame(width: stripWidths.queue, height: stripHeight, alignment: .topLeading)

                concurrencySection
                    .frame(width: stripWidths.concurrency, height: stripHeight, alignment: .topLeading)

                batchStatusSection
                    .frame(width: stripWidths.activity, height: stripHeight, alignment: .topLeading)
            }
            .frame(height: stripHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sourceDeck: some View {
        fileSelectionSection
            .accessibilityIdentifier("source-deck")
    }

    private var controlTower: some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CONTROL TOWER")
                        .font(WorkspaceType.caption)
                        .foregroundStyle(.secondary)
                    Text("Output setup")
                        .font(WorkspaceType.sectionTitle)
                }

                Spacer(minLength: 0)

                WorkspaceBadge(title: isMergeMode ? "Merge" : "Batch", tone: isMergeMode ? .accent : .muted)
            }

            operationModeSection

            FormatInputView(
                outputFormat: $appState.outputFormat,
                formats: FormatRegistry.allFormats,
                isEnabled: !appState.isConverting
            )

            outputPolicySection

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private func launchConsole(using action: WorkspacePresentation.Action) -> some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAUNCH CONSOLE")
                    .font(WorkspaceType.caption)
                    .foregroundStyle(.secondary)
                Text(action.title)
                    .font(WorkspaceType.sectionTitle)
                Text(action.message)
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            exportReadinessCard(using: action)

            primaryActionSection(using: action)

            launchProgressSection

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .workspaceSurface(tone: action.canStartPrimaryAction ? .accent : .standard, padding: 12)
    }

    private var fileSelectionSection: some View {
        FileSelectionView(
            files: appState.selectedAudioFiles,
            action: handleSelectFiles,
            onRemove: handleRemoveSelectedFile,
            onClearAll: handleClearAllFiles,
            onMoveUp: handleMoveSelectedFileUp,
            onMoveDown: handleMoveSelectedFileDown,
            canBrowseFiles: appState.canOpenFiles,
            canRemoveFiles: appState.canRemoveSelectedFiles,
            canReorderFiles: appState.canReorderSelectedFiles,
            isMergeMode: isMergeMode
        )
    }

    private var batchStatusSection: some View {
        BatchStatusListView(snapshots: appState.batchSnapshots)
    }

    private var outputPolicySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label(isMergeMode ? "Destination" : "Output", systemImage: isMergeMode ? "folder" : "tray.and.arrow.down")
                    .font(WorkspaceType.bodyStrong)

                Spacer(minLength: 0)

                if isMergeMode {
                    Button("Choose", action: handleSelectMergeDestination)
                        .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
                        .disabled(!appState.canChooseMergeDestination)
                        .accessibilityIdentifier("select-merge-destination")
                } else {
                    WorkspaceBadge(title: "Beside source", tone: .muted)
                }
            }

            if isMergeMode {
                if let mergeDestinationURL = appState.mergeDestinationURL {
                    Label(mergeDestinationURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                        .font(WorkspaceType.detail)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .workspaceInsetSurface(tone: .success, padding: 9)
                        .accessibilityIdentifier("merge-destination-name")
                } else {
                    Text("No destination selected.")
                        .font(WorkspaceType.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .workspaceInsetSurface(tone: .muted, padding: 9)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Originals stay intact", systemImage: "checkmark.circle.fill")
                    Label("Outputs render beside sources", systemImage: "checkmark.circle.fill")
                }
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .workspaceInsetSurface(tone: .muted, padding: 8)
            }
        }
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private var queueTelemetrySection: some View {
        let snapshot = appState.queueDashboardSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            WorkspaceSectionHeader(
                eyebrow: nil,
                title: "Queue",
                message: queueManagerMessage(for: snapshot)
            )

            HStack(spacing: 8) {
                metricTile(
                    title: "Total",
                    value: "\(snapshot.totalTrackedCount)",
                    icon: "doc",
                    color: .accentColor,
                    identifier: "queue-total-count"
                )
                metricTile(
                    title: "Running",
                    value: "\(snapshot.runningCount)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    identifier: "queue-running-count"
                )
            }

            HStack(spacing: 8) {
                metricTile(
                    title: "Done",
                    value: "\(snapshot.terminalCount)",
                    icon: "checkmark.circle",
                    color: .green,
                    identifier: "queue-finished-count"
                )
                metricTile(
                    title: "Queued",
                    value: "\(snapshot.queuedCount)",
                    icon: "clock",
                    color: .secondary,
                    identifier: "queue-queued-count"
                )
            }

            if snapshot.totalTrackedCount > 0 {
                WorkspaceLinearProgress(
                    value: Double(snapshot.terminalCount),
                    total: Double(max(snapshot.totalTrackedCount, 1)),
                    color: .accentColor
                )
                .accessibilityIdentifier("queue-progress")
            }
        }
        .workspaceSurface(tone: .standard, padding: 12)
        .accessibilityIdentifier("queue-manager")
    }

    private var concurrencySection: some View {
        let snapshot = appState.queueDashboardSnapshot

        return VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 6) {
                Text("Concurrency")
                    .font(WorkspaceType.sectionTitle)
                Image(systemName: "info.circle")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                if !isMergeMode {
                    Button {
                        appState.updateManualConcurrentJobLimit(appState.manualConcurrentJobLimit - 1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                    .disabled(
                        appState.schedulerSettings.usesAutomaticConcurrency
                            || appState.isConverting
                            || appState.manualConcurrentJobLimit <= QueueSchedulerSettings.minimumConcurrentJobLimit
                    )
                }

                Text("\(snapshot.effectiveConcurrentJobLimit)")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("queue-active-slots")

                if !isMergeMode {
                    Button {
                        appState.updateManualConcurrentJobLimit(appState.manualConcurrentJobLimit + 1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                    .disabled(
                        appState.schedulerSettings.usesAutomaticConcurrency
                            || appState.isConverting
                            || appState.manualConcurrentJobLimit >= QueueSchedulerSettings.maximumConcurrentJobLimit
                    )
                }
            }

            Text(isMergeMode ? "Ordered merge slot" : (snapshot.usesAutomaticConcurrency ? "Auto jobs" : "Manual jobs"))
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("queue-scheduler-mode")

            if !isMergeMode {
                Button {
                    appState.setAutomaticSchedulingEnabled(!appState.schedulerSettings.usesAutomaticConcurrency)
                } label: {
                    Label("Auto", systemImage: snapshot.usesAutomaticConcurrency ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    WorkspaceCommandButtonStyle(
                        tone: snapshot.usesAutomaticConcurrency ? .accent : .muted,
                        isProminent: snapshot.usesAutomaticConcurrency
                    )
                )
                .disabled(appState.isConverting)
                .accessibilityIdentifier("queue-auto-scheduler")
            }

            Spacer(minLength: 0)
        }
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private var launchProgressSection: some View {
        let snapshot = appState.queueDashboardSnapshot
        let total = max(snapshot.totalTrackedCount, 1)
        let progress = Double(snapshot.terminalCount) / Double(total)

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Overall Progress")
                    .font(WorkspaceType.bodyStrong)
                Spacer(minLength: 0)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(Color.accentColor)
            }

            WorkspaceLinearProgress(
                value: Double(snapshot.terminalCount),
                total: Double(total),
                color: .accentColor
            )

            HStack {
                Text("\(snapshot.terminalCount) / \(snapshot.totalTrackedCount) files")
                Spacer(minLength: 0)
                Text(appState.isConverting ? "running" : "idle")
            }
            .font(WorkspaceType.metric)
            .foregroundStyle(.secondary)
        }
        .workspaceInsetSurface(tone: .muted, padding: 10)
    }

    private func metricTile(
        title: String,
        value: String,
        icon: String,
        color: Color,
        identifier: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(WorkspaceType.sectionTitle)
                    .monospacedDigit()
                    .accessibilityIdentifier(identifier)
                Text(title)
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .workspaceInsetSurface(tone: .muted, padding: 9)
    }

    @ViewBuilder
    private func schedulerControlSection(for snapshot: QueueDashboardSnapshot) -> some View {
        if isMergeMode {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "lock")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)

                Text("One ordered merge slot")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("queue-scheduler-mode")

                Spacer(minLength: 0)

                Text("\(snapshot.effectiveConcurrentJobLimit)")
                    .font(WorkspaceType.metric)
                    .monospacedDigit()
                    .accessibilityIdentifier("queue-active-slots")
            }
            .workspaceInsetSurface(tone: .standard, padding: 8)
        } else {
            HStack(alignment: .center, spacing: 12) {
                schedulerControls(snapshot: snapshot)
            }
            .workspaceInsetSurface(tone: .standard, padding: 8)
        }
    }

    private func schedulerControls(snapshot: QueueDashboardSnapshot) -> some View {
        Group {
            Button {
                appState.setAutomaticSchedulingEnabled(!appState.schedulerSettings.usesAutomaticConcurrency)
            } label: {
                Label(
                    "Auto",
                    systemImage: snapshot.usesAutomaticConcurrency ? "checkmark.circle.fill" : "circle"
                )
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(
                WorkspaceCommandButtonStyle(
                    tone: snapshot.usesAutomaticConcurrency ? .accent : .muted,
                    isProminent: snapshot.usesAutomaticConcurrency
                )
            )
            .disabled(appState.isConverting)
            .accessibilityIdentifier("queue-auto-scheduler")

            HStack(spacing: 6) {
                Button {
                    appState.updateManualConcurrentJobLimit(appState.manualConcurrentJobLimit - 1)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                .disabled(
                    appState.schedulerSettings.usesAutomaticConcurrency
                        || appState.isConverting
                        || appState.manualConcurrentJobLimit <= QueueSchedulerSettings.minimumConcurrentJobLimit
                )

                Text("Slots \(appState.manualConcurrentJobLimit)")
                    .font(WorkspaceType.metric)
                    .monospacedDigit()

                Button {
                    appState.updateManualConcurrentJobLimit(appState.manualConcurrentJobLimit + 1)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                .disabled(
                    appState.schedulerSettings.usesAutomaticConcurrency
                        || appState.isConverting
                        || appState.manualConcurrentJobLimit >= QueueSchedulerSettings.maximumConcurrentJobLimit
                )
            }
            .foregroundStyle(appState.schedulerSettings.usesAutomaticConcurrency ? .secondary : .primary)
            .accessibilityIdentifier("queue-manual-slots")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(snapshot.usesAutomaticConcurrency ? "CPU" : "Manual")
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("queue-scheduler-mode")

                Text("\(snapshot.effectiveConcurrentJobLimit)")
                    .font(WorkspaceType.metric)
                    .monospacedDigit()
                    .foregroundStyle(appState.isConverting ? Color.accentColor : .secondary)
                    .accessibilityIdentifier("queue-active-slots")
            }
        }
    }

    @ViewBuilder
    private func queueStatusPills(for snapshot: QueueDashboardSnapshot) -> some View {
        queueStatusPill(
            title: "staged",
            value: snapshot.totalTrackedCount,
            color: .secondary,
            identifier: "queue-total-count"
        )
        queueStatusPill(
            title: "queued",
            value: snapshot.queuedCount,
            color: .secondary,
            identifier: "queue-queued-count"
        )
        queueStatusPill(
            title: "running",
            value: snapshot.runningCount,
            color: .orange,
            identifier: "queue-running-count"
        )
        queueStatusPill(
            title: "done",
            value: snapshot.terminalCount,
            color: .green,
            identifier: "queue-finished-count"
        )
    }

    private func queueStatusPill(
        title: String,
        value: Int,
        color: Color,
        identifier: String
    ) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .monospacedDigit()
                .accessibilityIdentifier(identifier)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .font(WorkspaceType.metric)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }

    private func queueManagerMessage(for snapshot: QueueDashboardSnapshot) -> String {
        if isMergeMode {
            return snapshot.totalTrackedCount == 0 ? "waiting for files" : "ordered export"
        }

        if appState.isConverting {
            return "\(snapshot.runningCount) running / \(snapshot.queuedCount) queued"
        }

        if snapshot.usesAutomaticConcurrency {
            return "auto slots"
        }

        return "manual \(snapshot.effectiveConcurrentJobLimit) slots"
    }

    private func secondaryLane(using presentation: WorkspacePresentation) -> some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            operationModeSection

            FormatInputView(
                outputFormat: $appState.outputFormat,
                formats: FormatRegistry.allFormats,
                isEnabled: !appState.isConverting
            )

            if isMergeMode {
                mergeDestinationSection
            }

            Spacer(minLength: 0)

            primaryActionSection(using: presentation.action)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func topBar(using presentation: WorkspacePresentation) -> some View {
        HStack(alignment: .center, spacing: WorkspaceChrome.pageSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AudioConverter")
                        .font(WorkspaceType.display)

                    Text(isMergeMode ? "Ordered merge workspace" : "Batch conversion workspace")
                        .font(WorkspaceType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                WorkspaceBadge(
                    title: presentation.headerBadge.title,
                    tone: presentation.headerBadge.tone
                )
            }
            .frame(minWidth: 280, alignment: .leading)

            StatusBannerView(
                title: presentation.banner.title,
                message: presentation.banner.message,
                tone: presentation.banner.tone
            )
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commandBar(using presentation: WorkspacePresentation) -> some View {
        ZStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red.opacity(0.92))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.yellow.opacity(0.92))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green.opacity(0.92))
                    .frame(width: 12, height: 12)

                Text("AudioConverter")
                    .font(WorkspaceType.display)
                    .lineLimit(1)

                Spacer(minLength: 0)

                StatusBannerView(
                    title: presentation.banner.title,
                    message: presentation.banner.message,
                    tone: presentation.banner.tone
                )
                .frame(width: 330)

                Button {
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(WorkspaceIconButtonStyle(tone: .muted))
                .disabled(true)
            }

            HStack(spacing: 0) {
                modeButton(
                    title: "Batch",
                    mode: .batchConvert,
                    identifier: "mode-batch"
                )
                .frame(width: 96)

                modeButton(
                    title: "Merge",
                    mode: .mergeIntoOne,
                    identifier: "mode-merge"
                )
                .frame(width: 96)
            }
            .padding(4)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.09), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: WorkspaceChrome.surfaceRadius, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkspaceChrome.surfaceRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var operationModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("Workflow", systemImage: "slider.horizontal.3")
                    .font(WorkspaceType.bodyStrong)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                WorkspaceBadge(
                    title: isMergeMode ? "Merge" : "Batch",
                    tone: isMergeMode ? .accent : .muted
                )
            }

            Text(isMergeMode ? "One ordered export with a single destination." : "Separate output per source file.")
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private var mergeDestinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label("Destination", systemImage: "folder")
                    .font(WorkspaceType.bodyStrong)

                Spacer(minLength: 0)

                Button("Choose", action: handleSelectMergeDestination)
                    .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
                    .disabled(!appState.canChooseMergeDestination)
                    .accessibilityIdentifier("select-merge-destination")
            }

            if let mergeDestinationURL = appState.mergeDestinationURL {
                Text(mergeDestinationURL.lastPathComponent)
                    .font(WorkspaceType.bodyStrong)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("merge-destination-name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .workspaceInsetSurface(tone: .muted, padding: 10)
            } else {
                Text("No destination selected.")
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .workspaceInsetSurface(tone: .muted, padding: 10)
            }
        }
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private func primaryActionSection(using action: WorkspacePresentation.Action) -> some View {
        let guidance = action.guidance

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.eyebrow.uppercased())
                    .font(WorkspaceType.caption)
                    .foregroundStyle(.secondary)
                Text(action.title)
                    .font(WorkspaceType.sectionTitle)
                    .lineLimit(1)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    actionButtons(using: action)
                }

                VStack(spacing: 8) {
                    actionButtons(using: action)
                }
            }

            statusCallout(
                title: guidance.title,
                message: guidance.message,
                tone: guidance.tone,
                identifier: guidance.identifier
            )
        }
        .workspaceSurface(tone: .standard, padding: 12)
    }

    private func exportReadinessCard(using action: WorkspacePresentation.Action) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("Ready checks", systemImage: "checklist")
                    .font(WorkspaceType.bodyStrong)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                WorkspaceBadge(
                    title: action.canStartPrimaryAction ? "Ready" : "Waiting",
                    tone: action.canStartPrimaryAction ? .success : .muted
                )
            }

            VStack(spacing: 7) {
                ForEach(exportReadinessRows) { row in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: row.isReady ? "checkmark.circle.fill" : "circle")
                            .font(WorkspaceType.metric)
                            .foregroundStyle(row.isReady ? Color.green : .secondary)
                            .frame(width: 14)

                        Text(row.title)
                            .font(WorkspaceType.metric)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Text(row.value)
                            .font(WorkspaceType.metric)
                            .foregroundStyle(row.isReady ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .workspaceSurface(tone: action.canStartPrimaryAction ? .success : .muted, padding: 12)
    }

    private var exportReadinessRows: [ExportReadinessRow] {
        var rows = [
            ExportReadinessRow(
                title: "Files",
                value: appState.selectedAudioFiles.isEmpty ? "None" : "\(appState.selectedAudioFiles.count)",
                isReady: isMergeMode ? appState.selectedAudioFiles.count >= 2 : !appState.selectedAudioFiles.isEmpty
            ),
            ExportReadinessRow(
                title: "Format",
                value: selectedFormatReadinessValue,
                isReady: selectedFormatReadinessIsReady
            )
        ]

        if isMergeMode {
            rows.append(
                ExportReadinessRow(
                    title: "Destination",
                    value: appState.mergeDestinationURL?.lastPathComponent ?? "None",
                    isReady: appState.mergeDestinationURL != nil
                )
            )
        }

        return rows
    }

    private var selectedFormatReadinessValue: String {
        switch appState.formatValidationState {
        case .idle:
            return "Missing"
        case let .valid(format):
            return format.outputExtension.uppercased()
        case let .invalidFormat(rawInput):
            let normalized = FormatRegistry.normalizedKey(for: rawInput)
            return normalized.isEmpty ? "Missing" : normalized.uppercased()
        }
    }

    private var selectedFormatReadinessIsReady: Bool {
        if case .valid = appState.formatValidationState {
            return true
        }

        return false
    }

    private func statusCallout(
        title: String,
        message: String,
        tone: WorkspaceSurfaceTone,
        identifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(WorkspaceType.caption)
                .foregroundStyle(.secondary)
            Text(message)
                .font(WorkspaceType.detail)
                .foregroundStyle(tone == .warning ? Color.orange : .secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .applyAccessibilityIdentifier(identifier)
        }
        .workspaceInsetSurface(tone: tone, padding: 10)
    }

    @ViewBuilder
    private func actionButtons(using action: WorkspacePresentation.Action) -> some View {
        Button(action: handleStartPrimaryAction) {
            Text(action.primaryButtonTitle)
                .frame(maxWidth: .infinity)
        }
            .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
            .disabled(!action.canStartPrimaryAction)
            .accessibilityIdentifier(action.primaryButtonIdentifier)

        if action.showsCancelButton {
            Button(action: handleCancelConversion) {
                Text(action.cancelButtonTitle)
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(WorkspaceCommandButtonStyle(tone: .warning, isProminent: false))
                .disabled(!action.canCancel)
                .accessibilityIdentifier(action.cancelButtonIdentifier)
        }

        if action.showsRetryStartupButton {
            Button(action: handleRetryStartupChecks) {
                Text("Retry Startup Check")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(WorkspaceCommandButtonStyle(tone: .warning, isProminent: false))
                .accessibilityIdentifier("retry-startup-check")
        }
    }

    private func modeButton(
        title: String,
        mode: AppState.OperationMode,
        identifier: String
    ) -> some View {
        Group {
            if mode == appState.operationMode {
                Button(title) {
                    appState.operationMode = mode
                }
                .buttonStyle(WorkspaceCommandButtonStyle(tone: .accent, isProminent: true))
                .accessibilityIdentifier(identifier)
            } else {
                Button(title) {
                    appState.operationMode = mode
                }
                .buttonStyle(WorkspaceCommandButtonStyle(tone: .muted, isProminent: false))
                .accessibilityIdentifier(identifier)
            }
        }
        .disabled(appState.isConverting)
    }

    private var isMergeMode: Bool {
        appState.operationMode == .mergeIntoOne
    }

    private func handleSelectFiles() {
        appState.selectFiles()
    }

    private func handleSelectMergeDestination() {
        appState.selectMergeDestination()
    }

    private func handleStartPrimaryAction() {
        appState.startPrimaryAction()
    }

    private func handleRemoveSelectedFile(_ file: SelectedAudioFile) {
        appState.removeSelectedFile(file)
    }

    private func handleClearAllFiles() {
        appState.clearAllFiles()
    }

    private func handleMoveSelectedFileUp(_ file: SelectedAudioFile) {
        appState.moveSelectedFileUp(file)
    }

    private func handleMoveSelectedFileDown(_ file: SelectedAudioFile) {
        appState.moveSelectedFileDown(file)
    }

    private func handleCancelConversion() {
        appState.cancelConversion()
    }

    private func handleRetryStartupChecks() {
        appState.retryStartupChecks()
    }
}

private struct ExportReadinessRow: Identifiable {
    let title: String
    let value: String
    let isReady: Bool

    var id: String {
        title
    }
}

private struct WorkspacePresentation {
    struct Banner {
        let title: String
        let message: String
        let tone: StatusBannerView.Tone
    }

    struct HeaderBadge {
        let title: String
        let tone: WorkspaceSurfaceTone
    }

    struct Guidance {
        let title: String
        let message: String
        let tone: WorkspaceSurfaceTone
        let identifier: String?
    }

    struct Action {
        let eyebrow: String
        let title: String
        let message: String
        let primaryButtonTitle: String
        let primaryButtonIdentifier: String
        let canStartPrimaryAction: Bool
        let cancelButtonTitle: String
        let cancelButtonIdentifier: String
        let showsCancelButton: Bool
        let canCancel: Bool
        let showsRetryStartupButton: Bool
        let guidance: Guidance
    }

    let banner: Banner
    let headerBadge: HeaderBadge
    let action: Action

    init(appState: AppState) {
        let isMergeMode = appState.operationMode == .mergeIntoOne
        let selectedFormat = Self.selectedFormat(from: appState.formatValidationState)
        let supportedFormatsList = FormatRegistry.allFormats.map(\.id).joined(separator: ", ")
        let canStartPrimaryAction = isMergeMode ? appState.canStartMerge : appState.canStartConversion
        let primaryButtonTitle = isMergeMode ? "Start Merge" : "Start Conversion"
        let primaryButtonIdentifier = isMergeMode ? "start-merge" : "start-conversion"
        let cancelButtonIdentifier = isMergeMode ? "cancel-merge" : "cancel-conversion"

        headerBadge = HeaderBadge(
            title: appState.isConverting
                ? "Running"
                : (isMergeMode ? "Merge" : "Batch"),
            tone: appState.isConverting ? .accent : .muted
        )

        banner = Self.makeBanner(
            appState: appState,
            isMergeMode: isMergeMode,
            selectedFormat: selectedFormat,
            supportedFormatsList: supportedFormatsList
        )

        action = Self.makeAction(
            appState: appState,
            isMergeMode: isMergeMode,
            selectedFormat: selectedFormat,
            supportedFormatsList: supportedFormatsList,
            canStartPrimaryAction: canStartPrimaryAction,
            primaryButtonTitle: primaryButtonTitle,
            primaryButtonIdentifier: primaryButtonIdentifier,
            cancelButtonIdentifier: cancelButtonIdentifier
        )
    }

    private static func selectedFormat(from validationState: ValidationState) -> SupportedFormat? {
        guard case let .valid(format) = validationState else {
            return nil
        }

        return format
    }

    private static func makeBanner(
        appState: AppState,
        isMergeMode: Bool,
        selectedFormat: SupportedFormat?,
        supportedFormatsList: String
    ) -> Banner {
        let tone: StatusBannerView.Tone
        switch appState.startupState {
        case .idle, .checking:
            tone = .checking
        case .startupError:
            tone = .blocked
        case .ready:
            tone = appState.isConverting ? .active : .ready
        }

        let title: String
        switch appState.startupState {
        case .idle:
            title = "Preparing launch"
        case .checking:
            title = "Checking bundled ffmpeg"
        case .startupError:
            title = "Startup blocked"
        case .ready:
            if appState.isConverting {
                if isMergeMode {
                    title = appState.isCancelling ? "Cancelling merge" : "Merging ordered audio"
                } else {
                    title = appState.isCancelling ? "Cancelling batch" : "Converting batch"
                }
            } else if let selectedFormat {
                if isMergeMode {
                    title = appState.selectedAudioFiles.count < 2
                        ? "Stage files for ordered merge"
                        : "Merge into one \(selectedFormat.displayName)"
                } else if appState.selectedAudioFiles.isEmpty {
                    title = "Ready for source files"
                } else {
                    title = "Prepared for \(selectedFormat.displayName)"
                }
            } else {
                title = "Choose a supported format"
            }
        }

        let message: String
        switch appState.startupState {
        case .idle, .checking:
            message = "AudioConverter is validating the bundled ffmpeg runtime before file selection and export become available."
        case let .startupError(errorMessage):
            message = errorMessage
        case .ready:
            if appState.isConverting, let selectedFormat {
                let verb = isMergeMode ? "Merging" : "Rendering"
                message = "\(verb) \(appState.selectedAudioFiles.count) file(s) to \(selectedFormat.displayName). \(appState.statusMessage)"
            } else if let selectedFormat {
                if isMergeMode {
                    if appState.selectedAudioFiles.isEmpty {
                        message = "Stage files, set their order, choose a destination, and merge into one \(selectedFormat.displayName) export."
                    } else {
                        message = "\(appState.selectedAudioFiles.count) ordered file(s) are staged for one \(selectedFormat.displayName) export. \(appState.statusMessage)"
                    }
                } else if appState.selectedAudioFiles.isEmpty {
                    message = "The workspace is ready and waiting for files to render as \(selectedFormat.displayName)."
                } else {
                    message = "\(appState.selectedAudioFiles.count) file(s) are staged for \(selectedFormat.displayName). \(appState.statusMessage)"
                }
            } else {
                message = "Supported formats come from the built-in registry: \(supportedFormatsList)."
            }
        }

        return Banner(title: title, message: message, tone: tone)
    }

    private static func makeAction(
        appState: AppState,
        isMergeMode: Bool,
        selectedFormat: SupportedFormat?,
        supportedFormatsList: String,
        canStartPrimaryAction: Bool,
        primaryButtonTitle: String,
        primaryButtonIdentifier: String,
        cancelButtonIdentifier: String
    ) -> Action {
        Action(
            eyebrow: isMergeMode ? "Merge export" : "Batch export",
            title: isMergeMode ? "Run merge" : "Run batch",
            message: isMergeMode
                ? "Starts once files and destination are ready."
                : "Starts once files and format are ready.",
            primaryButtonTitle: primaryButtonTitle,
            primaryButtonIdentifier: primaryButtonIdentifier,
            canStartPrimaryAction: canStartPrimaryAction,
            cancelButtonTitle: cancelButtonTitle(for: appState, isMergeMode: isMergeMode),
            cancelButtonIdentifier: cancelButtonIdentifier,
            showsCancelButton: appState.isConverting,
            canCancel: appState.canCancelConversion,
            showsRetryStartupButton: appState.canRetryStartupChecks,
            guidance: prioritizedGuidance(
                appState: appState,
                isMergeMode: isMergeMode,
                selectedFormat: selectedFormat,
                supportedFormatsList: supportedFormatsList,
                canStartPrimaryAction: canStartPrimaryAction
            )
        )
    }

    private static func cancelButtonTitle(for appState: AppState, isMergeMode: Bool) -> String {
        if isMergeMode {
            return appState.isCancelling ? "Cancelling Merge…" : "Cancel Merge"
        }

        return appState.isCancelling ? "Cancelling Batch…" : "Cancel Batch"
    }

    private static func prioritizedGuidance(
        appState: AppState,
        isMergeMode: Bool,
        selectedFormat: SupportedFormat?,
        supportedFormatsList: String,
        canStartPrimaryAction: Bool
    ) -> Guidance {
        if case let .invalidFormat(rawInput) = appState.formatValidationState {
            return Guidance(
                title: "Format check",
                message: invalidFormatMessage(for: rawInput, supportedFormatsList: supportedFormatsList),
                tone: .warning,
                identifier: nil
            )
        }

        if appState.isConverting {
            return Guidance(
                title: "Live status",
                message: appState.statusMessage,
                tone: .accent,
                identifier: "status-message"
            )
        }

        if let statusFeedback = statusFeedback(
            appState: appState,
            supportedFormatsList: supportedFormatsList
        ) {
            return statusFeedback
        }

        let readinessMessage = readinessMessage(
            appState: appState,
            isMergeMode: isMergeMode,
            selectedFormat: selectedFormat,
            supportedFormatsList: supportedFormatsList
        )

        if canStartPrimaryAction {
            return Guidance(
                title: "Ready to go",
                message: readinessMessage,
                tone: .success,
                identifier: "status-message"
            )
        }

        return Guidance(
            title: "Next step",
            message: readinessMessage,
            tone: .muted,
            identifier: "status-message"
        )
    }

    private static func statusFeedback(
        appState: AppState,
        supportedFormatsList: String
    ) -> Guidance? {
        let baselineMessage = AppStateStatusPolicy.currentInputMessage(
            startupState: appState.startupState,
            operationMode: appState.operationMode,
            selectedFileCount: appState.selectedFiles.count,
            validationState: appState.formatValidationState,
            mergeDestinationURL: appState.mergeDestinationURL,
            supportedFormatSummary: supportedFormatsList
        )

        guard appState.statusMessage != baselineMessage else {
            return nil
        }

        let loweredStatus = appState.statusMessage.lowercased()
        let tone: WorkspaceSurfaceTone

        if loweredStatus.contains("cancel") {
            tone = .warning
        } else if loweredStatus.contains("finished") || loweredStatus.contains("loaded") {
            tone = .success
        } else {
            tone = .accent
        }

        return Guidance(
            title: "Recent update",
            message: appState.statusMessage,
            tone: tone,
            identifier: "status-message"
        )
    }

    private static func readinessMessage(
        appState: AppState,
        isMergeMode: Bool,
        selectedFormat: SupportedFormat?,
        supportedFormatsList: String
    ) -> String {
        switch appState.startupState {
        case .idle, .checking:
            return "Wait for the startup self-check to finish."
        case .startupError:
            return "Retry the startup self-check to continue."
        case .ready:
            if appState.isCancelling {
                return isMergeMode
                    ? "Cancellation is in progress. Controls will re-enable when the merge finishes."
                    : "Cancellation is in progress. Controls will re-enable when the batch finishes."
            }

            if appState.isConverting {
                return isMergeMode
                    ? "Merge is running. Controls will re-enable when the export completes."
                    : "Conversion is running. Controls will re-enable when the batch completes."
            }

            if appState.selectedAudioFiles.isEmpty {
                return isMergeMode
                    ? "Choose two or more source files to enable ordered merge."
                    : "Choose files to enable conversion."
            }

            guard let selectedFormat else {
                return "Enter a supported format such as \(supportedFormatsList)."
            }

            if isMergeMode {
                if appState.selectedAudioFiles.count < 2 {
                    return "Add at least one more source file to enable ordered merge."
                }

                if appState.mergeDestinationURL == nil {
                    return "Choose a destination for the merged \(selectedFormat.displayName) file."
                }

                return "The ordered merge will export one \(selectedFormat.outputExtension.uppercased()) file."
            }

            return "Conversion will render beside the source files as \(selectedFormat.outputExtension.uppercased())."
        }
    }

    private static func invalidFormatMessage(for rawInput: String, supportedFormatsList: String) -> String {
        let candidate = FormatRegistry.normalizedKey(for: rawInput)
        let token = candidate.isEmpty ? "That format" : "\"\(candidate)\""
        return "\(token) is not in the registry yet. Try \(supportedFormatsList)."
    }
}

struct MainViewLayout: Equatable {
    static let studioBreakpoint: CGFloat = 860

    let windowWidth: CGFloat
    let availableWidth: CGFloat

    init(windowWidth: CGFloat) {
        self.windowWidth = windowWidth
        self.availableWidth = max(windowWidth - (WorkspaceChrome.pagePadding * 2), 0)
    }

    var prefersTwoColumn: Bool {
        prefersStudioDeck
    }

    var prefersBalancedGrid: Bool {
        prefersStudioDeck
    }

    var prefersStudioDeck: Bool {
        availableWidth >= Self.studioBreakpoint
    }

    var balancedColumnWidths: (source: CGFloat, controls: CGFloat, export: CGFloat) {
        let widths = deckColumnWidths
        return (widths.source, widths.controls, widths.launch)
    }

    var deckColumnWidths: (source: CGFloat, controls: CGFloat, launch: CGFloat) {
        let contentWidth = max(availableWidth - (WorkspaceChrome.pageSpacing * 2), 0)
        guard prefersStudioDeck else {
            let controls = max(contentWidth * 0.30, 190)
            let launch = max(contentWidth * 0.31, 200)
            let source = max(contentWidth - controls - launch, 250)

            return (source, controls, launch)
        }

        let controls = min(max(contentWidth * 0.29, 268), 302)
        let launch = min(max(contentWidth * 0.31, 286), 322)
        let source = max(contentWidth - controls - launch, 320)

        return (source, controls, launch)
    }

    var operationsStripColumnWidths: (queue: CGFloat, concurrency: CGFloat, activity: CGFloat) {
        let contentWidth = max(availableWidth - (WorkspaceChrome.pageSpacing * 2), 0)
        guard prefersStudioDeck else {
            let queue = max(contentWidth * 0.38, 250)
            let concurrency = max(contentWidth * 0.21, 150)
            let activity = max(contentWidth - queue - concurrency, 240)

            return (queue, concurrency, activity)
        }

        let queue = min(max(contentWidth * 0.38, 300), 378)
        let concurrency = min(max(contentWidth * 0.20, 178), 220)
        let activity = max(contentWidth - queue - concurrency, 300)

        return (queue, concurrency, activity)
    }

    func monitorRowHeight(for contentHeight: CGFloat) -> CGFloat {
        operationsStripHeight(for: contentHeight)
    }

    func operationsStripHeight(for contentHeight: CGFloat) -> CGFloat {
        min(max(contentHeight * 0.29, 188), 204)
    }

    var secondaryColumnWidth: CGFloat {
        min(max(availableWidth * 0.35, 260), 318)
    }
}

enum WorkspaceChrome {
    static let pagePadding: CGFloat = 12
    static let pageSpacing: CGFloat = 10
    static let commandBarHeight: CGFloat = 62
    static let topBarHeight: CGFloat = commandBarHeight
    static let surfacePadding: CGFloat = 12
    static let insetPadding: CGFloat = 9
    static let surfaceRadius: CGFloat = 8
    static let insetRadius: CGFloat = 6

    static var windowBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.84),
                    Color(red: 0.05, green: 0.06, blue: 0.065).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

enum WorkspaceType {
    static let display = Font.system(size: 23, weight: .semibold)
    static let sectionTitle = Font.system(size: 16, weight: .semibold)
    static let bodyStrong = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let detail = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .semibold)
    static let metric = Font.system(size: 11, weight: .medium, design: .monospaced)
}

enum WorkspaceSurfaceTone {
    case standard
    case accent
    case muted
    case warning
    case critical
    case success

    var fillColor: Color {
        switch self {
        case .standard:
            return Color.primary.opacity(0.055)
        case .accent:
            return Color.accentColor.opacity(0.095)
        case .muted:
            return Color.primary.opacity(0.035)
        case .warning:
            return Color.orange.opacity(0.095)
        case .critical:
            return Color.red.opacity(0.10)
        case .success:
            return Color.green.opacity(0.09)
        }
    }

    var strokeColor: Color {
        switch self {
        case .standard:
            return Color.primary.opacity(0.10)
        case .accent:
            return Color.accentColor.opacity(0.26)
        case .muted:
            return Color.primary.opacity(0.07)
        case .warning:
            return Color.orange.opacity(0.22)
        case .critical:
            return Color.red.opacity(0.24)
        case .success:
            return Color.green.opacity(0.24)
        }
    }
}

struct WorkspaceSectionHeader: View {
    let eyebrow: String?
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(WorkspaceType.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(WorkspaceType.sectionTitle)

            Text(message)
                .font(WorkspaceType.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }
}

struct WorkspaceBadge: View {
    let title: String
    let tone: WorkspaceSurfaceTone

    var body: some View {
        Text(title)
            .font(WorkspaceType.caption)
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.fillColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tone.strokeColor, lineWidth: 1)
            )
    }

    private var textColor: Color {
        switch tone {
        case .warning:
            return .orange
        case .critical:
            return .red
        case .accent:
            return .accentColor
        case .success:
            return .green
        case .standard, .muted:
            return .secondary
        }
    }
}

struct WorkspaceCommandButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let tone: WorkspaceSurfaceTone
    let isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkspaceType.metric)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(minHeight: 28)
            .background(backgroundColor(configuration: configuration), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(strokeColor, lineWidth: isProminent ? 0 : 1)
            )
            .opacity(isEnabled ? 1 : 0.46)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return .secondary
        }

        if isProminent {
            return .white
        }

        switch tone {
        case .accent:
            return .accentColor
        case .warning:
            return .orange
        case .critical:
            return .red
        case .success:
            return .green
        case .standard, .muted:
            return .primary
        }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if !isEnabled {
            return Color.primary.opacity(0.06)
        }

        let base: Color
        switch tone {
        case .accent:
            base = .accentColor
        case .warning:
            base = .orange
        case .critical:
            base = .red
        case .success:
            base = .green
        case .standard, .muted:
            base = .primary
        }

        if isProminent {
            return base.opacity(configuration.isPressed ? 0.82 : 0.92)
        }

        return base.opacity(configuration.isPressed ? 0.16 : 0.08)
    }

    private var strokeColor: Color {
        if !isEnabled {
            return Color.primary.opacity(0.10)
        }

        return tone.strokeColor
    }
}

struct WorkspaceIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let tone: WorkspaceSurfaceTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WorkspaceType.metric)
            .foregroundStyle(isEnabled ? foregroundColor : .secondary)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tone.fillColor.opacity(configuration.isPressed ? 1.4 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tone.strokeColor, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundColor: Color {
        switch tone {
        case .accent:
            return .accentColor
        case .warning:
            return .orange
        case .critical:
            return .red
        case .success:
            return .green
        case .standard, .muted:
            return .secondary
        }
    }
}

struct WorkspaceLinearProgress: View {
    let value: Double?
    let total: Double
    let color: Color

    init(value: Double? = nil, total: Double = 1, color: Color = .accentColor) {
        self.value = value
        self.total = total
        self.color = color
    }

    var body: some View {
        GeometryReader { proxy in
            let fraction = normalizedFraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(color.opacity(0.8))
                    .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 4 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityValue(progressAccessibilityValue)
    }

    private var normalizedFraction: Double {
        guard let value else {
            return 0.22
        }

        guard total > 0 else {
            return 0
        }

        return min(max(value / total, 0), 1)
    }

    private var progressAccessibilityValue: String {
        guard let value else {
            return "In progress"
        }

        return "\(Int((min(max(value / max(total, 1), 0), 1) * 100).rounded())) percent"
    }
}

private struct WorkspaceSurfaceModifier: ViewModifier {
    let tone: WorkspaceSurfaceTone
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tone.fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tone.strokeColor, lineWidth: 1)
            )
    }
}

extension View {
    func workspaceSurface(
        tone: WorkspaceSurfaceTone = .standard,
        padding: CGFloat = WorkspaceChrome.surfacePadding
    ) -> some View {
        modifier(
            WorkspaceSurfaceModifier(
                tone: tone,
                padding: padding,
                radius: WorkspaceChrome.surfaceRadius
            )
        )
    }

    func workspaceInsetSurface(
        tone: WorkspaceSurfaceTone = .muted,
        padding: CGFloat = WorkspaceChrome.insetPadding
    ) -> some View {
        modifier(
            WorkspaceSurfaceModifier(
                tone: tone,
                padding: padding,
                radius: WorkspaceChrome.insetRadius
            )
        )
    }

    @ViewBuilder
    func applyAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
