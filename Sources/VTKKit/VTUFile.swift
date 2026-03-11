import Foundation

public enum VTKCellType: UInt8, Sendable, Codable, CaseIterable {
    case vertex = 1
    case polyVertex = 2
    case line = 3
    case polyLine = 4
    case triangle = 5
    case triangleStrip = 6
    case polygon = 7
    case pixel = 8
    case quad = 9
    case tetra = 10
    case voxel = 11
    case hexahedron = 12
    case wedge = 13
    case pyramid = 14
    case pentagonalPrism = 15
    case hexagonalPrism = 16
    case polyhedron = 42
}

public struct VTUFile: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var headerType: BinaryDataHeaderType
    public var unstructuredGrid: UnstructuredGrid

    public init(
        unstructuredGrid: UnstructuredGrid,
        version: String = "0.1",
        byteOrder: ByteOrder = .littleEndian,
        headerType: BinaryDataHeaderType = .uInt32
    ) {
        self.unstructuredGrid = unstructuredGrid
        self.version = version
        self.byteOrder = byteOrder
        self.headerType = headerType
    }
}

public struct UnstructuredGrid: Sendable, Equatable, Codable {
    public var fieldData: FieldData?
    public var piece: UnstructuredPiece

    public init(piece: UnstructuredPiece, fieldData: FieldData? = nil) {
        self.fieldData = fieldData
        self.piece = piece
    }
}

public struct UnstructuredPiece: Sendable, Equatable, Codable {
    public var numberOfPoints: Int
    public var numberOfCells: Int

    public var points: Points
    public var cells: Cells
    public var pointData: PointData?
    public var cellData: CellData?

    public init(
        numberOfPoints: Int,
        numberOfCells: Int,
        points: Points,
        cells: Cells,
        pointData: PointData? = nil,
        cellData: CellData? = nil
    ) {
        self.numberOfPoints = numberOfPoints
        self.numberOfCells = numberOfCells
        self.points = points
        self.cells = cells
        self.pointData = pointData
        self.cellData = cellData
    }
}

public struct CellData: Sendable, Equatable, Codable {
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

public struct Cells: Sendable, Equatable, Codable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }

    public init(connectivity: DataArray, offsets: DataArray, types: DataArray) {
        self.dataArray = [connectivity, offsets, types]
    }
}

public extension DataArray {
    static func cellTypes(
        _ values: [VTKCellType],
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        .indices(name: "types", values: values.map(\.rawValue), format: format)
    }
}

public extension UnstructuredGrid {
    func withTimeValue<Scalar: VTKFloatingPointScalarValue>(
        _ value: Scalar,
        format: DataArrayFormat = .ascii
    ) -> UnstructuredGrid {
        var copy = self
        copy.fieldData = .timeValue(value, format: format)
        return copy
    }
}

extension VTUFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws {
        try unstructuredGrid.validate(at: "UnstructuredGrid")
        var context = VTKXMLBinaryEncodingContext(
            byteOrder: byteOrder,
            headerType: headerType
        )

        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", "UnstructuredGrid"),
                ("version", version),
                ("byte_order", byteOrder.rawValue),
                ("header_type", unstructuredGrid.usesEncodedData ? headerType.rawValue : nil),
            ],
            into: &xml,
            indentLevel: 0
        )
        try unstructuredGrid.renderXML(into: &xml, indentLevel: 1, context: &context)
        context.renderAppendedData(into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}

extension UnstructuredGrid {
    var usesEncodedData: Bool {
        fieldData?.usesEncodedData == true || piece.usesEncodedData
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("UnstructuredGrid", into: &xml, indentLevel: indentLevel)
        try fieldData?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try piece.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        XMLTag.close("UnstructuredGrid", into: &xml, indentLevel: indentLevel)
    }

    func validate(at datasetPath: String) throws {
        try fieldData?.validate(at: datasetPath + "/FieldData")
        try piece.validate(at: datasetPath + "/Piece")
    }
}

extension UnstructuredPiece {
    var usesEncodedData: Bool {
        points.usesEncodedData
            || cells.usesEncodedData
            || pointData?.usesEncodedData == true
            || cellData?.usesEncodedData == true
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
                ("NumberOfCells", String(numberOfCells)),
            ],
            into: &xml,
            indentLevel: indentLevel
        )

        try pointData?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try cellData?.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try points.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        try cells.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)

        XMLTag.close("Piece", into: &xml, indentLevel: indentLevel)
    }

    func validate(at datasetPath: String) throws {
        let pointTupleCount = try points.validate(
            expectedPointCount: numberOfPoints,
            datasetPath: datasetPath + "/Points"
        )

        try pointData?.validate(
            expectedTupleCount: pointTupleCount,
            datasetPath: datasetPath + "/PointData"
        )
        try cellData?.validate(
            expectedTupleCount: numberOfCells,
            datasetPath: datasetPath + "/CellData"
        )
        try cells.validate(
            expectedCellCount: numberOfCells,
            datasetPath: datasetPath + "/Cells"
        )
    }
}

extension CellData {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open(
            "CellData",
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
        XMLTag.close("CellData", into: &xml, indentLevel: indentLevel)
    }

    func validate(expectedTupleCount: Int, datasetPath: String) throws {
        for array in dataArray {
            let tupleCount = try array.validatedTupleCount(at: datasetPath)
            guard tupleCount == expectedTupleCount else {
                throw VTKWriter.Error.invalidTupleCount(
                    arrayName: array.name,
                    datasetPath: datasetPath,
                    expectedTupleCount: expectedTupleCount,
                    actualTupleCount: tupleCount
                )
            }
        }
    }
}

extension Cells {
    var usesEncodedData: Bool {
        dataArray.contains(where: \.usesEncodedData)
    }

    func renderXML(
        into xml: inout String,
        indentLevel: Int,
        context: inout VTKXMLBinaryEncodingContext
    ) throws {
        XMLTag.open("Cells", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            try element.renderXML(into: &xml, indentLevel: indentLevel + 1, context: &context)
        }
        XMLTag.close("Cells", into: &xml, indentLevel: indentLevel)
    }

    func validate(expectedCellCount: Int, datasetPath: String) throws {
        guard let connectivity = dataArray.first(where: { $0.name == "connectivity" }) else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Missing connectivity array."
            )
        }

        guard let offsets = dataArray.first(where: { $0.name == "offsets" }) else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Missing offsets array."
            )
        }

        guard let types = dataArray.first(where: { $0.name == "types" }) else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Missing types array."
            )
        }

        let connectivityTupleCount = try connectivity.validatedTupleCount(at: datasetPath)
        let offsetTupleCount = try offsets.validatedTupleCount(at: datasetPath)
        let typeTupleCount = try types.validatedTupleCount(at: datasetPath)

        guard offsetTupleCount == expectedCellCount else {
            throw VTKWriter.Error.invalidTupleCount(
                arrayName: offsets.name,
                datasetPath: datasetPath,
                expectedTupleCount: expectedCellCount,
                actualTupleCount: offsetTupleCount
            )
        }

        guard typeTupleCount == expectedCellCount else {
            throw VTKWriter.Error.invalidTupleCount(
                arrayName: types.name,
                datasetPath: datasetPath,
                expectedTupleCount: expectedCellCount,
                actualTupleCount: typeTupleCount
            )
        }

        let offsetValues = try offsets.integerValues(at: datasetPath)
        var previousOffset = 0
        for offset in offsetValues {
            guard offset >= previousOffset else {
                throw VTKWriter.Error.invalidCellLayout(
                    datasetPath: datasetPath,
                    reason: "Offsets must be monotonically increasing."
                )
            }
            previousOffset = offset
        }

        guard offsetValues.last ?? 0 == connectivityTupleCount else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "The final offset \(offsetValues.last ?? 0) must equal connectivity tuple count \(connectivityTupleCount)."
            )
        }

        _ = try types.integerValues(at: datasetPath)
    }
}
