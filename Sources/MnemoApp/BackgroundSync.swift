// Agent-B audit B-014
// Agent-B audit B-032
import Foundation
import MnemoCore
import MnemoOrchestrator

/// App-side background loop (M2): keeps the ingest index fresh and runs the
/// on-device media-extraction pass. Runs at utility priority — never on the
/// interactive path (M11 hardens this further).
final class BackgroundSync: Sendable {
    let index: IngestIndex
    let ingestor: MediaIngestor
    let engine: EngineClient
    let pollSeconds: Int
    let scheduler: WorkScheduler

    init(engine: EngineClient, config: MnemoConfig, scheduler: WorkScheduler) {
        self.engine = engine
        self.index = IngestIndex(docs: engine, container: "mnemo")
        self.ingestor = MediaIngestor(
            creator: engine, container: "mnemo",
            mountRoot: (config.smfs.mountPoint as NSString).expandingTildeInPath)
        self.pollSeconds = config.sync.pollSeconds
        self.scheduler = scheduler
    }

    func start() -> Task<Void, Never> {
        // Lowest priority; yields to interactive queries (M11).
        Task.detached(priority: .background) { [self] in
            while !Task.isCancelled {
                if await !scheduler.shouldBackgroundYield {
                    await index.refresh()
                    if let docs = try? await engine.documentsList(container: "mnemo") {
                        await ingestor.sync(docs: docs)
                    }
                }
                try? await Task.sleep(for: .seconds(pollSeconds))
            }
        }
    }
}
