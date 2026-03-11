import Foundation

public enum VTKWriter {
    public enum Error: LocalizedError {
        case failedToEncodeDocument
        case failedToCreateDirectory(path: String, underlying: Swift.Error)
        case failedToWrite(path: String, underlying: Swift.Error)
        case unsupportedDataArrayType(arrayName: String, type: String)
        case invalidDataArrayValue(arrayName: String, type: String, value: String)
        case invalidBinaryStorage(arrayName: String, type: String, expectedByteCount: Int, actualByteCount: Int)
        case binaryPayloadTooLarge(arrayName: String, headerType: String, payloadByteCount: Int)
        case compressionFailed(arrayName: String, algorithm: String)
        case invalidCompressionConfiguration(reason: String)
        case invalidComponentCount(arrayName: String, datasetPath: String, valueCount: Int, numberOfComponents: Int)
        case invalidTupleCount(arrayName: String, datasetPath: String, expectedTupleCount: Int, actualTupleCount: Int)
        case invalidCellLayout(datasetPath: String, reason: String)
        case invalidSeriesDefinition(reason: String)
        case invalidParallelDefinition(reason: String)
        case invalidPVDDocument(path: String, reason: String)
        case numericOverflow(datasetPath: String, value: Int, targetType: String)

        public var errorDescription: String? {
            switch self {
            case .failedToEncodeDocument:
                return "Could not encode the VTK document as UTF-8 data."
            case .failedToCreateDirectory(let path, let underlying):
                return "Could not create the output directory at '\(path)'. \(underlying.localizedDescription)"
            case .failedToWrite(let path, let underlying):
                return "Could not write VTK output to '\(path)'. \(underlying.localizedDescription)"
            case .unsupportedDataArrayType(let arrayName, let type):
                return "DataArray '\(arrayName)' uses unsupported VTK type '\(type)'."
            case .invalidDataArrayValue(let arrayName, let type, let value):
                return "DataArray '\(arrayName)' contains value '\(value)' that cannot be encoded as \(type)."
            case .invalidBinaryStorage(let arrayName, let type, let expectedByteCount, let actualByteCount):
                return "DataArray '\(arrayName)' uses VTK type '\(type)' with \(actualByteCount) bytes of raw storage, expected \(expectedByteCount)."
            case .binaryPayloadTooLarge(let arrayName, let headerType, let payloadByteCount):
                return "DataArray '\(arrayName)' payload of \(payloadByteCount) bytes exceeds the \(headerType) header limit."
            case .compressionFailed(let arrayName, let algorithm):
                return "DataArray '\(arrayName)' could not be compressed with \(algorithm)."
            case .invalidCompressionConfiguration(let reason):
                return "Invalid VTK compression configuration. \(reason)"
            case .invalidComponentCount(let arrayName, let datasetPath, let valueCount, let numberOfComponents):
                return "DataArray '\(arrayName)' at '\(datasetPath)' has \(valueCount) values, which is not divisible by NumberOfComponents=\(numberOfComponents)."
            case .invalidTupleCount(let arrayName, let datasetPath, let expectedTupleCount, let actualTupleCount):
                return "DataArray '\(arrayName)' at '\(datasetPath)' has \(actualTupleCount) tuples, expected \(expectedTupleCount)."
            case .invalidCellLayout(let datasetPath, let reason):
                return "Invalid cell layout at '\(datasetPath)'. \(reason)"
            case .invalidSeriesDefinition(let reason):
                return "Invalid PVD series definition. \(reason)"
            case .invalidParallelDefinition(let reason):
                return "Invalid parallel dataset definition. \(reason)"
            case .invalidPVDDocument(let path, let reason):
                return "Invalid PVD document at '\(path)'. \(reason)"
            case .numericOverflow(let datasetPath, let value, let targetType):
                return "Value \(value) at '\(datasetPath)' cannot be represented as \(targetType)."
            }
        }
    }

    public static func encode(_ file: VTKFile) throws -> Data {
        try data(for: file)
    }

    public static func encode(_ file: VTUFile) throws -> Data {
        try data(for: file)
    }

    public static func encode(_ file: PVTPFile) throws -> Data {
        try data(for: file)
    }

    public static func encode(_ file: PVTUFile) throws -> Data {
        try data(for: file)
    }

    public static func encode(_ file: PVDFile) throws -> Data {
        try data(for: file)
    }

    public static func write(_ file: VTKFile, to url: URL) throws {
        try writeData(encode(file), to: url)
    }

    public static func write(_ file: VTUFile, to url: URL) throws {
        try writeData(encode(file), to: url)
    }

    public static func write(_ file: PVTPFile, to url: URL) throws {
        try writeData(encode(file), to: url)
    }

    public static func write(_ file: PVTUFile, to url: URL) throws {
        try writeData(encode(file), to: url)
    }

    public static func write(_ file: PVDFile, to url: URL) throws {
        try writeData(encode(file), to: url)
    }

    private static func data(for document: XMLDocumentRenderable) throws -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        try document.renderXML(into: &xml)
        guard let data = xml.data(using: .utf8) else {
            throw Error.failedToEncodeDocument
        }
        return data
    }

    private static func writeData(_ data: @autoclosure () throws -> Data, to url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw Error.failedToCreateDirectory(path: directoryURL.path, underlying: error)
        }

        do {
            try data().write(to: url)
        } catch let writerError as Error {
            throw writerError
        } catch {
            throw Error.failedToWrite(path: url.path, underlying: error)
        }
    }
}

protocol XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws
}

enum XMLTag {
    private static func indentation(_ level: Int) -> String {
        String(repeating: "  ", count: level)
    }

    private static func serializedAttributes(_ attributes: [(String, String?)]) -> String {
        attributes.compactMap { key, value in
            guard let value else {
                return nil
            }
            return " \(key)=\"\(value.xmlEscaped)\""
        }
        .joined()
    }

    static func open(
        _ name: String,
        attributes: [(String, String?)] = [],
        into xml: inout String,
        indentLevel: Int
    ) {
        xml += "\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes))>\n"
    }

    static func close(_ name: String, into xml: inout String, indentLevel: Int) {
        xml += "\(indentation(indentLevel))</\(name)>\n"
    }

    static func leaf(
        _ name: String,
        attributes: [(String, String?)] = [],
        into xml: inout String,
        indentLevel: Int
    ) {
        xml += "\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes)) />\n"
    }

    static func text(
        _ name: String,
        attributes: [(String, String?)] = [],
        text: String,
        into xml: inout String,
        indentLevel: Int
    ) {
        xml += "\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes))>\(text.xmlEscaped)</\(name)>\n"
    }
}

extension String {
    fileprivate var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
