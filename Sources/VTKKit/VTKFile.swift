import Foundation

public enum ByteOrder: String, Sendable, Codable {
    case littleEndian = "LittleEndian"
    case bigEndian = "BigEndian"

    public static var native: ByteOrder {
        #if _endian(little)
        .littleEndian
        #else
        .bigEndian
        #endif
    }
}

public enum DataArrayFormat: String, Sendable, Codable {
    case ascii
    case binary
    case appended
}

public enum BinaryDataHeaderType: String, Sendable, Codable {
    case uInt32 = "UInt32"
    case uInt64 = "UInt64"
}

public struct VTKFile: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var headerType: BinaryDataHeaderType
    public var compression: VTKCompression?
    public var polyData: PolyData

    public init(
        polyData: PolyData,
        version: String = "0.1",
        byteOrder: ByteOrder = .littleEndian,
        headerType: BinaryDataHeaderType = .uInt32,
        compression: VTKCompression? = nil
    ) {
        self.polyData = polyData
        self.version = version
        self.byteOrder = byteOrder
        self.headerType = headerType
        self.compression = compression
    }
}

public struct PolyData: Sendable, Equatable, Codable {
    public var fieldData: FieldData?
    public var piece: Piece

    public init(piece: Piece, fieldData: FieldData? = nil) {
        self.fieldData = fieldData
        self.piece = piece
    }
}

public struct FieldData: Sendable, Equatable, Codable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }

    public init(timeValue: DataArray) {
        self.dataArray = [timeValue]
    }
}

public struct Piece: Sendable, Equatable, Codable {
    public var numberOfPoints: Int
    public var numberOfVerts: Int
    public var numberOfLines: Int
    public var numberOfStrips: Int
    public var numberOfPolys: Int

    public var points: Points
    public var pointData: PointData?
    public var polys: Polys?
    public var verts: Verts?

    public init(
        numberOfPoints: Int = 0,
        numberOfVerts: Int = 0,
        numberOfLines: Int = 0,
        numberOfStrips: Int = 0,
        numberOfPolys: Int = 0,
        points: Points,
        pointData: PointData? = nil,
        polys: Polys? = nil,
        verts: Verts? = nil
    ) {
        self.numberOfPoints = numberOfPoints
        self.numberOfVerts = numberOfVerts
        self.numberOfLines = numberOfLines
        self.numberOfStrips = numberOfStrips
        self.numberOfPolys = numberOfPolys
        self.points = points
        self.pointData = pointData
        self.polys = polys
        self.verts = verts
    }
}

public struct Points: Sendable, Equatable, Codable {
    public var dataArray: DataArray

    public init(dataArray: DataArray) {
        self.dataArray = dataArray
    }
}

public struct PointData: Sendable, Equatable, Codable {
    public var scalarsName: String?
    public var vectorsName: String?
    public var dataArray: [DataArray]

    public init(
        scalarsName: String? = nil,
        vectorsName: String? = nil,
        dataArray: [DataArray]
    ) {
        self.scalarsName = scalarsName
        self.vectorsName = vectorsName
        self.dataArray = dataArray
    }
}

public struct Polys: Sendable, Equatable, Codable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }

    public init(connectivity: DataArray, offsets: DataArray) {
        self.dataArray = [connectivity, offsets]
    }
}

public struct Verts: Sendable, Equatable, Codable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }
}

public struct DataArray: Sendable, Equatable, Codable {
    public var type: String
    public var name: String
    public var format: DataArrayFormat
    public var numberOfComponents: Int?
    public var values: String
    public var binaryStorage: DataArrayBinaryStorage?

    @available(*, deprecated, message: "Prefer typed DataArray initializers or the explicit uncheckedType: initializer.")
    public init<Value: LosslessStringConvertible>(
        type: String,
        name: String,
        format: DataArrayFormat = .ascii,
        numberOfComponents: Int,
        values: [Value]
    ) {
        self.init(
            uncheckedType: type,
            name: name,
            format: format,
            numberOfComponents: numberOfComponents,
            values: values
        )
    }

    @available(*, deprecated, message: "Prefer typed DataArray initializers or the explicit uncheckedType: initializer.")
    public init(
        type: String,
        name: String,
        format: DataArrayFormat = .ascii,
        numberOfComponents: Int
    ) {
        self.init(
            uncheckedType: type,
            name: name,
            format: format,
            numberOfComponents: numberOfComponents
        )
    }

    @available(*, deprecated, message: "Prefer typed DataArray initializers or the explicit uncheckedType: initializer.")
    public init(
        type: String,
        name: String,
        format: DataArrayFormat = .binary,
        numberOfComponents: Int,
        binaryStorage: DataArrayBinaryStorage
    ) {
        self.init(
            uncheckedType: type,
            name: name,
            format: format,
            numberOfComponents: numberOfComponents,
            binaryStorage: binaryStorage
        )
    }

    public init<Value: LosslessStringConvertible>(
        uncheckedType type: String,
        name: String,
        format: DataArrayFormat = .ascii,
        numberOfComponents: Int,
        values: [Value]
    ) {
        self.type = type
        self.name = name
        self.format = format
        self.numberOfComponents = numberOfComponents
        self.values = values.map { String($0) }.joined(separator: " ")
        self.binaryStorage = nil
    }

    public init(
        uncheckedType type: String,
        name: String,
        format: DataArrayFormat = .ascii,
        numberOfComponents: Int
    ) {
        self.type = type
        self.name = name
        self.format = format
        self.numberOfComponents = numberOfComponents
        self.values = ""
        self.binaryStorage = nil
    }

    public init(
        uncheckedType type: String,
        name: String,
        format: DataArrayFormat = .binary,
        numberOfComponents: Int,
        binaryStorage: DataArrayBinaryStorage
    ) {
        self.type = type
        self.name = name
        self.format = format
        self.numberOfComponents = numberOfComponents
        self.values = ""
        self.binaryStorage = binaryStorage
    }
}

public struct DataArrayBinaryStorage: Sendable, Equatable, Codable {
    public var data: Data
    public var valueCount: Int
    public var byteOrder: ByteOrder

    public init(data: Data, valueCount: Int, byteOrder: ByteOrder = .native) {
        self.data = data
        self.valueCount = valueCount
        self.byteOrder = byteOrder
    }
}

extension VTKFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws {
        try polyData.validate(at: "PolyData")
        var context = VTKXMLBinaryEncodingContext(
            byteOrder: byteOrder,
            headerType: headerType,
            compression: compression
        )
        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", "PolyData"),
                ("version", version),
                ("byte_order", byteOrder.rawValue),
                ("header_type", polyData.usesEncodedData ? headerType.rawValue : nil),
                ("compressor", polyData.usesEncodedData ? compression?.vtkClassName : nil),
            ],
            into: &xml,
            indentLevel: 0
        )
        try polyData.renderXML(into: &xml, indentLevel: 1, context: &context)
        context.renderAppendedData(into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}

extension PolyData {
    var usesEncodedData: Bool {
        fieldData?.usesEncodedData == true || piece.usesEncodedData
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("PolyData", into: &xml, indentLevel: indentLevel)
        try fieldData?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try piece.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        XMLTag.close("PolyData", into: &xml, indentLevel: indentLevel)
    }
}

extension Piece {
    var usesEncodedData: Bool {
        points.usesEncodedData
            || pointData?.usesEncodedData == true
            || polys?.usesEncodedData == true
            || verts?.usesEncodedData == true
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open(
            "Piece",
            attributes: [
                ("NumberOfPoints", String(numberOfPoints)),
                ("NumberOfVerts", String(numberOfVerts)),
                ("NumberOfLines", String(numberOfLines)),
                ("NumberOfStrips", String(numberOfStrips)),
                ("NumberOfPolys", String(numberOfPolys)),
            ],
            into: &xml,
            indentLevel: indentLevel
        )

        try points.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try pointData?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try polys?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try verts?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)

        XMLTag.close("Piece", into: &xml, indentLevel: indentLevel)
    }
}

extension FieldData {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("FieldData", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            try element.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        }
        XMLTag.close("FieldData", into: &xml, indentLevel: indentLevel)
    }
}

extension Points {
    var usesEncodedData: Bool {
        dataArray.usesEncodedData
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("Points", into: &xml, indentLevel: indentLevel)
        try dataArray.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        XMLTag.close("Points", into: &xml, indentLevel: indentLevel)
    }
}

extension PointData {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open(
            "PointData",
            attributes: [
                ("Scalars", scalarsName),
                ("Vectors", vectorsName),
            ],
            into: &xml,
            indentLevel: indentLevel
        )
        for element in dataArray {
            try element.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        }
        XMLTag.close("PointData", into: &xml, indentLevel: indentLevel)
    }
}

extension Polys {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("Polys", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            try element.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        }
        XMLTag.close("Polys", into: &xml, indentLevel: indentLevel)
    }
}

extension Verts {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("Verts", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            try element.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        }
        XMLTag.close("Verts", into: &xml, indentLevel: indentLevel)
    }
}

extension DataArray {
    var usesEncodedData: Bool {
        format != .ascii
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        let attributes: [(String, String?)] = [
            ("type", type),
            ("Name", name),
            ("format", format.rawValue),
            ("NumberOfComponents", numberOfComponents.map(String.init)),
        ]

        switch format {
        case .ascii:
            XMLTag.text(
                "DataArray",
                attributes: attributes,
                text: try renderedTextValues(),
                into: &xml,
                indentLevel: indentLevel
            )
        case .binary:
            XMLTag.text(
                "DataArray",
                attributes: attributes,
                text: try encodedBinaryChunk(
                    byteOrder: context.byteOrder,
                    headerType: context.headerType,
                    compression: context.compression
                ),
                into: &xml,
                indentLevel: indentLevel
            )
        case .appended:
            XMLTag.leaf(
                "DataArray",
                attributes: attributes + [
                    ("offset", String(try context.appendedOffset(for: self))),
                ],
                into: &xml,
                indentLevel: indentLevel
            )
        }
    }
}

struct VTKXMLBinaryEncodingContext {
    var byteOrder: ByteOrder
    var headerType: BinaryDataHeaderType
    var compression: VTKCompression?
    private var appendedSegments: [String] = []
    private var nextAppendedOffset = 0

    init(byteOrder: ByteOrder, headerType: BinaryDataHeaderType, compression: VTKCompression? = nil) {
        self.byteOrder = byteOrder
        self.headerType = headerType
        self.compression = compression
    }

    mutating func appendedOffset(for dataArray: DataArray) throws -> Int {
        let encodedChunk = try dataArray.encodedBinaryChunk(
            byteOrder: byteOrder,
            headerType: headerType,
            compression: compression
        )
        let offset = nextAppendedOffset
        appendedSegments.append(encodedChunk)
        nextAppendedOffset += encodedChunk.utf8.count
        return offset
    }

    func renderAppendedData(into xml: inout String, indentLevel: Int) {
        guard appendedSegments.isEmpty == false else {
            return
        }

        let indentation = String(repeating: "  ", count: indentLevel)
        xml += "\(indentation)<AppendedData encoding=\"base64\">_\(appendedSegments.joined())</AppendedData>\n"
    }
}

public enum VTKScalarType: String, Sendable, Codable, CaseIterable {
    case int8 = "Int8"
    case uint8 = "UInt8"
    case int16 = "Int16"
    case uint16 = "UInt16"
    case int32 = "Int32"
    case uint32 = "UInt32"
    case int64 = "Int64"
    case uint64 = "UInt64"
    case float32 = "Float32"
    case float64 = "Float64"

    var byteWidth: Int {
        switch self {
        case .int8, .uint8:
            1
        case .int16, .uint16:
            2
        case .int32, .uint32, .float32:
            4
        case .int64, .uint64, .float64:
            8
        }
    }

    func encode(tokens: [Substring], byteOrder: ByteOrder, arrayName: String) throws -> Data {
        var data = Data()

        switch self {
        case .int8:
            data.reserveCapacity(tokens.count)
            for token in tokens {
                try data.appendScalar(parse(Int8.self, token: token, arrayName: arrayName))
            }
        case .uint8:
            data.reserveCapacity(tokens.count)
            for token in tokens {
                try data.appendScalar(parse(UInt8.self, token: token, arrayName: arrayName))
            }
        case .int16:
            data.reserveCapacity(tokens.count * MemoryLayout<Int16>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(Int16.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .uint16:
            data.reserveCapacity(tokens.count * MemoryLayout<UInt16>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(UInt16.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .int32:
            data.reserveCapacity(tokens.count * MemoryLayout<Int32>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(Int32.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .uint32:
            data.reserveCapacity(tokens.count * MemoryLayout<UInt32>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(UInt32.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .int64:
            data.reserveCapacity(tokens.count * MemoryLayout<Int64>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(Int64.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .uint64:
            data.reserveCapacity(tokens.count * MemoryLayout<UInt64>.size)
            for token in tokens {
                try data.appendInteger(
                    parse(UInt64.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .float32:
            data.reserveCapacity(tokens.count * MemoryLayout<Float32>.size)
            for token in tokens {
                try data.appendFloat32(
                    parse(Float32.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        case .float64:
            data.reserveCapacity(tokens.count * MemoryLayout<Float64>.size)
            for token in tokens {
                try data.appendFloat64(
                    parse(Float64.self, token: token, arrayName: arrayName),
                    byteOrder: byteOrder
                )
            }
        }

        return data
    }

    func encode(
        storage: DataArrayBinaryStorage,
        targetByteOrder: ByteOrder,
        arrayName: String
    ) throws -> Data {
        let expectedByteCount = storage.valueCount * byteWidth
        guard storage.data.count == expectedByteCount else {
            throw VTKWriter.Error.invalidBinaryStorage(
                arrayName: arrayName,
                type: rawValue,
                expectedByteCount: expectedByteCount,
                actualByteCount: storage.data.count
            )
        }

        guard byteWidth > 1, storage.byteOrder != targetByteOrder else {
            return storage.data
        }

        return storage.data.byteSwapped(elementWidth: byteWidth)
    }

    func renderedASCIIValues(
        from storage: DataArrayBinaryStorage,
        arrayName: String
    ) throws -> String {
        let expectedByteCount = storage.valueCount * byteWidth
        guard storage.data.count == expectedByteCount else {
            throw VTKWriter.Error.invalidBinaryStorage(
                arrayName: arrayName,
                type: rawValue,
                expectedByteCount: expectedByteCount,
                actualByteCount: storage.data.count
            )
        }

        var renderedValues: [String] = []
        renderedValues.reserveCapacity(storage.valueCount)

        switch self {
        case .int8:
            for value in storage.data {
                renderedValues.append(String(Int8(bitPattern: value)))
            }
        case .uint8:
            for value in storage.data {
                renderedValues.append(String(value))
            }
        case .int16:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: Int16.self,
                arrayName: arrayName
            )
        case .uint16:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: UInt16.self,
                arrayName: arrayName
            )
        case .int32:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: Int32.self,
                arrayName: arrayName
            )
        case .uint32:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: UInt32.self,
                arrayName: arrayName
            )
        case .int64:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: Int64.self,
                arrayName: arrayName
            )
        case .uint64:
            try renderedValues.appendDecodedIntegers(
                from: storage,
                as: UInt64.self,
                arrayName: arrayName
            )
        case .float32:
            try renderedValues.appendDecodedFloat32s(
                from: storage,
                arrayName: arrayName
            )
        case .float64:
            try renderedValues.appendDecodedFloat64s(
                from: storage,
                arrayName: arrayName
            )
        }

        return renderedValues.joined(separator: " ")
    }

    private func parse<Value: LosslessStringConvertible>(
        _ type: Value.Type,
        token: Substring,
        arrayName: String
    ) throws -> Value {
        let value = String(token)
        guard let parsed = Value(value) else {
            throw VTKWriter.Error.invalidDataArrayValue(
                arrayName: arrayName,
                type: rawValue,
                value: value
            )
        }
        return parsed
    }
}

extension DataArray {
    var parsedTokens: [Substring] {
        values.split(whereSeparator: \.isWhitespace)
    }

    func encodedBinaryChunk(
        byteOrder: ByteOrder,
        headerType: BinaryDataHeaderType,
        compression: VTKCompression?
    ) throws -> String {
        try encodedBinaryData(
            byteOrder: byteOrder,
            headerType: headerType,
            compression: compression
        ).base64EncodedString()
    }

    func encodedBinaryData(
        byteOrder: ByteOrder,
        headerType: BinaryDataHeaderType,
        compression: VTKCompression?
    ) throws -> Data {
        let payload = try binaryPayload(byteOrder: byteOrder)
        if let compression {
            return try compression.encodedPayload(
                for: payload,
                headerType: headerType,
                byteOrder: byteOrder,
                arrayName: name
            )
        }
        return try headerType.prefixedPayload(
            payload,
            byteOrder: byteOrder,
            arrayName: name
        )
    }

    func binaryPayload(byteOrder: ByteOrder) throws -> Data {
        guard let scalarType = VTKScalarType(rawValue: type) else {
            throw VTKWriter.Error.unsupportedDataArrayType(arrayName: name, type: type)
        }
        if let binaryStorage {
            return try scalarType.encode(
                storage: binaryStorage,
                targetByteOrder: byteOrder,
                arrayName: name
            )
        }
        return try scalarType.encode(tokens: parsedTokens, byteOrder: byteOrder, arrayName: name)
    }

    func renderedTextValues() throws -> String {
        guard let binaryStorage else {
            return values
        }

        guard let scalarType = VTKScalarType(rawValue: type) else {
            throw VTKWriter.Error.unsupportedDataArrayType(arrayName: name, type: type)
        }

        return try scalarType.renderedASCIIValues(from: binaryStorage, arrayName: name)
    }
}

extension BinaryDataHeaderType {
    func prefixedPayload(
        _ payload: Data,
        byteOrder: ByteOrder,
        arrayName: String
    ) throws -> Data {
        var data = Data()
        try appendHeaderValue(payload.count, into: &data, byteOrder: byteOrder, arrayName: arrayName)
        data.append(payload)
        return data
    }

    func appendHeaderValue(
        _ value: Int,
        into data: inout Data,
        byteOrder: ByteOrder,
        arrayName: String
    ) throws {
        switch self {
        case .uInt32:
            guard value <= Int(UInt32.max) else {
                throw VTKWriter.Error.binaryPayloadTooLarge(
                    arrayName: arrayName,
                    headerType: rawValue,
                    payloadByteCount: value
                )
            }
            data.appendInteger(UInt32(value), byteOrder: byteOrder)
        case .uInt64:
            data.appendInteger(UInt64(value), byteOrder: byteOrder)
        }
    }
}

extension Data {
    mutating func appendScalar<T>(_ value: T) {
        var value = value
        Swift.withUnsafeBytes(of: &value) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendInteger<T: FixedWidthInteger>(_ value: T, byteOrder: ByteOrder) {
        let endianValue = switch byteOrder {
        case .littleEndian:
            value.littleEndian
        case .bigEndian:
            value.bigEndian
        }

        appendScalar(endianValue)
    }

    mutating func appendFloat32(_ value: Float32, byteOrder: ByteOrder) {
        appendInteger(value.bitPattern, byteOrder: byteOrder)
    }

    mutating func appendFloat64(_ value: Float64, byteOrder: ByteOrder) {
        appendInteger(value.bitPattern, byteOrder: byteOrder)
    }

    func byteSwapped(elementWidth: Int) -> Data {
        guard elementWidth > 1, isEmpty == false else {
            return self
        }

        var swapped = Data(count: count)
        withUnsafeBytes { sourceBytes in
            swapped.withUnsafeMutableBytes { destinationBytes in
                let source = sourceBytes.bindMemory(to: UInt8.self)
                let destination = destinationBytes.bindMemory(to: UInt8.self)

                for offset in stride(from: 0, to: count, by: elementWidth) {
                    for index in 0..<elementWidth {
                        destination[offset + index] = source[offset + (elementWidth - index - 1)]
                    }
                }
            }
        }
        return swapped
    }

    func decodedInteger<T: FixedWidthInteger>(
        at byteOffset: Int,
        as type: T.Type,
        byteOrder: ByteOrder
    ) -> T {
        var rawValue: T = 0
        _ = Swift.withUnsafeMutableBytes(of: &rawValue) { destination in
            copyBytes(to: destination, from: byteOffset..<(byteOffset + MemoryLayout<T>.size))
        }
        return switch byteOrder {
        case .littleEndian:
            T(littleEndian: rawValue)
        case .bigEndian:
            T(bigEndian: rawValue)
        }
    }
}

private extension Array where Element == String {
    mutating func appendDecodedIntegers<T: FixedWidthInteger & CustomStringConvertible>(
        from storage: DataArrayBinaryStorage,
        as type: T.Type,
        arrayName: String
    ) throws {
        reserveCapacity(count + storage.valueCount)
        for byteOffset in stride(from: 0, to: storage.data.count, by: MemoryLayout<T>.size) {
            let value = storage.data.decodedInteger(
                at: byteOffset,
                as: T.self,
                byteOrder: storage.byteOrder
            )
            append(String(value))
        }
    }

    mutating func appendDecodedFloat32s(
        from storage: DataArrayBinaryStorage,
        arrayName: String
    ) throws {
        reserveCapacity(count + storage.valueCount)
        for byteOffset in stride(from: 0, to: storage.data.count, by: MemoryLayout<UInt32>.size) {
            let value = storage.data.decodedInteger(
                at: byteOffset,
                as: UInt32.self,
                byteOrder: storage.byteOrder
            )
            append(String(Float32(bitPattern: value)))
        }
    }

    mutating func appendDecodedFloat64s(
        from storage: DataArrayBinaryStorage,
        arrayName: String
    ) throws {
        reserveCapacity(count + storage.valueCount)
        for byteOffset in stride(from: 0, to: storage.data.count, by: MemoryLayout<UInt64>.size) {
            let value = storage.data.decodedInteger(
                at: byteOffset,
                as: UInt64.self,
                byteOrder: storage.byteOrder
            )
            append(String(Float64(bitPattern: value)))
        }
    }
}
