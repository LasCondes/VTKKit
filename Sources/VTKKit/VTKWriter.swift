import Foundation

public enum VTKWriter {
    public enum Error: LocalizedError {
        case failedToEncodeDocument
        case failedToCreateDirectory(path: String, underlying: Swift.Error)
        case failedToWrite(path: String, underlying: Swift.Error)
        case unsupportedDataArrayType(arrayName: String, type: String)
        case invalidDataArrayValue(arrayName: String, type: String, value: String)
        case binaryPayloadTooLarge(arrayName: String, headerType: String, payloadByteCount: Int)

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
            case .binaryPayloadTooLarge(let arrayName, let headerType, let payloadByteCount):
                return "DataArray '\(arrayName)' payload of \(payloadByteCount) bytes exceeds the \(headerType) header limit."
            }
        }
    }

    public static func encode(_ file: VTKFile) throws -> Data {
        try data(for: file)
    }

    public static func encode(_ file: PVDFile) throws -> Data {
        try data(for: file)
    }

    public static func write(_ file: VTKFile, to url: URL) throws {
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
