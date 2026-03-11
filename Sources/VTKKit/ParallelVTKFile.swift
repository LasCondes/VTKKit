import Foundation

public struct ParallelPiece: Sendable, Equatable, Codable {
    public var source: String

    public init(source: String) {
        self.source = source
    }
}

public struct PDataArray: Sendable, Equatable, Codable {
    public var type: String
    public var name: String?
    public var numberOfComponents: Int?

    public init(type: String, name: String? = nil, numberOfComponents: Int? = nil) {
        self.type = type
        self.name = name
        self.numberOfComponents = numberOfComponents
    }

    init(_ dataArray: DataArray, includeName: Bool = true) {
        self.init(
            type: dataArray.type,
            name: includeName ? dataArray.name : nil,
            numberOfComponents: dataArray.numberOfComponents
        )
    }
}

public struct PPointData: Sendable, Equatable, Codable {
    public var scalarsName: String?
    public var vectorsName: String?
    public var dataArray: [PDataArray]

    public init(
        scalarsName: String? = nil,
        vectorsName: String? = nil,
        dataArray: [PDataArray]
    ) {
        self.scalarsName = scalarsName
        self.vectorsName = vectorsName
        self.dataArray = dataArray
    }

    init(_ pointData: PointData) {
        self.init(
            scalarsName: pointData.scalarsName,
            vectorsName: pointData.vectorsName,
            dataArray: pointData.dataArray.map { PDataArray($0) }
        )
    }
}

public struct PCellData: Sendable, Equatable, Codable {
    public var scalarsName: String?
    public var vectorsName: String?
    public var dataArray: [PDataArray]

    public init(
        scalarsName: String? = nil,
        vectorsName: String? = nil,
        dataArray: [PDataArray]
    ) {
        self.scalarsName = scalarsName
        self.vectorsName = vectorsName
        self.dataArray = dataArray
    }

    init(_ cellData: CellData) {
        self.init(
            scalarsName: cellData.scalarsName,
            vectorsName: cellData.vectorsName,
            dataArray: cellData.dataArray.map { PDataArray($0) }
        )
    }
}

public struct PPoints: Sendable, Equatable, Codable {
    public var dataArray: PDataArray

    public init(dataArray: PDataArray) {
        self.dataArray = dataArray
    }

    init(_ points: Points) {
        self.init(dataArray: PDataArray(points.dataArray, includeName: false))
    }
}

public struct PPolyData: Sendable, Equatable, Codable {
    public var ghostLevel: Int
    public var pointData: PPointData?
    public var points: PPoints
    public var pieces: [ParallelPiece]

    public init(
        ghostLevel: Int = 0,
        pointData: PPointData? = nil,
        points: PPoints,
        pieces: [ParallelPiece]
    ) {
        self.ghostLevel = ghostLevel
        self.pointData = pointData
        self.points = points
        self.pieces = pieces
    }
}

public struct PUnstructuredGrid: Sendable, Equatable, Codable {
    public var ghostLevel: Int
    public var pointData: PPointData?
    public var cellData: PCellData?
    public var points: PPoints
    public var pieces: [ParallelPiece]

    public init(
        ghostLevel: Int = 0,
        pointData: PPointData? = nil,
        cellData: PCellData? = nil,
        points: PPoints,
        pieces: [ParallelPiece]
    ) {
        self.ghostLevel = ghostLevel
        self.pointData = pointData
        self.cellData = cellData
        self.points = points
        self.pieces = pieces
    }
}

public struct PVTPFile: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var polyData: PPolyData

    public init(
        polyData: PPolyData,
        version: String = "0.1",
        byteOrder: ByteOrder = .native
    ) {
        self.version = version
        self.byteOrder = byteOrder
        self.polyData = polyData
    }
}

public struct PVTUFile: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var unstructuredGrid: PUnstructuredGrid

    public init(
        unstructuredGrid: PUnstructuredGrid,
        version: String = "0.1",
        byteOrder: ByteOrder = .native
    ) {
        self.version = version
        self.byteOrder = byteOrder
        self.unstructuredGrid = unstructuredGrid
    }
}

public extension PVTPFile {
    static func collection(
        pieceSources: [String],
        template: PolyData,
        ghostLevel: Int = 0,
        version: String = "0.1",
        byteOrder: ByteOrder = .native
    ) throws(VTKWriter.Error) -> PVTPFile {
        guard pieceSources.isEmpty == false else {
            throw VTKWriter.Error.invalidParallelDefinition(
                reason: "pieceSources must contain at least one .vtp file."
            )
        }

        guard ghostLevel >= 0 else {
            throw VTKWriter.Error.invalidParallelDefinition(
                reason: "GhostLevel must be greater than or equal to zero."
            )
        }

        return PVTPFile(
            polyData: PPolyData(
                ghostLevel: ghostLevel,
                pointData: template.piece.pointData.map(PPointData.init),
                points: PPoints(template.piece.points),
                pieces: pieceSources.map(ParallelPiece.init(source:))
            ),
            version: version,
            byteOrder: byteOrder
        )
    }
}

public extension PVTUFile {
    static func collection(
        pieceSources: [String],
        template: UnstructuredGrid,
        ghostLevel: Int = 0,
        version: String = "0.1",
        byteOrder: ByteOrder = .native
    ) throws(VTKWriter.Error) -> PVTUFile {
        guard pieceSources.isEmpty == false else {
            throw VTKWriter.Error.invalidParallelDefinition(
                reason: "pieceSources must contain at least one .vtu file."
            )
        }

        guard ghostLevel >= 0 else {
            throw VTKWriter.Error.invalidParallelDefinition(
                reason: "GhostLevel must be greater than or equal to zero."
            )
        }

        return PVTUFile(
            unstructuredGrid: PUnstructuredGrid(
                ghostLevel: ghostLevel,
                pointData: template.piece.pointData.map(PPointData.init),
                cellData: template.piece.cellData.map(PCellData.init),
                points: PPoints(template.piece.points),
                pieces: pieceSources.map(ParallelPiece.init(source:))
            ),
            version: version,
            byteOrder: byteOrder
        )
    }
}

extension PVTPFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws(VTKWriter.Error) {
        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", "PPolyData"),
                ("version", version),
                ("byte_order", byteOrder.rawValue),
            ],
            into: &xml,
            indentLevel: 0
        )
        polyData.renderXML(into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}

extension PVTUFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws(VTKWriter.Error) {
        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", "PUnstructuredGrid"),
                ("version", version),
                ("byte_order", byteOrder.rawValue),
            ],
            into: &xml,
            indentLevel: 0
        )
        unstructuredGrid.renderXML(into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}

private extension PPolyData {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open(
            "PPolyData",
            attributes: [("GhostLevel", String(ghostLevel))],
            into: &xml,
            indentLevel: indentLevel
        )
        pointData?.renderXML(tagName: "PPointData", into: &xml, indentLevel: indentLevel + 1)
        points.renderXML(into: &xml, indentLevel: indentLevel + 1)
        for piece in pieces {
            piece.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("PPolyData", into: &xml, indentLevel: indentLevel)
    }
}

private extension PUnstructuredGrid {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open(
            "PUnstructuredGrid",
            attributes: [("GhostLevel", String(ghostLevel))],
            into: &xml,
            indentLevel: indentLevel
        )
        pointData?.renderXML(tagName: "PPointData", into: &xml, indentLevel: indentLevel + 1)
        cellData?.renderXML(tagName: "PCellData", into: &xml, indentLevel: indentLevel + 1)
        points.renderXML(into: &xml, indentLevel: indentLevel + 1)
        for piece in pieces {
            piece.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("PUnstructuredGrid", into: &xml, indentLevel: indentLevel)
    }
}

private extension PPointData {
    func renderXML(tagName: String, into xml: inout String, indentLevel: Int) {
        XMLTag.open(
            tagName,
            attributes: [
                ("Scalars", scalarsName),
                ("Vectors", vectorsName),
            ],
            into: &xml,
            indentLevel: indentLevel
        )
        for array in dataArray {
            array.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close(tagName, into: &xml, indentLevel: indentLevel)
    }
}

private extension PCellData {
    func renderXML(tagName: String, into xml: inout String, indentLevel: Int) {
        XMLTag.open(
            tagName,
            attributes: [
                ("Scalars", scalarsName),
                ("Vectors", vectorsName),
            ],
            into: &xml,
            indentLevel: indentLevel
        )
        for array in dataArray {
            array.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close(tagName, into: &xml, indentLevel: indentLevel)
    }
}

private extension PPoints {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("PPoints", into: &xml, indentLevel: indentLevel)
        dataArray.renderXML(into: &xml, indentLevel: indentLevel + 1)
        XMLTag.close("PPoints", into: &xml, indentLevel: indentLevel)
    }
}

private extension PDataArray {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.leaf(
            "PDataArray",
            attributes: [
                ("type", type),
                ("Name", name),
                ("NumberOfComponents", numberOfComponents.map(String.init)),
            ],
            into: &xml,
            indentLevel: indentLevel
        )
    }
}

private extension ParallelPiece {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.leaf(
            "Piece",
            attributes: [("Source", source)],
            into: &xml,
            indentLevel: indentLevel
        )
    }
}
