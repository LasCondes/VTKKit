import Foundation
import Testing
import VTKKit

@Suite("PVD validation and failure recovery")
struct PVDValidationTests {
    @Test
    func rejectsInvalidSeriesAndUnexpectedDocuments() throws {
        for time in [Double.nan, .infinity, -.infinity] {
            #expect(throws: VTKWriter.Error.self) { try PVDFile.series(files: ["frame.vtu"], timesteps: [time]) }
            #expect(throws: VTKWriter.Error.self) { try PVDFile.series(groups: [.init(group: "motor", files: ["frame.vtu"], timesteps: [time])]) }
        }
        #expect(throws: VTKWriter.Error.self) { try PVDFile.series(files: [" "], timesteps: [0]) }
        #expect(throws: VTKWriter.Error.self) { try PVDFile.series(files: ["frame.vtu"], timesteps: [0], part: -1) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pvd")
        defer { try? FileManager.default.removeItem(at: url) }
        for xml in ["<Wrong />", "<VTKFile type=\"PolyData\"><Collection /></VTKFile>",
                    "<VTKFile type=\"Collection\" />", "<VTKFile type=\"Collection\"><Collection><Wrong /></Collection></VTKFile>",
                    "<VTKFile type=\"Collection\"><Collection><DataSet file=\"frame.vtu\" timestep=\"nan\" /></Collection></VTKFile>"] {
            try Data(xml.utf8).write(to: url)
            #expect(throws: VTKWriter.Error.self) { try PVDFile.load(from: url) }
        }
    }

    @Test
    func rejectedAppendLeavesSnapshotAndFileUnchanged() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pvd")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try PVDSeriesWriter(url: url)
        try await writer.append(file: "frame0.vtu", timestep: 0, part: 0)
        let original = try Data(contentsOf: url)
        do { try await writer.append(file: "frame1.vtu", timestep: .nan); Issue.record("Invalid append succeeded") }
        catch { }
        #expect(await writer.snapshot().collection.dataSet.count == 1)
        #expect(try Data(contentsOf: url) == original)
        try await writer.append(file: "frame1.vtu", timestep: 1, part: 0)
        #expect(try PVDFile.load(from: url).collection.dataSet.count == 2)
    }

    @Test
    func failedDiskWriteDoesNotCommitActorState() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocked = root.appendingPathComponent("blocked")
        try Data("regular file".utf8).write(to: blocked)
        let url = blocked.appendingPathComponent("series.pvd")
        let writer = try PVDSeriesWriter(url: url)
        do { try await writer.append(file: "failed.vtu", timestep: 0); Issue.record("Blocked append succeeded") }
        catch { }
        #expect(await writer.snapshot().collection.dataSet.isEmpty)
        let replacement = try PVDFile.series(files: ["failed-replacement.vtu"], timesteps: [0])
        do { try await writer.replace(with: replacement); Issue.record("Blocked replacement succeeded") }
        catch { }
        #expect(await writer.snapshot().collection.dataSet.isEmpty)
        try FileManager.default.removeItem(at: blocked)
        try await writer.append(file: "success.vtu", timestep: 1)
        #expect(try PVDFile.load(from: url).collection.dataSet.map(\.file) == ["success.vtu"])
    }
}
