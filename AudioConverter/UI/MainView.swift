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
                    - WorkspaceChrome.topBarHeight
                    - WorkspaceChrome.pageSpacing,
                0
            )

            VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
                topBar(using: presentation)
                    .frame(height: WorkspaceChrome.topBarHeight)

                workspace(
                    for: layout,
                    contentHeight: contentHeight,
                    presentation: presentation
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(WorkspaceChrome.pagePadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func workspace(
        for layout: MainViewLayout,
        contentHeight: CGFloat,
        presentation: WorkspacePresentation
    ) -> some View {
        if layout.prefersBalancedGrid {
            balancedWorkspace(
                for: layout,
                contentHeight: contentHeight,
                presentation: presentation
            )
        } else {
            compactWorkspace(
                for: layout,
                contentHeight: contentHeight,
                presentation: presentation
            )
        }
    }

    private func balancedWorkspace(
        for layout: MainViewLayout,
        contentHeight: CGFloat,
        presentation: WorkspacePresentation
    ) -> some View {
        let columnWidths = layout.balancedColumnWidths
        let monitorHeight = layout.monitorRowHeight(for: contentHeight)
        let setupHeight = max(contentHeight - monitorHeight - WorkspaceChrome.pageSpacing, 0)

        return VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                fileSelectionSection
                    .frame(width: columnWidths.source, height: setupHeight, alignment: .topLeading)

                setupControlsColumn
                    .frame(width: columnWidths.controls, height: setupHeight, alignment: .topLeading)

                exportColumn(using: presentation.action)
                    .frame(width: columnWidths.export, height: setupHeight, alignment: .topLeading)
            }
            .frame(height: setupHeight, alignment: .topLeading)

            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                queueManagerSection
                    .frame(width: columnWidths.source, height: monitorHeight, alignment: .topLeading)

                batchStatusSection
                    .frame(width: columnWidths.controls + columnWidths.export + WorkspaceChrome.pageSpacing, height: monitorHeight, alignment: .topLeading)
            }
            .frame(height: monitorHeight, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactWorkspace(
        for layout: MainViewLayout,
        contentHeight: CGFloat,
        presentation: WorkspacePresentation
    ) -> some View {
        let secondaryWidth = layout.secondaryColumnWidth

        return HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
            primaryLane(contentHeight: contentHeight)
                .frame(
                    width: max(layout.availableWidth - secondaryWidth - WorkspaceChrome.pageSpacing, 300),
                    alignment: .topLeading
                )
                .layoutPriority(1)

            secondaryLane(using: presentation)
                .frame(width: secondaryWidth, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var setupControlsColumn: some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            operationModeSection
                .frame(maxWidth: .infinity, alignment: .topLeading)

            FormatInputView(
                outputFormat: $appState.outputFormat,
                formats: FormatRegistry.allFormats,
                isEnabled: !appState.isConverting
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if isMergeMode {
                mergeDestinationSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func exportColumn(using action: WorkspacePresentation.Action) -> some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            primaryActionSection(using: action)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            exportReadinessCard(using: action)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func primaryLane(contentHeight: CGFloat) -> some View {
        let statusHeight = min(max(contentHeight * 0.38, 220), 278)

        return VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            fileSelectionSection
                .frame(maxHeight: .infinity, alignment: .top)

            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                queueManagerSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                batchStatusSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: statusHeight, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
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

    private var queueManagerSection: some View {
        let snapshot = appState.queueDashboardSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(isMergeMode ? "Merge queue" : "Batch queue", systemImage: isMergeMode ? "arrow.triangle.merge" : "square.stack.3d.up")
                    .font(WorkspaceType.bodyStrong)

                Spacer(minLength: 0)

                Text(queueManagerMessage(for: snapshot))
                    .font(WorkspaceType.metric)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    queueStatusPills(for: snapshot)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                    queueStatusPills(for: snapshot)
                }
            }

            if snapshot.totalTrackedCount > 0 {
                WorkspaceLinearProgress(
                    value: Double(snapshot.terminalCount),
                    total: Double(max(snapshot.totalTrackedCount, 1)),
                    color: .accentColor
                )
                .accessibilityIdentifier("queue-progress")
            }

            schedulerControlSection(for: snapshot)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .workspaceSurface(tone: .muted, padding: 12)
        .accessibilityIdentifier("queue-manager")
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

            HStack(spacing: 8) {
                modeButton(
                    title: "Batch",
                    mode: .batchConvert,
                    identifier: "mode-batch"
                )
                modeButton(
                    title: "Merge",
                    mode: .mergeIntoOne,
                    identifier: "mode-merge"
                )
            }

            Text(isMergeMode ? "One ordered export." : "Separate output per file.")
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
    static let balancedGridBreakpoint: CGFloat = 860

    let windowWidth: CGFloat
    let availableWidth: CGFloat

    init(windowWidth: CGFloat) {
        self.windowWidth = windowWidth
        self.availableWidth = max(windowWidth - (WorkspaceChrome.pagePadding * 2), 0)
    }

    var prefersTwoColumn: Bool {
        prefersBalancedGrid
    }

    var prefersBalancedGrid: Bool {
        availableWidth >= Self.balancedGridBreakpoint
    }

    var balancedColumnWidths: (source: CGFloat, controls: CGFloat, export: CGFloat) {
        let contentWidth = max(availableWidth - (WorkspaceChrome.pageSpacing * 2), 0)
        let controls = min(max(contentWidth * 0.24, 220), 248)
        let export = min(max(contentWidth * 0.24, 220), 248)
        let source = max(contentWidth - controls - export, 360)

        return (source, controls, export)
    }

    func monitorRowHeight(for contentHeight: CGFloat) -> CGFloat {
        min(max(contentHeight * 0.33, 204), 232)
    }

    var secondaryColumnWidth: CGFloat {
        min(max(availableWidth * 0.35, 260), 318)
    }
}

enum WorkspaceChrome {
    static let pagePadding: CGFloat = 14
    static let pageSpacing: CGFloat = 10
    static let topBarHeight: CGFloat = 70
    static let surfacePadding: CGFloat = 12
    static let insetPadding: CGFloat = 9
    static let surfaceRadius: CGFloat = 8
    static let insetRadius: CGFloat = 6
}

enum WorkspaceType {
    static let display = Font.system(size: 24, weight: .semibold)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
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
            return Color.primary.opacity(0.035)
        case .accent:
            return Color.accentColor.opacity(0.08)
        case .muted:
            return Color.primary.opacity(0.020)
        case .warning:
            return Color.orange.opacity(0.08)
        case .critical:
            return Color.red.opacity(0.09)
        case .success:
            return Color.green.opacity(0.08)
        }
    }

    var strokeColor: Color {
        switch self {
        case .standard:
            return Color.primary.opacity(0.07)
        case .accent:
            return Color.accentColor.opacity(0.20)
        case .muted:
            return Color.primary.opacity(0.04)
        case .warning:
            return Color.orange.opacity(0.18)
        case .critical:
            return Color.red.opacity(0.20)
        case .success:
            return Color.green.opacity(0.20)
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
