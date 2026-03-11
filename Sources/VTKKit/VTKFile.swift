import Foundation

public struct VTKFile: Sendable, Equatable {
    public var type: String
    public var version: String
    public var byteOrder: String
    public var polyData: PolyData

    public init(
        polyData: PolyData,
        type: String = "PolyData",
        version: String = "0.1",
        byteOrder: String = "LittleEndian"
    ) {
        self.polyData = polyData
        self.type = type
        self.version = version
        self.byteOrder = byteOrder
    }
}

public struct PolyData: Sendable, Equatable {
    public var piece: Piece

    public init(piece: Piece) {
        self.piece = piece
    }
}

public struct FieldData: Sendable, Equatable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }

    public init(timeValue: DataArray) {
        self.dataArray = [timeValue]
    }
}

public struct Piece: Sendable, Equatable {
    public var numberOfPoints: Int
    public var numberOfVerts: Int
    public var numberOfLines: Int
    public var numberOfStrips: Int
    public var numberOfPolys: Int

    public var fieldData: FieldData?
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
        fieldData: FieldData? = nil,
        verts: Verts? = nil
    ) {
        self.numberOfPoints = numberOfPoints
        self.numberOfVerts = numberOfVerts
        self.numberOfLines = numberOfLines
        self.numberOfStrips = numberOfStrips
        self.numberOfPolys = numberOfPolys
        self.fieldData = fieldData
        self.points = points
        self.pointData = pointData
        self.polys = polys
        self.verts = verts
    }
}

public struct Points: Sendable, Equatable {
    public var dataArray: DataArray

    public init(dataArray: DataArray) {
        self.dataArray = dataArray
    }
}

public struct PointData: Sendable, Equatable {
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

public struct Polys: Sendable, Equatable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }

    public init(connectivity: DataArray, offsets: DataArray) {
        self.dataArray = [connectivity, offsets]
    }
}

public struct Verts: Sendable, Equatable {
    public var dataArray: [DataArray]

    public init(dataArray: [DataArray]) {
        self.dataArray = dataArray
    }
}

public struct DataArray: Sendable, Equatable {
    public var type: String
    public var name: String
    public var format: String
    public var numberOfComponents: Int?
    public var values: String

    public init<Value: LosslessStringConvertible>(
        type: String,
        name: String,
        format: String = "ascii",
        numberOfComponents: Int,
        values: [Value]
    ) {
        self.type = type
        self.name = name
        self.format = format
        self.numberOfComponents = numberOfComponents
        self.values = values.map { String($0) }.joined(separator: " ")
    }

    public init(
        type: String,
        name: String,
        format: String = "ascii",
        numberOfComponents: Int
    ) {
        self.type = type
        self.name = name
        self.format = format
        self.numberOfComponents = numberOfComponents
        self.values = ""
    }
}

extension VTKFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) {
        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", type),
                ("version", version),
                ("byte_order", byteOrder),
            ],
            into: &xml,
            indentLevel: 0
        )
        polyData.renderXML(into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}

extension PolyData {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("PolyData", into: &xml, indentLevel: indentLevel)
        piece.renderXML(into: &xml, indentLevel: indentLevel + 1)
        XMLTag.close("PolyData", into: &xml, indentLevel: indentLevel)
    }
}

extension Piece {
    func renderXML(into xml: inout String, indentLevel: Int) {
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

        fieldData?.renderXML(into: &xml, indentLevel: indentLevel + 1)
        points.renderXML(into: &xml, indentLevel: indentLevel + 1)
        pointData?.renderXML(into: &xml, indentLevel: indentLevel + 1)
        polys?.renderXML(into: &xml, indentLevel: indentLevel + 1)
        verts?.renderXML(into: &xml, indentLevel: indentLevel + 1)

        XMLTag.close("Piece", into: &xml, indentLevel: indentLevel)
    }
}

extension FieldData {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("FieldData", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            element.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("FieldData", into: &xml, indentLevel: indentLevel)
    }
}

extension Points {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("Points", into: &xml, indentLevel: indentLevel)
        dataArray.renderXML(into: &xml, indentLevel: indentLevel + 1)
        XMLTag.close("Points", into: &xml, indentLevel: indentLevel)
    }
}

extension PointData {
    func renderXML(into xml: inout String, indentLevel: Int) {
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
            element.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("PointData", into: &xml, indentLevel: indentLevel)
    }
}

extension Polys {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("Polys", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            element.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("Polys", into: &xml, indentLevel: indentLevel)
    }
}

extension Verts {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("Verts", into: &xml, indentLevel: indentLevel)
        for element in dataArray {
            element.renderXML(into: &xml, indentLevel: indentLevel + 1)
        }
        XMLTag.close("Verts", into: &xml, indentLevel: indentLevel)
    }
}

extension DataArray {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.text(
            "DataArray",
            attributes: [
                ("type", type),
                ("Name", name),
                ("format", format),
                ("NumberOfComponents", numberOfComponents.map(String.init)),
            ],
            text: values,
            into: &xml,
            indentLevel: indentLevel
        )
    }
}

