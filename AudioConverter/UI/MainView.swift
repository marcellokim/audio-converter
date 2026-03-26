import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            let layout = MainViewLayout(windowWidth: proxy.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
                    header

                    StatusBannerView(
                        title: bannerTitle,
                        message: bannerMessage,
                        tone: bannerTone
                    )

                    workspace(for: layout)
                }
                .padding(WorkspaceChrome.pagePadding)
                .frame(width: max(layout.availableWidth, 0), alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func workspace(for layout: MainViewLayout) -> some View {
        if layout.prefersTwoColumn {
            let secondaryWidth = min(max(layout.availableWidth * 0.34, 280), 320)
            HStack(alignment: .top, spacing: WorkspaceChrome.pageSpacing) {
                primaryLane
                    .frame(
                        width: max(layout.availableWidth - secondaryWidth - WorkspaceChrome.pageSpacing, 280),
                        alignment: .leading
                    )
                    .layoutPriority(1)
                secondaryLane
                    .frame(width: secondaryWidth, alignment: .leading)
            }
            .frame(width: max(layout.availableWidth, 0), alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
                FileSelectionView(
                    files: appState.selectedAudioFiles,
                    action: handleSelectFiles,
                    onRemove: handleRemoveSelectedFile,
                    onMoveUp: handleMoveSelectedFileUp,
                    onMoveDown: handleMoveSelectedFileDown,
                    canBrowseFiles: appState.canOpenFiles,
                    canRemoveFiles: appState.canRemoveSelectedFiles,
                    canReorderFiles: appState.canReorderSelectedFiles,
                    isMergeMode: isMergeMode
                )

                secondaryLane

                BatchStatusListView(snapshots: appState.batchSnapshots)
            }
            .frame(width: max(layout.availableWidth, 0), alignment: .leading)
        }
    }

    private var primaryLane: some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            FileSelectionView(
                files: appState.selectedAudioFiles,
                action: handleSelectFiles,
                onRemove: handleRemoveSelectedFile,
                onMoveUp: handleMoveSelectedFileUp,
                onMoveDown: handleMoveSelectedFileDown,
                canBrowseFiles: appState.canOpenFiles,
                canRemoveFiles: appState.canRemoveSelectedFiles,
                canReorderFiles: appState.canReorderSelectedFiles,
                isMergeMode: isMergeMode
            )

            BatchStatusListView(snapshots: appState.batchSnapshots)
        }
    }

    private var secondaryLane: some View {
        VStack(alignment: .leading, spacing: WorkspaceChrome.pageSpacing) {
            operationModeSection

            if isMergeMode {
                mergeDestinationSection

                primaryActionSection

                FormatInputView(
                    outputFormat: $appState.outputFormat,
                    formats: FormatRegistry.allFormats,
                    isEnabled: !appState.isConverting
                )
            } else {
                primaryActionSection

                FormatInputView(
                    outputFormat: $appState.outputFormat,
                    formats: FormatRegistry.allFormats,
                    isEnabled: !appState.isConverting
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AudioConverter")
                        .font(WorkspaceType.display)

                    Text("Batch convert audio or stage a deliberate order for one merged export, all inside a single adaptive workspace.")
                        .font(WorkspaceType.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                WorkspaceBadge(
                    title: appState.isConverting
                        ? (isMergeMode ? "Merge in flight" : "Batch in flight")
                        : (isMergeMode ? "Merge studio" : "Batch studio"),
                    tone: appState.isConverting ? .accent : .muted
                )
            }

            Text("The window keeps one scroll surface, stable selectors, and clearer separation between staging, export controls, and live status.")
                .font(WorkspaceType.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .workspaceSurface(tone: .standard)
    }

    private var operationModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkspaceSectionHeader(
                eyebrow: "Workflow",
                title: "Choose the session type",
                message: "Switch between per-file conversion and one ordered merge without duplicating any interactive controls."
            )

            HStack(spacing: 10) {
                modeButton(
                    title: "Batch Convert",
                    mode: .batchConvert,
                    identifier: "mode-batch"
                )
                modeButton(
                    title: "Merge into One",
                    mode: .mergeIntoOne,
                    identifier: "mode-merge"
                )
            }
        }
        .workspaceSurface(tone: .standard)
    }

    private var mergeDestinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                WorkspaceSectionHeader(
                    eyebrow: "Destination",
                    title: "Choose the merged export path",
                    message: "Choose the export location before starting the merge."
                )

                Spacer(minLength: 0)

                Button("Choose Destination", action: handleSelectMergeDestination)
                    .buttonStyle(.borderedProminent)
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
                .workspaceInsetSurface(tone: .muted)
            } else {
                Text("No merge destination selected yet.")
                    .font(WorkspaceType.detail)
                    .foregroundStyle(.secondary)
                    .workspaceInsetSurface(tone: .muted)
            }
        }
        .workspaceSurface(tone: .standard)
    }

    private var primaryActionSection: some View {
        VStack(alignment: .leading, spacing: isMergeMode ? 10 : 16) {
            WorkspaceSectionHeader(
                eyebrow: isMergeMode ? "Merge export" : "Batch export",
                title: isMergeMode ? "Run the ordered merge" : "Run the conversion batch",
                message: isMergeMode
                    ? "Start the merge once the staged files and destination are ready."
                    : "Readiness, validation, and live progress stay separated so blocked states do not crowd the main CTA row."
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    actionButtons
                }
            }

            if !isMergeMode || appState.isConverting || !canStartPrimaryAction {
                statusCallout(
                    title: "Readiness",
                    message: readinessMessage,
                    tone: .muted
                )
            }

            if case let .invalidFormat(rawInput) = validationState {
                statusCallout(
                    title: "Format check",
                    message: invalidFormatMessage(for: rawInput),
                    tone: .warning
                )
            }

            if !isMergeMode || appState.isConverting || !canStartPrimaryAction {
                statusCallout(
                    title: "Live status",
                    message: appState.statusMessage,
                    tone: appState.isConverting ? .accent : .standard,
                    identifier: "status-message"
                )
            }
        }
        .workspaceSurface(tone: .standard)
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
                .fixedSize(horizontal: false, vertical: true)
                .applyAccessibilityIdentifier(identifier)
        }
        .workspaceInsetSurface(tone: tone)
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(primaryActionTitle, action: handleStartPrimaryAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canStartPrimaryAction)
            .accessibilityIdentifier(primaryActionIdentifier)

        if appState.isConverting {
            Button(cancelActionTitle, action: handleCancelConversion)
                .buttonStyle(.bordered)
                .disabled(!appState.canCancelConversion)
                .accessibilityIdentifier(cancelActionIdentifier)
        }

        if appState.canRetryStartupChecks {
            Button("Retry Startup Check", action: handleRetryStartupChecks)
                .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(identifier)
            } else {
                Button(title) {
                    appState.operationMode = mode
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(identifier)
            }
        }
        .disabled(appState.isConverting)
    }

    private var isMergeMode: Bool {
        appState.operationMode == .mergeIntoOne
    }

    private var validationState: ValidationState {
        appState.formatValidationState
    }

    private var selectedFormat: SupportedFormat? {
        guard case let .valid(format) = validationState else {
            return nil
        }

        return format
    }

    private var canStartPrimaryAction: Bool {
        isMergeMode ? appState.canStartMerge : appState.canStartConversion
    }

    private var primaryActionTitle: String {
        isMergeMode ? "Start Merge" : "Start Conversion"
    }

    private var primaryActionIdentifier: String {
        isMergeMode ? "start-merge" : "start-conversion"
    }

    private var cancelActionTitle: String {
        if isMergeMode {
            return appState.isCancelling ? "Cancelling Merge…" : "Cancel Merge"
        }

        return appState.isCancelling ? "Cancelling Batch…" : "Cancel Batch"
    }

    private var cancelActionIdentifier: String {
        isMergeMode ? "cancel-merge" : "cancel-conversion"
    }

    private var bannerTone: StatusBannerView.Tone {
        switch appState.startupState {
        case .idle, .checking:
            return .checking
        case .startupError:
            return .blocked
        case .ready:
            return appState.isConverting ? .active : .ready
        }
    }

    private var bannerTitle: String {
        switch appState.startupState {
        case .idle:
            return "Preparing launch"
        case .checking:
            return "Checking bundled ffmpeg"
        case .startupError:
            return "Startup blocked"
        case .ready:
            if appState.isConverting {
                if isMergeMode {
                    return appState.isCancelling ? "Cancelling merge" : "Merging ordered audio"
                }

                return appState.isCancelling ? "Cancelling batch" : "Converting batch"
            }

            if let format = selectedFormat {
                if isMergeMode {
                    return appState.selectedAudioFiles.count < 2
                        ? "Stage files for ordered merge"
                        : "Merge into one \(format.displayName)"
                }

                if appState.selectedAudioFiles.isEmpty {
                    return "Ready for source files"
                }

                return "Prepared for \(format.displayName)"
            }

            return "Choose a supported format"
        }
    }

    private var bannerMessage: String {
        switch appState.startupState {
        case .idle, .checking:
            return "AudioConverter is validating the bundled ffmpeg runtime before file selection and export become available."
        case let .startupError(message):
            return message
        case .ready:
            if appState.isConverting, let format = selectedFormat {
                let verb = isMergeMode ? "Merging" : "Rendering"
                return "\(verb) \(appState.selectedAudioFiles.count) file(s) to \(format.displayName). \(appState.statusMessage)"
            }

            if let format = selectedFormat {
                if isMergeMode {
                    if appState.selectedAudioFiles.isEmpty {
                        return "Stage files, set their order, choose a destination, and merge into one \(format.displayName) export."
                    }

                    return "\(appState.selectedAudioFiles.count) ordered file(s) are staged for one \(format.displayName) export. \(appState.statusMessage)"
                }

                if appState.selectedAudioFiles.isEmpty {
                    return "The workspace is ready and waiting for files to render as \(format.displayName)."
                }

                return "\(appState.selectedAudioFiles.count) file(s) are staged for \(format.displayName). \(appState.statusMessage)"
            }

            return "Supported formats come from the built-in registry: \(supportedFormatsList)."
        }
    }

    private var readinessMessage: String {
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
                    : "Choose one or more source files to enable conversion."
            }

            guard let format = selectedFormat else {
                return "Enter a supported format such as \(supportedFormatsList)."
            }

            if isMergeMode {
                if appState.selectedAudioFiles.count < 2 {
                    return "Add at least one more source file to enable ordered merge."
                }

                if appState.mergeDestinationURL == nil {
                    return "Choose a destination before starting the merged \(format.displayName) export."
                }

                return "The ordered merge will export one \(format.outputExtension.uppercased()) file."
            }

            return "Conversion will render beside the source files as \(format.outputExtension.uppercased())."
        }
    }

    private var supportedFormatsList: String {
        FormatRegistry.allFormats.map(\.id).joined(separator: ", ")
    }

    private func invalidFormatMessage(for rawInput: String) -> String {
        let candidate = FormatRegistry.normalizedKey(for: rawInput)
        let token = candidate.isEmpty ? "That format" : "\"\(candidate)\""
        return "\(token) is not in the registry yet. Try \(supportedFormatsList)."
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

struct MainViewLayout: Equatable {
    static let wideBreakpoint: CGFloat = 840

    let windowWidth: CGFloat
    let availableWidth: CGFloat

    init(windowWidth: CGFloat) {
        self.windowWidth = windowWidth
        self.availableWidth = max(windowWidth - (WorkspaceChrome.pagePadding * 2), 0)
    }

    var prefersTwoColumn: Bool {
        availableWidth >= Self.wideBreakpoint
    }
}

enum WorkspaceChrome {
    static let pagePadding: CGFloat = 24
    static let pageSpacing: CGFloat = 20
    static let surfacePadding: CGFloat = 20
    static let insetPadding: CGFloat = 14
    static let surfaceRadius: CGFloat = 22
    static let insetRadius: CGFloat = 16
}

enum WorkspaceType {
    static let display = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let sectionTitle = Font.system(size: 21, weight: .semibold, design: .rounded)
    static let bodyStrong = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 14, weight: .regular, design: .rounded)
    static let detail = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let metric = Font.system(size: 11, weight: .semibold, design: .monospaced)
}

enum WorkspaceSurfaceTone {
    case standard
    case accent
    case muted
    case warning
    case critical

    var fillColor: Color {
        switch self {
        case .standard:
            return Color.primary.opacity(0.045)
        case .accent:
            return Color.accentColor.opacity(0.10)
        case .muted:
            return Color.primary.opacity(0.028)
        case .warning:
            return Color.orange.opacity(0.10)
        case .critical:
            return Color.red.opacity(0.11)
        }
    }

    var strokeColor: Color {
        switch self {
        case .standard:
            return Color.primary.opacity(0.08)
        case .accent:
            return Color.accentColor.opacity(0.24)
        case .muted:
            return Color.primary.opacity(0.05)
        case .warning:
            return Color.orange.opacity(0.22)
        case .critical:
            return Color.red.opacity(0.24)
        }
    }
}

struct WorkspaceSectionHeader: View {
    let eyebrow: String?
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow)
                    .font(WorkspaceType.caption)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(WorkspaceType.sectionTitle)

            Text(message)
                .font(WorkspaceType.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        case .standard, .muted:
            return .secondary
        }
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
