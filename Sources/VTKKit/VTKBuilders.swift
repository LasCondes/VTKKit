import Foundation

public protocol VTKScalarValue: LosslessStringConvertible, Sendable {
    static var vtkScalarType: VTKScalarType { get }
}

public protocol VTKIntegerScalarValue: VTKScalarValue, FixedWidthInteger {}
public protocol VTKFloatingPointScalarValue: VTKScalarValue, BinaryFloatingPoint {}

extension Int8: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .int8 } }
extension UInt8: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .uint8 } }
extension Int16: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .int16 } }
extension UInt16: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .uint16 } }
extension Int32: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .int32 } }
extension UInt32: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .uint32 } }
extension Int64: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .int64 } }
extension UInt64: VTKIntegerScalarValue { public static var vtkScalarType: VTKScalarType { .uint64 } }
extension Float: VTKFloatingPointScalarValue { public static var vtkScalarType: VTKScalarType { .float32 } }
extension Double: VTKFloatingPointScalarValue { public static var vtkScalarType: VTKScalarType { .float64 } }

public extension DataArray {
    init<Scalar: VTKScalarValue>(
        name: String,
        format: DataArrayFormat = .ascii,
        numberOfComponents: Int,
        values: [Scalar]
    ) throws {
        if format == .ascii {
            self.init(
                uncheckedType: Scalar.vtkScalarType.rawValue,
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                values: values
            )
        } else {
            self.init(
                uncheckedType: Scalar.vtkScalarType.rawValue,
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                binaryStorage: .init(values: values)
            )
        }
        try validateComponentCount(at: name)
    }

    init<Scalar: VTKScalarValue>(
        name: String,
        format: DataArrayFormat = .appended,
        numberOfComponents: Int,
        contiguousValues: ContiguousArray<Scalar>
    ) throws {
        if format == .ascii {
            try self.init(
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                values: Array(contiguousValues)
            )
        } else {
            self.init(
                uncheckedType: Scalar.vtkScalarType.rawValue,
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                binaryStorage: .init(contiguousValues: contiguousValues)
            )
            try validateComponentCount(at: name)
        }
    }

    init<Scalar: VTKScalarValue>(
        name: String,
        format: DataArrayFormat = .appended,
        numberOfComponents: Int,
        buffer: UnsafeBufferPointer<Scalar>
    ) throws {
        if format == .ascii {
            try self.init(
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                values: Array(buffer)
            )
        } else {
            self.init(
                uncheckedType: Scalar.vtkScalarType.rawValue,
                name: name,
                format: format,
                numberOfComponents: numberOfComponents,
                binaryStorage: .init(buffer: buffer)
            )
            try validateComponentCount(at: name)
        }
    }

    init<Scalar: VTKScalarValue>(
        name: String,
        format: DataArrayFormat = .appended,
        numberOfComponents: Int,
        scalarType: Scalar.Type,
        data: Data,
        valueCount: Int,
        byteOrder: ByteOrder = .native
    ) throws {
        self.init(
            uncheckedType: scalarType.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: numberOfComponents,
            binaryStorage: .init(data: data, valueCount: valueCount, byteOrder: byteOrder)
        )
        try validateComponentCount(at: name)
    }

    static func points<Scalar: VTKFloatingPointScalarValue>(
        _ values: [Scalar],
        format: DataArrayFormat = .ascii
    ) throws -> DataArray {
        try DataArray(
            name: "Points",
            format: format,
            numberOfComponents: 3,
            values: values
        )
    }

    static func points<Scalar: VTKFloatingPointScalarValue>(
        contiguousValues: ContiguousArray<Scalar>,
        format: DataArrayFormat = .appended
    ) throws -> DataArray {
        try DataArray(
            name: "Points",
            format: format,
            numberOfComponents: 3,
            contiguousValues: contiguousValues
        )
    }

    static func points<Scalar: VTKFloatingPointScalarValue>(
        buffer: UnsafeBufferPointer<Scalar>,
        format: DataArrayFormat = .appended
    ) throws -> DataArray {
        try DataArray(
            name: "Points",
            format: format,
            numberOfComponents: 3,
            buffer: buffer
        )
    }

    static func scalars<Scalar: VTKScalarValue>(
        name: String,
        values: [Scalar],
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            values: values
        )
    }

    static func scalars<Scalar: VTKScalarValue>(
        name: String,
        contiguousValues: ContiguousArray<Scalar>,
        format: DataArrayFormat = .appended
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            binaryStorage: .init(contiguousValues: contiguousValues)
        )
    }

    static func scalars<Scalar: VTKScalarValue>(
        name: String,
        buffer: UnsafeBufferPointer<Scalar>,
        format: DataArrayFormat = .appended
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            binaryStorage: .init(buffer: buffer)
        )
    }

    static func vectors<Scalar: VTKScalarValue>(
        name: String,
        values: [Scalar],
        format: DataArrayFormat = .ascii
    ) throws -> DataArray {
        try DataArray(
            name: name,
            format: format,
            numberOfComponents: 3,
            values: values
        )
    }

    static func vectors<Scalar: VTKScalarValue>(
        name: String,
        contiguousValues: ContiguousArray<Scalar>,
        format: DataArrayFormat = .appended
    ) throws -> DataArray {
        try DataArray(
            name: name,
            format: format,
            numberOfComponents: 3,
            contiguousValues: contiguousValues
        )
    }

    static func vectors<Scalar: VTKScalarValue>(
        name: String,
        buffer: UnsafeBufferPointer<Scalar>,
        format: DataArrayFormat = .appended
    ) throws -> DataArray {
        try DataArray(
            name: name,
            format: format,
            numberOfComponents: 3,
            buffer: buffer
        )
    }

    static func indices<Scalar: VTKIntegerScalarValue>(
        name: String,
        values: [Scalar],
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            values: values
        )
    }

    static func indices<Scalar: VTKIntegerScalarValue>(
        name: String,
        contiguousValues: ContiguousArray<Scalar>,
        format: DataArrayFormat = .appended
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            binaryStorage: .init(contiguousValues: contiguousValues)
        )
    }

    static func indices<Scalar: VTKIntegerScalarValue>(
        name: String,
        buffer: UnsafeBufferPointer<Scalar>,
        format: DataArrayFormat = .appended
    ) -> DataArray {
        DataArray(
            uncheckedType: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            binaryStorage: .init(buffer: buffer)
        )
    }

    static func timeValue<Scalar: VTKFloatingPointScalarValue>(
        _ value: Scalar,
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        scalars(name: "TimeValue", values: [value], format: format)
    }
}

public extension FieldData {
    static func timeValue<Scalar: VTKFloatingPointScalarValue>(
        _ value: Scalar,
        format: DataArrayFormat = .ascii
    ) -> FieldData {
        FieldData(dataArray: [.timeValue(value, format: format)])
    }
}

public extension PolyData {
    func withTimeValue<Scalar: VTKFloatingPointScalarValue>(
        _ value: Scalar,
        format: DataArrayFormat = .ascii
    ) -> PolyData {
        var copy = self
        copy.fieldData = .timeValue(value, format: format)
        return copy
    }

    static func pointCloud<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws -> PolyData {
        try pointCloud(
            points: points,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: Int32.self
        )
    }

    static func pointCloud<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> PolyData {
        let datasetPath = "PolyData.pointCloud"
        guard points.count.isMultiple(of: 3) else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: "Points",
                datasetPath: datasetPath,
                valueCount: points.count,
                numberOfComponents: 3
            )
        }

        let pointCount = points.count / 3
        let connectivity: [IndexScalar] = try (0..<pointCount).map {
            try exactInteger($0, as: IndexScalar.self, datasetPath: datasetPath + "/Verts/connectivity")
        }
        let offsets: [IndexScalar] = try (1...pointCount).map {
            try exactInteger($0, as: IndexScalar.self, datasetPath: datasetPath + "/Verts/offsets")
        }

        return PolyData(
            piece: Piece(
                numberOfPoints: pointCount,
                numberOfVerts: pointCount,
                points: Points(dataArray: try .points(points, format: format)),
                pointData: pointData,
                verts: Verts(
                    dataArray: [
                        .indices(name: "connectivity", values: connectivity, format: format),
                        .indices(name: "offsets", values: offsets, format: format),
                    ]
                )
            ),
            fieldData: fieldData
        )
    }

    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        triangleIndices: [Int32],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws -> PolyData {
        try triangleMesh(
            points: points,
            triangleIndices: triangleIndices,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: Int32.self
        )
    }

    static func triangleMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        triangleIndices: [IndexScalar],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> PolyData {
        let datasetPath = "PolyData.triangleMesh"
        guard points.count.isMultiple(of: 3) else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: "Points",
                datasetPath: datasetPath,
                valueCount: points.count,
                numberOfComponents: 3
            )
        }

        guard triangleIndices.count.isMultiple(of: 3) else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath + "/Polys",
                reason: "Triangle connectivity count \(triangleIndices.count) is not divisible by 3."
            )
        }

        let triangleCount = triangleIndices.count / 3
        let offsets: [IndexScalar] = try (1...triangleCount).map {
            try exactInteger($0 * 3, as: IndexScalar.self, datasetPath: datasetPath + "/Polys/offsets")
        }

        return PolyData(
            piece: Piece(
                numberOfPoints: points.count / 3,
                numberOfPolys: triangleCount,
                points: Points(dataArray: try .points(points, format: format)),
                pointData: pointData,
                polys: Polys(
                    dataArray: [
                        .indices(name: "connectivity", values: triangleIndices, format: format),
                        .indices(name: "offsets", values: offsets, format: format),
                    ]
                )
            ),
            fieldData: fieldData
        )
    }

    static func polygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws -> PolyData {
        try polygonMesh(
            points: points,
            polygons: polygons,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: Int32.self
        )
    }

    static func polygonMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        polygons: [[IndexScalar]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> PolyData {
        let datasetPath = "PolyData.polygonMesh"
        guard points.count.isMultiple(of: 3) else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: "Points",
                datasetPath: datasetPath,
                valueCount: points.count,
                numberOfComponents: 3
            )
        }

        let flattenedPolygons = try flattenedPolygonConnectivity(
            polygons: polygons,
            datasetPath: datasetPath + "/Polys"
        )

        return PolyData(
            piece: Piece(
                numberOfPoints: points.count / 3,
                numberOfPolys: polygons.count,
                points: Points(dataArray: try .points(points, format: format)),
                pointData: pointData,
                polys: Polys(
                    dataArray: [
                        .indices(name: "connectivity", values: flattenedPolygons.connectivity, format: format),
                        .indices(name: "offsets", values: flattenedPolygons.offsets, format: format),
                    ]
                )
            ),
            fieldData: fieldData
        )
    }

    static func polygonMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        polygonIndices: [IndexScalar],
        polygonVertexCounts: [Int],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> PolyData {
        try polygonMesh(
            points: points,
            polygons: try regroupPolygons(
                connectivity: polygonIndices,
                polygonVertexCounts: polygonVertexCounts,
                datasetPath: "PolyData.polygonMesh/Polys"
            ),
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: indexType
        )
    }

    static func triangulatedPolygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        strategy: PolygonTriangulationStrategy = .fan
    ) throws -> PolyData {
        try triangulatedPolygonMesh(
            points: points,
            polygons: polygons,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: Int32.self,
            strategy: strategy
        )
    }

    static func triangulatedPolygonMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        polygons: [[IndexScalar]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type,
        strategy: PolygonTriangulationStrategy = .fan
    ) throws -> PolyData {
        let triangles = try triangulatedPolygons(
            polygons: polygons,
            points: points,
            strategy: strategy,
            datasetPath: "PolyData.triangulatedPolygonMesh/Polys"
        )
        return try triangleMesh(
            points: points,
            triangleIndices: triangles,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: indexType
        )
    }

    static func robustTriangulatedPolygonMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        polygons: [[Int32]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws -> PolyData {
        try triangulatedPolygonMesh(
            points: points,
            polygons: polygons,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            strategy: .earClipping
        )
    }

    static func robustTriangulatedPolygonMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        polygons: [[IndexScalar]],
        pointData: PointData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> PolyData {
        try triangulatedPolygonMesh(
            points: points,
            polygons: polygons,
            pointData: pointData,
            fieldData: fieldData,
            format: format,
            indexType: indexType,
            strategy: .earClipping
        )
    }
}

public extension Cells {
    static func polyhedra<IndexScalar: VTKIntegerScalarValue>(
        _ cells: [[[IndexScalar]]],
        format: DataArrayFormat = .ascii
    ) throws -> Cells {
        let encodedCells = try encodePolyhedronCells(cells, datasetPath: "UnstructuredGrid.polyhedronMesh/Cells")
        return Cells(
            dataArray: [
                .indices(name: "connectivity", values: encodedCells.connectivity, format: format),
                .indices(name: "offsets", values: encodedCells.offsets, format: format),
                .cellTypes(Array(repeating: .polyhedron, count: cells.count), format: format),
                .indices(name: "faces", values: encodedCells.faces, format: format),
                .indices(name: "faceoffsets", values: encodedCells.faceOffsets, format: format),
            ]
        )
    }
}

public extension UnstructuredGrid {
    static func polyhedronMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar],
        cells: [[[Int32]]],
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws -> UnstructuredGrid {
        try polyhedronMesh(
            points: points,
            cells: cells,
            pointData: pointData,
            cellData: cellData,
            fieldData: fieldData,
            format: format,
            indexType: Int32.self
        )
    }

    static func polyhedronMesh<
        PointScalar: VTKFloatingPointScalarValue,
        IndexScalar: VTKIntegerScalarValue
    >(
        points: [PointScalar],
        cells: [[[IndexScalar]]],
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type
    ) throws -> UnstructuredGrid {
        let datasetPath = "UnstructuredGrid.polyhedronMesh"
        guard points.count.isMultiple(of: 3) else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: "Points",
                datasetPath: datasetPath,
                valueCount: points.count,
                numberOfComponents: 3
            )
        }

        return UnstructuredGrid(
            piece: UnstructuredPiece(
                numberOfPoints: points.count / 3,
                numberOfCells: cells.count,
                points: Points(dataArray: try .points(points, format: format)),
                cells: try .polyhedra(cells, format: format),
                pointData: pointData,
                cellData: cellData
            ),
            fieldData: fieldData
        )
    }
}

public extension PVDFile {
    struct SeriesGroup: Sendable, Equatable, Codable {
        public var group: String
        public var part: Int
        public var files: [String]
        public var timesteps: [Double]

        public init(
            group: String,
            files: [String],
            timesteps: [Double],
            part: Int = 1
        ) {
            self.group = group
            self.files = files
            self.timesteps = timesteps
            self.part = part
        }
    }

    static func series(
        files: [String],
        timesteps: [Double],
        group: String = "default",
        part: Int = 1
    ) throws -> PVDFile {
        guard files.count == timesteps.count else {
            throw VTKWriter.Error.invalidSeriesDefinition(
                reason: "files.count (\(files.count)) must match timesteps.count (\(timesteps.count))."
            )
        }

        return PVDFile(
            collection: .init(
                dataSet: zip(files, timesteps).map { file, timestep in
                    PVDDataSet(group: group, file: file, timestep: timestep, part: part)
                }
            )
        )
    }

    static func series(groups: [SeriesGroup]) throws -> PVDFile {
        var indexedSeries: [(groupIndex: Int, itemIndex: Int, dataSet: PVDDataSet)] = []

        for (groupIndex, group) in groups.enumerated() {
            guard group.files.count == group.timesteps.count else {
                throw VTKWriter.Error.invalidSeriesDefinition(
                    reason: "files.count (\(group.files.count)) must match timesteps.count (\(group.timesteps.count)) for group '\(group.group)'."
                )
            }

            indexedSeries.append(
                contentsOf: zip(group.files, group.timesteps).enumerated().map { itemIndex, pair in
                    let (file, timestep) = pair
                    return (
                        groupIndex: groupIndex,
                        itemIndex: itemIndex,
                        dataSet: PVDDataSet(
                            group: group.group,
                            file: file,
                            timestep: timestep,
                            part: group.part
                        )
                    )
                }
            )
        }

        let sortedDataSets = indexedSeries
            .sorted { lhs, rhs in
                if lhs.dataSet.timestep != rhs.dataSet.timestep {
                    return lhs.dataSet.timestep < rhs.dataSet.timestep
                }
                if lhs.groupIndex != rhs.groupIndex {
                    return lhs.groupIndex < rhs.groupIndex
                }
                return lhs.itemIndex < rhs.itemIndex
            }
            .map(\.dataSet)

        return PVDFile(collection: .init(dataSet: sortedDataSets))
    }
}

extension PolyData {
    func validate(at datasetPath: String) throws {
        try fieldData?.validate(at: datasetPath + "/FieldData")
        try piece.validate(at: datasetPath + "/Piece")
    }
}

extension FieldData {
    func validate(at datasetPath: String) throws {
        for array in dataArray {
            _ = try array.validatedTupleCount(at: datasetPath)
        }
    }
}

extension Piece {
    func validate(at datasetPath: String) throws {
        let pointTupleCount = try points.validate(
            expectedPointCount: numberOfPoints,
            datasetPath: datasetPath + "/Points"
        )

        try pointData?.validate(
            expectedTupleCount: pointTupleCount,
            datasetPath: datasetPath + "/PointData"
        )
        try polys?.validate(
            expectedCellCount: numberOfPolys,
            datasetPath: datasetPath + "/Polys"
        )
        try verts?.validate(
            expectedCellCount: numberOfVerts,
            datasetPath: datasetPath + "/Verts"
        )
    }
}

extension Points {
    @discardableResult
    func validate(expectedPointCount: Int, datasetPath: String) throws -> Int {
        guard dataArray.numberOfComponents == 3 else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: dataArray.name,
                datasetPath: datasetPath,
                valueCount: dataArray.rawValueCount,
                numberOfComponents: 3
            )
        }

        let tupleCount = try dataArray.validatedTupleCount(at: datasetPath)
        guard tupleCount == expectedPointCount else {
            throw VTKWriter.Error.invalidTupleCount(
                arrayName: dataArray.name,
                datasetPath: datasetPath,
                expectedTupleCount: expectedPointCount,
                actualTupleCount: tupleCount
            )
        }

        return tupleCount
    }
}

extension PointData {
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

extension Polys {
    func validate(expectedCellCount: Int, datasetPath: String) throws {
        try validateCellTopology(expectedCellCount: expectedCellCount, datasetPath: datasetPath)
    }
}

extension Verts {
    func validate(expectedCellCount: Int, datasetPath: String) throws {
        try validateCellTopology(expectedCellCount: expectedCellCount, datasetPath: datasetPath)
    }
}

private protocol VTKCellTopologyValidating {
    var dataArray: [DataArray] { get }
}

extension Polys: VTKCellTopologyValidating {}
extension Verts: VTKCellTopologyValidating {}

private extension VTKCellTopologyValidating {
    func validateCellTopology(expectedCellCount: Int, datasetPath: String) throws {
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

        let connectivityTupleCount = try connectivity.validatedTupleCount(at: datasetPath)
        let offsetTupleCount = try offsets.validatedTupleCount(at: datasetPath)
        guard offsetTupleCount == expectedCellCount else {
            throw VTKWriter.Error.invalidTupleCount(
                arrayName: offsets.name,
                datasetPath: datasetPath,
                expectedTupleCount: expectedCellCount,
                actualTupleCount: offsetTupleCount
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
    }
}

extension DataArray {
    var rawValueCount: Int {
        if let binaryStorage {
            return binaryStorage.valueCount
        }
        return values.split(whereSeparator: \.isWhitespace).count
    }

    func validateComponentCount(at datasetPath: String) throws {
        _ = try validatedTupleCount(at: datasetPath)
    }

    func validatedTupleCount(at datasetPath: String) throws -> Int {
        guard let numberOfComponents else {
            return rawValueCount
        }

        guard numberOfComponents > 0 else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: name,
                datasetPath: datasetPath,
                valueCount: rawValueCount,
                numberOfComponents: numberOfComponents
            )
        }

        guard rawValueCount.isMultiple(of: numberOfComponents) else {
            throw VTKWriter.Error.invalidComponentCount(
                arrayName: name,
                datasetPath: datasetPath,
                valueCount: rawValueCount,
                numberOfComponents: numberOfComponents
            )
        }

        return rawValueCount / numberOfComponents
    }

    func integerValues(at datasetPath: String) throws -> [Int] {
        if let binaryStorage {
            guard let scalarType = VTKScalarType(rawValue: type) else {
                throw VTKWriter.Error.unsupportedDataArrayType(arrayName: name, type: type)
            }

            let renderedValues = try scalarType.renderedASCIIValues(
                from: binaryStorage,
                arrayName: name
            )
            return try renderedValues.split(whereSeparator: \.isWhitespace).map { token in
                guard let value = Int(token) else {
                    throw VTKWriter.Error.invalidCellLayout(
                        datasetPath: datasetPath,
                        reason: "Array '\(name)' contains non-integer token '\(token)'."
                    )
                }
                return value
            }
        }

        return try values.split(whereSeparator: \.isWhitespace).map { token in
            guard let value = Int(token) else {
                throw VTKWriter.Error.invalidCellLayout(
                    datasetPath: datasetPath,
                    reason: "Array '\(name)' contains non-integer token '\(token)'."
                )
            }
            return value
        }
    }
}

private func exactInteger<Scalar: VTKIntegerScalarValue>(
    _ value: Int,
    as type: Scalar.Type,
    datasetPath: String
) throws -> Scalar {
    guard let converted = Scalar(exactly: value) else {
        throw VTKWriter.Error.numericOverflow(
            datasetPath: datasetPath,
            value: value,
            targetType: Scalar.vtkScalarType.rawValue
        )
    }

    return converted
}

private func flattenedPolygonConnectivity<IndexScalar: VTKIntegerScalarValue>(
    polygons: [[IndexScalar]],
    datasetPath: String
) throws -> (connectivity: [IndexScalar], offsets: [IndexScalar]) {
    guard polygons.isEmpty == false else {
        return ([], [])
    }

    var connectivity: [IndexScalar] = []
    connectivity.reserveCapacity(polygons.reduce(into: 0) { $0 += $1.count })

    var offsets: [IndexScalar] = []
    offsets.reserveCapacity(polygons.count)

    var runningOffset = 0
    for polygon in polygons {
        guard polygon.count >= 3 else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Each polygon must contain at least 3 vertices."
            )
        }

        connectivity.append(contentsOf: polygon)
        runningOffset += polygon.count
        offsets.append(try exactInteger(runningOffset, as: IndexScalar.self, datasetPath: datasetPath + "/offsets"))
    }

    return (connectivity, offsets)
}

private func regroupPolygons<IndexScalar: VTKIntegerScalarValue>(
    connectivity: [IndexScalar],
    polygonVertexCounts: [Int],
    datasetPath: String
) throws -> [[IndexScalar]] {
    var polygons: [[IndexScalar]] = []
    polygons.reserveCapacity(polygonVertexCounts.count)

    var cursor = 0
    for count in polygonVertexCounts {
        guard count >= 3 else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Each polygon must contain at least 3 vertices."
            )
        }

        let upperBound = cursor + count
        guard upperBound <= connectivity.count else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Polygon connectivity ended before all vertices were consumed."
            )
        }

        polygons.append(Array(connectivity[cursor..<upperBound]))
        cursor = upperBound
    }

    guard cursor == connectivity.count else {
        throw VTKWriter.Error.invalidCellLayout(
            datasetPath: datasetPath,
            reason: "Polygon connectivity contains trailing vertices beyond the supplied polygon counts."
        )
    }

    return polygons
}

private func triangulatedPolygons<
    PointScalar: VTKFloatingPointScalarValue,
    IndexScalar: VTKIntegerScalarValue
>(
    polygons: [[IndexScalar]],
    points: [PointScalar],
    strategy: PolygonTriangulationStrategy,
    datasetPath: String
) throws -> [IndexScalar] {
    if strategy == .fan {
        return try fanTriangulatedPolygons(
            polygons: polygons,
            datasetPath: datasetPath
        )
    }

    return try earClippedPolygons(
        polygons: polygons,
        points: points,
        datasetPath: datasetPath
    )
}

private func fanTriangulatedPolygons<IndexScalar: VTKIntegerScalarValue>(
    polygons: [[IndexScalar]],
    datasetPath: String
) throws -> [IndexScalar] {
    var triangles: [IndexScalar] = []
    triangles.reserveCapacity(polygons.reduce(into: 0) { $0 += max(0, ($1.count - 2) * 3) })

    for polygon in polygons {
        guard polygon.count >= 3 else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Each polygon must contain at least 3 vertices."
            )
        }

        guard let firstVertex = polygon.first else {
            continue
        }

        for index in 1..<(polygon.count - 1) {
            triangles.append(firstVertex)
            triangles.append(polygon[index])
            triangles.append(polygon[index + 1])
        }
    }

    return triangles
}

private func encodePolyhedronCells<IndexScalar: VTKIntegerScalarValue>(
    _ cells: [[[IndexScalar]]],
    datasetPath: String
) throws -> (
    connectivity: [IndexScalar],
    offsets: [IndexScalar],
    faces: [IndexScalar],
    faceOffsets: [IndexScalar]
) {
    var connectivity: [IndexScalar] = []
    var offsets: [IndexScalar] = []
    var faces: [IndexScalar] = []
    var faceOffsets: [IndexScalar] = []

    offsets.reserveCapacity(cells.count)
    faceOffsets.reserveCapacity(cells.count)

    var runningConnectivityOffset = 0
    var runningFaceOffset = 0

    for (cellIndex, cellFaces) in cells.enumerated() {
        guard cellFaces.isEmpty == false else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Polyhedron cell \(cellIndex) must contain at least one face."
            )
        }

        var uniqueVertices: [IndexScalar] = []
        uniqueVertices.reserveCapacity(cellFaces.reduce(into: 0) { $0 += $1.count })

        for face in cellFaces {
            guard face.count >= 3 else {
                throw VTKWriter.Error.invalidCellLayout(
                    datasetPath: datasetPath,
                    reason: "Each polyhedron face must contain at least 3 vertices."
                )
            }

            for vertex in face where uniqueVertices.contains(vertex) == false {
                uniqueVertices.append(vertex)
            }
        }

        connectivity.append(contentsOf: uniqueVertices)
        runningConnectivityOffset += uniqueVertices.count
        offsets.append(
            try exactInteger(
                runningConnectivityOffset,
                as: IndexScalar.self,
                datasetPath: datasetPath + "/offsets"
            )
        )

        faces.append(
            try exactInteger(
                cellFaces.count,
                as: IndexScalar.self,
                datasetPath: datasetPath + "/faces"
            )
        )

        for face in cellFaces {
            faces.append(
                try exactInteger(
                    face.count,
                    as: IndexScalar.self,
                    datasetPath: datasetPath + "/faces"
                )
            )
            faces.append(contentsOf: face)
        }

        runningFaceOffset = faces.count
        faceOffsets.append(
            try exactInteger(
                runningFaceOffset,
                as: IndexScalar.self,
                datasetPath: datasetPath + "/faceoffsets"
            )
        )
    }

    return (connectivity, offsets, faces, faceOffsets)
}
