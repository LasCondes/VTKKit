import Foundation

public extension PVDFile {
    static func load(from url: URL) throws -> PVDFile {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw VTKWriter.Error.invalidPVDDocument(
                path: url.path,
                reason: error.localizedDescription
            )
        }

        let parser = XMLParser(data: data)
        let delegate = PVDXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse(), delegate.failureReason == nil {
            return PVDFile(collection: .init(dataSet: delegate.dataSets))
        }

        let failureReason = delegate.failureReason ?? parser.parserError?.localizedDescription ?? "Unknown XML parsing failure."
        throw VTKWriter.Error.invalidPVDDocument(path: url.path, reason: failureReason)
    }

    func appending(_ dataSet: PVDDataSet) -> PVDFile {
        appending(contentsOf: [dataSet])
    }

    func appending(contentsOf dataSets: [PVDDataSet]) -> PVDFile {
        var copy = self
        copy.collection.dataSet.append(contentsOf: dataSets)
        return copy
    }
}

public actor PVDSeriesWriter {
    public let url: URL
    private var file: PVDFile
    private var canAppendInPlace: Bool

    public init(
        url: URL,
        loadExisting: Bool = true,
        initialFile: PVDFile = .init(collection: .init(dataSet: []))
    ) throws {
        self.url = url

        if loadExisting, FileManager.default.fileExists(atPath: url.path) {
            file = try PVDFile.load(from: url)
            canAppendInPlace = Self.hasCanonicalFooter(at: url)
        } else {
            file = initialFile
            canAppendInPlace = true
        }
    }

    public func append(_ dataSet: PVDDataSet) throws {
        try append(contentsOf: [dataSet])
    }

    public func append(
        file: String,
        timestep: Double,
        group: String = "default",
        part: Int = 1
    ) throws {
        try append(PVDDataSet(group: group, file: file, timestep: timestep, part: part))
    }

    public func append(contentsOf dataSets: [PVDDataSet]) throws {
        file = file.appending(contentsOf: dataSets)
        try appendInPlace(dataSets)
    }

    public func replace(with file: PVDFile) throws {
        self.file = file
        try writeCanonicalDocument(file)
        canAppendInPlace = true
    }

    public func snapshot() -> PVDFile {
        file
    }

    private func appendInPlace(_ dataSets: [PVDDataSet]) throws {
        guard dataSets.isEmpty == false else {
            return
        }

        if FileManager.default.fileExists(atPath: url.path) == false || canAppendInPlace == false {
            try writeCanonicalDocument(file)
            canAppendInPlace = true
            return
        }

        let footerData = Self.footerData
        do {
            let handle = try FileHandle(forUpdating: url)
            defer { try? handle.close() }

            let fileSize = try handle.seekToEnd()
            guard fileSize >= UInt64(footerData.count) else {
                try writeCanonicalDocument(file)
                canAppendInPlace = true
                return
            }

            try handle.seek(toOffset: fileSize - UInt64(footerData.count))
            let existingFooter = try handle.read(upToCount: footerData.count) ?? Data()
            guard existingFooter == footerData else {
                try writeCanonicalDocument(file)
                canAppendInPlace = true
                return
            }

            try handle.truncate(atOffset: fileSize - UInt64(footerData.count))
            try handle.seekToEnd()
            for dataSet in dataSets {
                try handle.write(contentsOf: Self.dataSetLineData(for: dataSet))
            }
            try handle.write(contentsOf: footerData)
        } catch let writerError as VTKWriter.Error {
            throw writerError
        } catch {
            throw VTKWriter.Error.failedToWrite(path: url.path, underlying: error)
        }
    }

    private func writeCanonicalDocument(_ file: PVDFile) throws {
        let directoryURL = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw VTKWriter.Error.failedToCreateDirectory(path: directoryURL.path, underlying: error)
        }

        let data = Self.headerData
            + file.collection.dataSet.reduce(into: Data()) { partialResult, dataSet in
                partialResult.append(Self.dataSetLineData(for: dataSet))
            }
            + Self.footerData

        do {
            try data.write(to: url)
        } catch {
            throw VTKWriter.Error.failedToWrite(path: url.path, underlying: error)
        }
    }

    private static func hasCanonicalFooter(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        guard let fileSize = try? handle.seekToEnd(),
              fileSize >= UInt64(footerData.count) else {
            return false
        }

        try? handle.seek(toOffset: fileSize - UInt64(footerData.count))
        let footer = try? handle.read(upToCount: footerData.count)
        return footer == footerData
    }

    private static var headerData: Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <VTKFile type="Collection" version="0.1" byte_order="LittleEndian">
          <Collection>
        """.utf8) + Data([0x0A])
    }

    private static var footerData: Data {
        Data("  </Collection>\n</VTKFile>\n".utf8)
    }

    private static func dataSetLineData(for dataSet: PVDDataSet) -> Data {
        Data(
            "    <DataSet timestep=\"\(String(dataSet.timestep).xmlEscaped)\" group=\"\(dataSet.group.xmlEscaped)\" part=\"\(String(dataSet.part).xmlEscaped)\" file=\"\(dataSet.file.xmlEscaped)\" />\n".utf8
        )
    }
}

private final class PVDXMLParserDelegate: NSObject, XMLParserDelegate {
    var dataSets: [PVDDataSet] = []
    var failureReason: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "DataSet" else {
            return
        }

        guard let file = attributeDict["file"], file.isEmpty == false else {
            fail(parser, reason: "Encountered a DataSet element without a file attribute.")
            return
        }

        let timestepString = attributeDict["timestep"] ?? "0"
        guard let timestep = Double(timestepString) else {
            fail(parser, reason: "Encountered a DataSet element with invalid timestep '\(timestepString)'.")
            return
        }

        let partString = attributeDict["part"] ?? "1"
        guard let part = Int(partString) else {
            fail(parser, reason: "Encountered a DataSet element with invalid part '\(partString)'.")
            return
        }

        dataSets.append(
            PVDDataSet(
                group: attributeDict["group"] ?? "default",
                file: file,
                timestep: timestep,
                part: part
            )
        )
    }

    private func fail(_ parser: XMLParser, reason: String) {
        guard failureReason == nil else {
            return
        }

        failureReason = reason
        parser.abortParsing()
    }
}
