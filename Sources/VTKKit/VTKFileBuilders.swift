import Foundation

public struct VTKXMLFileOptions: Sendable, Equatable, Codable {
    public var version: String
    public var byteOrder: ByteOrder
    public var headerType: BinaryDataHeaderType
    public var compression: VTKCompression?
    public var dataArrayFormat: DataArrayFormat

    public init(
        version: String = "0.1",
        byteOrder: ByteOrder = .littleEndian,
        headerType: BinaryDataHeaderType = .uInt32,
        compression: VTKCompression? = nil,
        dataArrayFormat: DataArrayFormat = .ascii
    ) {
        self.version = version
        self.byteOrder = byteOrder
        self.headerType = headerType
        self.compression = compression
        self.dataArrayFormat = dataArrayFormat
    }
}

public extension VTKFile {
    init(polyData: PolyData, options: VTKXMLFileOptions) {
        self.init(
            polyData: polyData,
            version: options.version,
            byteOrder: options.byteOrder,
            headerType: options.headerType,
            compression: options.compression
        )
    }

    static func pointCloud<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws -> VTKFile {
        VTKFile(
            polyData: try PolyData.pointCloud(
                points: points,
                pointData: pointData,
                fieldData: fieldData,
                format: options.dataArrayFormat
            ),
            options: options
        )
    }

    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        triangleIndices: [Int32],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws -> VTKFile {
        VTKFile(
            polyData: try PolyData.triangleMesh(
                points: points,
                triangleIndices: triangleIndices,
                pointData: pointData,
                fieldData: fieldData,
                format: options.dataArrayFormat
            ),
            options: options
        )
    }

    static func polygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws -> VTKFile {
        VTKFile(
            polyData: try PolyData.polygonMesh(
                points: points,
                polygons: polygons,
                pointData: pointData,
                fieldData: fieldData,
                format: options.dataArrayFormat
            ),
            options: options
        )
    }

    static func triangulatedPolygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init(),
        strategy: PolygonTriangulationStrategy = .fan
    ) throws -> VTKFile {
        VTKFile(
            polyData: try PolyData.triangulatedPolygonMesh(
                points: points,
                polygons: polygons,
                pointData: pointData,
                fieldData: fieldData,
                format: options.dataArrayFormat,
                strategy: strategy
            ),
            options: options
        )
    }

    static func robustTriangulatedPolygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws -> VTKFile {
        try triangulatedPolygonMesh(
            points: points,
            polygons: polygons,
            pointData: pointData,
            fieldData: fieldData,
            options: options,
            strategy: .earClipping
        )
    }
}

public extension VTUFile {
    init(unstructuredGrid: UnstructuredGrid, options: VTKXMLFileOptions) {
        self.init(
            unstructuredGrid: unstructuredGrid,
            version: options.version,
            byteOrder: options.byteOrder,
            headerType: options.headerType,
            compression: options.compression
        )
    }

    static func polyhedronMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        cells: [[[Int32]]],
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws -> VTUFile {
        VTUFile(
            unstructuredGrid: try UnstructuredGrid.polyhedronMesh(
                points: points,
                cells: cells,
                pointData: pointData,
                cellData: cellData,
                fieldData: fieldData,
                format: options.dataArrayFormat
            ),
            options: options
        )
    }
}

public extension VTKWriter {
    static func writePartitionedPolyData(
        pieces: [PolyData],
        manifestURL: URL,
        pieceFileNames: [String]? = nil,
        ghostLevel: Int = 0,
        options: VTKXMLFileOptions = .init()
    ) throws -> PVTPFile {
        guard let template = pieces.first else {
            throw Error.invalidParallelDefinition(reason: "pieces must contain at least one PolyData dataset.")
        }

        let names = try resolvedPieceFileNames(
            explicitNames: pieceFileNames,
            pieceCount: pieces.count,
            manifestURL: manifestURL,
            extensionName: "vtp"
        )

        let directoryURL = manifestURL.deletingLastPathComponent()
        for (piece, fileName) in zip(pieces, names) {
            try write(VTKFile(polyData: piece, options: options), to: directoryURL.appendingPathComponent(fileName))
        }

        let manifest = try PVTPFile.collection(
            pieceSources: names,
            template: template,
            ghostLevel: ghostLevel,
            version: options.version,
            byteOrder: options.byteOrder
        )
        try write(manifest, to: manifestURL)
        return manifest
    }

    static func writePartitionedUnstructuredGrid(
        pieces: [UnstructuredGrid],
        manifestURL: URL,
        pieceFileNames: [String]? = nil,
        ghostLevel: Int = 0,
        options: VTKXMLFileOptions = .init()
    ) throws -> PVTUFile {
        guard let template = pieces.first else {
            throw Error.invalidParallelDefinition(reason: "pieces must contain at least one UnstructuredGrid dataset.")
        }

        let names = try resolvedPieceFileNames(
            explicitNames: pieceFileNames,
            pieceCount: pieces.count,
            manifestURL: manifestURL,
            extensionName: "vtu"
        )

        let directoryURL = manifestURL.deletingLastPathComponent()
        for (piece, fileName) in zip(pieces, names) {
            try write(VTUFile(unstructuredGrid: piece, options: options), to: directoryURL.appendingPathComponent(fileName))
        }

        let manifest = try PVTUFile.collection(
            pieceSources: names,
            template: template,
            ghostLevel: ghostLevel,
            version: options.version,
            byteOrder: options.byteOrder
        )
        try write(manifest, to: manifestURL)
        return manifest
    }

    private static func resolvedPieceFileNames(
        explicitNames: [String]?,
        pieceCount: Int,
        manifestURL: URL,
        extensionName: String
    ) throws -> [String] {
        if let explicitNames {
            guard explicitNames.count == pieceCount else {
                throw Error.invalidParallelDefinition(
                    reason: "pieceFileNames.count (\(explicitNames.count)) must match pieces.count (\(pieceCount))."
                )
            }
            return explicitNames
        }

        let baseName = manifestURL.deletingPathExtension().lastPathComponent
        return (0..<pieceCount).map { "\(baseName)_piece_\($0).\(extensionName)" }
    }
}
