import Foundation

extension VTKWriter {
    static func writeStreaming(_ file: VTKFile, to url: URL) throws(VTKWriter.Error) {
        try file.polyData.validate(at: "PolyData")
        var sink = try XMLFileHandleSink(url: url)
        defer { sink.close() }

        let appendedLayout = try VTKStreamingBinaryLayout(
            appendedArrays: file.polyData.appendedArrays(),
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression
        )
        var context = VTKStreamingRenderContext(
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression,
            appendedOffsets: appendedLayout.offsets
        )

        try sink.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        try sink.writeOpenTag(
            "VTKFile",
            attributes: [
                ("type", "PolyData"),
                ("version", file.version),
                ("byte_order", file.byteOrder.rawValue),
                ("header_type", file.polyData.usesEncodedData ? file.headerType.rawValue : nil),
                ("compressor", file.polyData.usesEncodedData ? file.compression?.vtkClassName : nil),
            ],
            indentLevel: 0
        )
        try file.polyData.writeStreamingXML(into: &sink, indentLevel: 1, context: &context)
        try appendedLayout.writeAppendedDataIfNeeded(
            into: &sink,
            indentLevel: 1,
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression
        )
        try sink.writeCloseTag("VTKFile", indentLevel: 0)
    }

    static func writeStreaming(_ file: VTUFile, to url: URL) throws(VTKWriter.Error) {
        try file.unstructuredGrid.validate(at: "UnstructuredGrid")
        var sink = try XMLFileHandleSink(url: url)
        defer { sink.close() }

        let appendedLayout = try VTKStreamingBinaryLayout(
            appendedArrays: file.unstructuredGrid.appendedArrays(),
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression
        )
        var context = VTKStreamingRenderContext(
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression,
            appendedOffsets: appendedLayout.offsets
        )

        try sink.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        try sink.writeOpenTag(
            "VTKFile",
            attributes: [
                ("type", "UnstructuredGrid"),
                ("version", file.version),
                ("byte_order", file.byteOrder.rawValue),
                ("header_type", file.unstructuredGrid.usesEncodedData ? file.headerType.rawValue : nil),
                ("compressor", file.unstructuredGrid.usesEncodedData ? file.compression?.vtkClassName : nil),
            ],
            indentLevel: 0
        )
        try file.unstructuredGrid.writeStreamingXML(into: &sink, indentLevel: 1, context: &context)
        try appendedLayout.writeAppendedDataIfNeeded(
            into: &sink,
            indentLevel: 1,
            byteOrder: file.byteOrder,
            headerType: file.headerType,
            compression: file.compression
        )
        try sink.writeCloseTag("VTKFile", indentLevel: 0)
    }
}

private struct XMLFileHandleSink {
    let url: URL
    private let fileHandle: FileHandle

    init(url: URL) throws(VTKWriter.Error) {
        let directoryURL = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw VTKWriter.Error.failedToCreateDirectory(path: directoryURL.path, underlying: error)
        }

        if FileManager.default.fileExists(atPath: url.path) == false {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        do {
            fileHandle = try FileHandle(forWritingTo: url)
            try fileHandle.truncate(atOffset: 0)
        } catch {
            throw VTKWriter.Error.failedToOpenFile(path: url.path, underlying: error)
        }

        self.url = url
    }

    func close() {
        try? fileHandle.close()
    }

    func write(_ string: String) throws(VTKWriter.Error) {
        guard let data = string.data(using: .utf8) else {
            throw VTKWriter.Error.failedToEncodeDocument
        }
        try write(data)
    }

    func write(_ data: Data) throws(VTKWriter.Error) {
        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            throw VTKWriter.Error.failedToWrite(path: url.path, underlying: error)
        }
    }

    func writeOpenTag(
        _ name: String,
        attributes: [(String, String?)] = [],
        indentLevel: Int
    ) throws(VTKWriter.Error) {
        try write("\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes))>\n")
    }

    func writeCloseTag(_ name: String, indentLevel: Int) throws(VTKWriter.Error) {
        try write("\(indentation(indentLevel))</\(name)>\n")
    }

    func writeLeafTag(
        _ name: String,
        attributes: [(String, String?)] = [],
        indentLevel: Int
    ) throws(VTKWriter.Error) {
        try write("\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes)) />\n")
    }

    func writeTextTag(
        _ name: String,
        attributes: [(String, String?)] = [],
        text: String,
        indentLevel: Int
    ) throws(VTKWriter.Error) {
        try write(
            "\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes))>\(text.xmlEscaped)</\(name)>\n"
        )
    }

    func writeTagPrefix(
        _ name: String,
        attributes: [(String, String?)] = [],
        indentLevel: Int
    ) throws(VTKWriter.Error) {
        try write("\(indentation(indentLevel))<\(name)\(serializedAttributes(attributes))>")
    }

    func writeTagSuffix(_ name: String) throws(VTKWriter.Error) {
        try write("</\(name)>\n")
    }

    private func indentation(_ level: Int) -> String {
        String(repeating: "  ", count: level)
    }

    private func serializedAttributes(_ attributes: [(String, String?)]) -> String {
        attributes.compactMap { key, value in
            guard let value else {
                return nil
            }
            return " \(key)=\"\(value.xmlEscaped)\""
        }
        .joined()
    }
}

private struct VTKStreamingBinaryLayout {
    let appendedArrays: [DataArray]
    let offsets: [Int]

    init(
        appendedArrays: [DataArray],
        byteOrder: ByteOrder,
        headerType: BinaryDataHeaderType,
        compression: VTKCompression?
    ) throws(VTKWriter.Error) {
        self.appendedArrays = appendedArrays

        var offsets: [Int] = []
        offsets.reserveCapacity(appendedArrays.count)

        var nextOffset = 0
        for array in appendedArrays {
            offsets.append(nextOffset)
            let encodedByteCount = try array.encodedBinaryData(
                byteOrder: byteOrder,
                headerType: headerType,
                compression: compression
            ).count
            nextOffset += encodedByteCount.base64EncodedLength
        }

        self.offsets = offsets
    }

    func writeAppendedDataIfNeeded(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        byteOrder: ByteOrder,
        headerType: BinaryDataHeaderType,
        compression: VTKCompression?
    ) throws(VTKWriter.Error) {
        guard appendedArrays.isEmpty == false else {
            return
        }

        try sink.write("\(String(repeating: "  ", count: indentLevel))<AppendedData encoding=\"base64\">_")
        for array in appendedArrays {
            let encodedData = try array.encodedBinaryData(
                byteOrder: byteOrder,
                headerType: headerType,
                compression: compression
            )
            try sink.write(encodedData.base64EncodedData())
        }
        try sink.write("</AppendedData>\n")
    }
}

private struct VTKStreamingRenderContext {
    let byteOrder: ByteOrder
    let headerType: BinaryDataHeaderType
    let compression: VTKCompression?
    private let appendedOffsets: [Int]
    private var nextAppendedIndex = 0

    init(
        byteOrder: ByteOrder,
        headerType: BinaryDataHeaderType,
        compression: VTKCompression?,
        appendedOffsets: [Int]
    ) {
        self.byteOrder = byteOrder
        self.headerType = headerType
        self.compression = compression
        self.appendedOffsets = appendedOffsets
    }

    mutating func nextAppendedOffset() -> Int {
        defer { nextAppendedIndex += 1 }
        return appendedOffsets[nextAppendedIndex]
    }
}

private extension PolyData {
    func appendedArrays() -> [DataArray] {
        (fieldData?.appendedArrays() ?? []) + piece.appendedArrays()
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("PolyData", indentLevel: indentLevel)
        try fieldData?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try piece.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try sink.writeCloseTag("PolyData", indentLevel: indentLevel)
    }
}

private extension UnstructuredGrid {
    func appendedArrays() -> [DataArray] {
        (fieldData?.appendedArrays() ?? []) + piece.appendedArrays()
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("UnstructuredGrid", indentLevel: indentLevel)
        try fieldData?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try piece.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try sink.writeCloseTag("UnstructuredGrid", indentLevel: indentLevel)
    }
}

private extension FieldData {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("FieldData", indentLevel: indentLevel)
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("FieldData", indentLevel: indentLevel)
    }
}

private extension Piece {
    func appendedArrays() -> [DataArray] {
        points.appendedArrays()
            + (pointData?.appendedArrays() ?? [])
            + (polys?.appendedArrays() ?? [])
            + (verts?.appendedArrays() ?? [])
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag(
            "Piece",
            attributes: [
                ("NumberOfPoints", String(numberOfPoints)),
                ("NumberOfVerts", String(numberOfVerts)),
                ("NumberOfLines", String(numberOfLines)),
                ("NumberOfStrips", String(numberOfStrips)),
                ("NumberOfPolys", String(numberOfPolys)),
            ],
            indentLevel: indentLevel
        )
        try points.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try pointData?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try polys?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try verts?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try sink.writeCloseTag("Piece", indentLevel: indentLevel)
    }
}

private extension UnstructuredPiece {
    func appendedArrays() -> [DataArray] {
        (pointData?.appendedArrays() ?? [])
            + (cellData?.appendedArrays() ?? [])
            + points.appendedArrays()
            + cells.appendedArrays()
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag(
            "Piece",
            attributes: [
                ("NumberOfPoints", String(numberOfPoints)),
                ("NumberOfCells", String(numberOfCells)),
            ],
            indentLevel: indentLevel
        )
        try pointData?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try cellData?.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try points.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try cells.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try sink.writeCloseTag("Piece", indentLevel: indentLevel)
    }
}

private extension Points {
    func appendedArrays() -> [DataArray] {
        dataArray.format == .appended ? [dataArray] : []
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("Points", indentLevel: indentLevel)
        try dataArray.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        try sink.writeCloseTag("Points", indentLevel: indentLevel)
    }
}

private extension PointData {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag(
            "PointData",
            attributes: [
                ("Scalars", scalarsName),
                ("Vectors", vectorsName),
            ],
            indentLevel: indentLevel
        )
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("PointData", indentLevel: indentLevel)
    }
}

private extension CellData {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag(
            "CellData",
            attributes: [
                ("Scalars", scalarsName),
                ("Vectors", vectorsName),
            ],
            indentLevel: indentLevel
        )
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("CellData", indentLevel: indentLevel)
    }
}

private extension Polys {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("Polys", indentLevel: indentLevel)
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("Polys", indentLevel: indentLevel)
    }
}

private extension Verts {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("Verts", indentLevel: indentLevel)
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("Verts", indentLevel: indentLevel)
    }
}

private extension Cells {
    func appendedArrays() -> [DataArray] {
        dataArray.filter { $0.format == .appended }
    }

    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        try sink.writeOpenTag("Cells", indentLevel: indentLevel)
        for element in dataArray {
            try element.writeStreamingXML(into: &sink, indentLevel: indentLevel + 1, context: &context)
        }
        try sink.writeCloseTag("Cells", indentLevel: indentLevel)
    }
}

private extension DataArray {
    func writeStreamingXML(
        into sink: inout XMLFileHandleSink,
        indentLevel: Int,
        context: inout VTKStreamingRenderContext
    ) throws(VTKWriter.Error) {
        let attributes: [(String, String?)] = [
            ("type", type),
            ("Name", name),
            ("format", format.rawValue),
            ("NumberOfComponents", numberOfComponents.map(String.init)),
        ]

        switch format {
        case .ascii:
            try sink.writeTextTag(
                "DataArray",
                attributes: attributes,
                text: try renderedTextValues(),
                indentLevel: indentLevel
            )
        case .binary:
            try sink.writeTagPrefix("DataArray", attributes: attributes, indentLevel: indentLevel)
            let encodedData = try encodedBinaryData(
                byteOrder: context.byteOrder,
                headerType: context.headerType,
                compression: context.compression
            )
            try sink.write(encodedData.base64EncodedData())
            try sink.writeTagSuffix("DataArray")
        case .appended:
            try sink.writeLeafTag(
                "DataArray",
                attributes: attributes + [("offset", String(context.nextAppendedOffset()))],
                indentLevel: indentLevel
            )
        }
    }
}

private extension Int {
    var base64EncodedLength: Int {
        ((self + 2) / 3) * 4
    }
}
