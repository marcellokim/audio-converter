import Foundation

struct ConversionCoordinator {
    private let engine: ConversionEngine
    private let presenter: BatchStatusPresenting
    let maximumConcurrentJobs: Int

    init(
        engine: ConversionEngine = ConversionEngine(),
        presenter: BatchStatusPresenting = BatchStatusPresenter(),
        maximumConcurrentJobs: Int = 2
    ) {
        self.engine = engine
        self.presenter = presenter
        self.maximumConcurrentJobs = max(1, min(maximumConcurrentJobs, 2))
    }

    func process(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL
    ) -> [BatchStatusSnapshot] {
        var snapshots: [BatchStatusSnapshot] = []
        let batch = Array(files.prefix(files.count))

        for chunkStart in stride(from: 0, to: batch.count, by: maximumConcurrentJobs) {
            let chunk = Array(batch[chunkStart ..< min(chunkStart + maximumConcurrentJobs, batch.count)])
            for file in chunk {
                switch engine.makeJob(for: file, format: format) {
                case let .success(job):
                    let state = engine.run(job: job, ffmpegURL: ffmpegURL)
                    snapshots.append(presenter.makeSnapshot(fileName: file.displayName, state: state))
                case let .failure(state):
                    snapshots.append(presenter.makeSnapshot(fileName: file.displayName, state: state))
                }
            }
        }

        return snapshots
    }
}
