import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AudioConverter")
                .font(.largeTitle.weight(.semibold))

            Text("Initial scaffold for the FFmpeg-based macOS batch audio converter.")
                .foregroundStyle(.secondary)

            if let startupError = appState.startupError {
                Text(startupError)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Output format")
                    .font(.headline)
                TextField("mp3", text: $appState.outputFormat)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Selected files")
                    .font(.headline)

                if appState.selectedFiles.isEmpty {
                    Text("No files selected yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.selectedFiles, id: \.self) { fileURL in
                        Text(fileURL.lastPathComponent)
                    }
                }
            }

            HStack {
                Button("Select Files") {
                    appState.statusMessage = "File selection adapter will be added in the next implementation cycle."
                }

                Button("Start Conversion") {
                    appState.statusMessage = "Conversion engine scaffold is pending implementation."
                }
                .disabled(!appState.canStartConversion)
            }

            Text(appState.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }
}
