import Foundation

public struct PVDDataSet: Sendable, Equatable, Codable {
    public var timestep: Double
    public var group: String
    public var part: Int
    public var file: String

    public init(group: String, file: String, timestep: Double, part: Int = 1) {
        self.group = group
        self.file = file
        self.part = part
        self.timestep = timestep
    }
}

public struct PVDFile: Sendable, Equatable, Codable {
    public struct Collection: Sendable, Equatable, Codable {
        public var dataSet: [PVDDataSet]

        public init(dataSet: [PVDDataSet]) {
            self.dataSet = dataSet
        }
    }

    public var collection: Collection

    public init(collection: Collection) {
        self.collection = collection
    }
}

extension PVDFile: XMLDocumentRenderable {
    func renderXML(into xml: inout String) throws(VTKWriter.Error) {
        XMLTag.open(
            "VTKFile",
            attributes: [
                ("type", "Collection"),
                ("version", "0.1"),
                ("byte_order", "LittleEndian"),
            ],
            into: &xml,
            indentLevel: 0
        )

        XMLTag.open("Collection", into: &xml, indentLevel: 1)
        for dataSet in collection.dataSet {
            XMLTag.leaf(
                "DataSet",
                attributes: [
                    ("timestep", String(dataSet.timestep)),
                    ("group", dataSet.group),
                    ("part", String(dataSet.part)),
                    ("file", dataSet.file),
                ],
                into: &xml,
                indentLevel: 2
            )
        }
        XMLTag.close("Collection", into: &xml, indentLevel: 1)
        XMLTag.close("VTKFile", into: &xml, indentLevel: 0)
    }
}
