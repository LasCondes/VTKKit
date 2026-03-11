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

    public init(
        url: URL,
        loadExisting: Bool = true,
        initialFile: PVDFile = .init(collection: .init(dataSet: []))
    ) throws {
        self.url = url

        if loadExisting, FileManager.default.fileExists(atPath: url.path) {
            file = try PVDFile.load(from: url)
        } else {
            file = initialFile
        }
    }

    public func append(_ dataSet: PVDDataSet) throws {
        file = file.appending(dataSet)
        try VTKWriter.write(file, to: url)
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
        try VTKWriter.write(file, to: url)
    }

    public func replace(with file: PVDFile) throws {
        self.file = file
        try VTKWriter.write(file, to: url)
    }

    public func snapshot() -> PVDFile {
        file
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
