import Foundation

public enum ByteOrder: String, Sendable, Codable {
    case littleEndian = "LittleEndian"
    case bigEndian = "BigEndian"
}

public enum DataArrayFormat: String, Sendable, Codable {
    case ascii
}

public struct VTKFile: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var polyData: PolyData

    public init(
        polyData: PolyData,
        version: String = "0.1",
        byteOrder: ByteOrder = .littleEndian
    ) {
        self.polyData = polyData
        self.version = version
        self.byteOrder = byteOrder
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

    public init<Value: LosslessStringConvertible>(
        type: String,
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
    }

    public init(
        type: String,
        name: String,
        format: DataArrayFormat = .ascii,
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
                ("type", "PolyData"),
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

extension PolyData {
    func renderXML(into xml: inout String, indentLevel: Int) {
        XMLTag.open("PolyData", into: &xml, indentLevel: indentLevel)
        fieldData?.renderXML(into: &xml, indentLevel: indentLevel + 1)
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
                ("format", format.rawValue),
                ("NumberOfComponents", numberOfComponents.map(String.init)),
            ],
            text: values,
            into: &xml,
            indentLevel: indentLevel
        )
    }
}
