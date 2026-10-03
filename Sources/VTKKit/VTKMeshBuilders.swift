import Foundation

/// Controls connectivity ordering without changing the order of cells or their data.
public enum TetrahedronOrientation: String, Sendable, Codable {
    /// Keep the supplied node order, including negatively oriented tetrahedra.
    case preserve
    /// Apply VTK's right-hand rule and reject zero-volume tetrahedra.
    case positive
}

public extension UnstructuredGrid {
    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar], triangleIndices: [Int32], pointData: PointData? = nil,
        cellData: CellData? = nil, fieldData: FieldData? = nil, format: DataArrayFormat = .ascii
    ) throws(VTKWriter.Error) -> UnstructuredGrid {
        try triangleMesh(points: points, triangleIndices: triangleIndices, pointData: pointData,
                         cellData: cellData, fieldData: fieldData, format: format, indexType: Int32.self)
    }

    /// Builds linear triangle cells from interleaved xyz points and flat connectivity.
    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue, IndexScalar: VTKIntegerScalarValue>(
        points: [PointScalar],
        triangleIndices: [IndexScalar],
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type = IndexScalar.self
    ) throws(VTKWriter.Error) -> UnstructuredGrid {
        try linearMesh(points: points, indices: triangleIndices, type: .triangle,
                       nodesPerCell: 3, pointData: pointData, cellData: cellData,
                       fieldData: fieldData, format: format)
    }

    static func tetrahedronMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar], tetrahedronIndices: [Int32], orientation: TetrahedronOrientation = .preserve,
        pointData: PointData? = nil, cellData: CellData? = nil, fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii
    ) throws(VTKWriter.Error) -> UnstructuredGrid {
        try tetrahedronMesh(points: points, tetrahedronIndices: tetrahedronIndices, orientation: orientation,
                            pointData: pointData, cellData: cellData, fieldData: fieldData,
                            format: format, indexType: Int32.self)
    }

    /// Builds linear tetrahedra. Orientation correction only swaps nodes within a cell;
    /// cell-associated arrays keep their original ordering.
    static func tetrahedronMesh<PointScalar: VTKFloatingPointScalarValue, IndexScalar: VTKIntegerScalarValue>(
        points: [PointScalar],
        tetrahedronIndices: [IndexScalar],
        orientation: TetrahedronOrientation = .preserve,
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        format: DataArrayFormat = .ascii,
        indexType: IndexScalar.Type = IndexScalar.self
    ) throws(VTKWriter.Error) -> UnstructuredGrid {
        var grid = try linearMesh(points: points, indices: tetrahedronIndices, type: .tetra,
                                  nodesPerCell: 4, pointData: pointData, cellData: cellData,
                                  fieldData: fieldData, format: format)
        if orientation == .positive {
            var indices = tetrahedronIndices
            func vertex(_ index: IndexScalar) -> SIMD3<Double> {
                let start = Int(index) * 3
                return SIMD3(Double(points[start]), Double(points[start + 1]), Double(points[start + 2]))
            }
            for start in stride(from: 0, to: indices.count, by: 4) {
                // Bounds and integer conversion have already been checked by linearMesh.
                let origin = vertex(indices[start])
                var a = vertex(indices[start + 1]) - origin
                var b = vertex(indices[start + 2]) - origin
                var c = vertex(indices[start + 3]) - origin
                // Normalize edges before the determinant to avoid cubic overflow/underflow
                // for otherwise valid meshes expressed in very large or small units.
                let scale = max(maximumMagnitude(a), maximumMagnitude(b), maximumMagnitude(c))
                guard scale > 0, scale.isFinite else {
                    throw orientationError(cell: start / 4)
                }
                a /= scale
                b /= scale
                c /= scale
                let determinant = a[0] * (b[1] * c[2] - b[2] * c[1])
                    - a[1] * (b[0] * c[2] - b[2] * c[0])
                    + a[2] * (b[0] * c[1] - b[1] * c[0])
                guard determinant.isFinite, determinant != 0 else {
                    throw orientationError(cell: start / 4)
                }
                if determinant < 0 { indices.swapAt(start, start + 1) }
            }
            grid.piece.cells.dataArray[0] = .indices(name: "connectivity", values: indices, format: format)
        }
        return grid
    }
}

public extension VTUFile {
    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar], triangleIndices: [Int32], pointData: PointData? = nil,
        cellData: CellData? = nil, fieldData: FieldData? = nil, options: VTKXMLFileOptions = .init()
    ) throws(VTKWriter.Error) -> VTUFile {
        try triangleMesh(points: points, triangleIndices: triangleIndices, pointData: pointData,
                         cellData: cellData, fieldData: fieldData, options: options, indexType: Int32.self)
    }

    static func triangleMesh<PointScalar: VTKFloatingPointScalarValue, IndexScalar: VTKIntegerScalarValue>(
        points: [PointScalar],
        triangleIndices: [IndexScalar],
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init(),
        indexType: IndexScalar.Type = IndexScalar.self
    ) throws(VTKWriter.Error) -> VTUFile {
        VTUFile(unstructuredGrid: try .triangleMesh(
            points: points, triangleIndices: triangleIndices, pointData: pointData,
            cellData: cellData, fieldData: fieldData, format: options.dataArrayFormat
        ), options: options)
    }

    static func tetrahedronMesh<PointScalar: VTKFloatingPointScalarValue>(
        points: [PointScalar], tetrahedronIndices: [Int32], orientation: TetrahedronOrientation = .preserve,
        pointData: PointData? = nil, cellData: CellData? = nil, fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init()
    ) throws(VTKWriter.Error) -> VTUFile {
        try tetrahedronMesh(points: points, tetrahedronIndices: tetrahedronIndices, orientation: orientation,
                            pointData: pointData, cellData: cellData, fieldData: fieldData,
                            options: options, indexType: Int32.self)
    }

    static func tetrahedronMesh<PointScalar: VTKFloatingPointScalarValue, IndexScalar: VTKIntegerScalarValue>(
        points: [PointScalar],
        tetrahedronIndices: [IndexScalar],
        orientation: TetrahedronOrientation = .preserve,
        pointData: PointData? = nil,
        cellData: CellData? = nil,
        fieldData: FieldData? = nil,
        options: VTKXMLFileOptions = .init(),
        indexType: IndexScalar.Type = IndexScalar.self
    ) throws(VTKWriter.Error) -> VTUFile {
        VTUFile(unstructuredGrid: try .tetrahedronMesh(
            points: points, tetrahedronIndices: tetrahedronIndices, orientation: orientation,
            pointData: pointData, cellData: cellData, fieldData: fieldData,
            format: options.dataArrayFormat
        ), options: options)
    }
}

private func maximumMagnitude(_ vector: SIMD3<Double>) -> Double {
    max(abs(vector[0]), abs(vector[1]), abs(vector[2]))
}

private func linearMesh<PointScalar: VTKFloatingPointScalarValue, IndexScalar: VTKIntegerScalarValue>(
    points: [PointScalar], indices: [IndexScalar], type: VTKCellType, nodesPerCell: Int,
    pointData: PointData?, cellData: CellData?, fieldData: FieldData?, format: DataArrayFormat
) throws(VTKWriter.Error) -> UnstructuredGrid {
    let datasetPath = "UnstructuredGrid.\(type == .triangle ? "triangleMesh" : "tetrahedronMesh")"
    guard points.count.isMultiple(of: 3) else {
        throw .invalidComponentCount(arrayName: "Points", datasetPath: datasetPath,
                                     valueCount: points.count, numberOfComponents: 3)
    }
    for (index, coordinate) in points.enumerated() where !coordinate.isFinite {
        throw .invalidCellLayout(datasetPath: datasetPath + "/Points",
                                 reason: "Coordinate \(index) must be finite.")
    }
    guard indices.count.isMultiple(of: nodesPerCell) else {
        throw .invalidCellLayout(datasetPath: datasetPath + "/Cells",
                                 reason: "Connectivity count \(indices.count) is not divisible by \(nodesPerCell).")
    }
    let cellCount = indices.count / nodesPerCell
    var offsets: [IndexScalar] = []
    offsets.reserveCapacity(cellCount)
    for cell in 0..<cellCount {
        let offset = (cell + 1) * nodesPerCell
        guard let converted = IndexScalar(exactly: offset) else {
            throw .numericOverflow(datasetPath: datasetPath + "/Cells/offsets",
                                   value: offset, targetType: IndexScalar.vtkScalarType.rawValue)
        }
        offsets.append(converted)
    }
    let grid = UnstructuredGrid(piece: UnstructuredPiece(
        numberOfPoints: points.count / 3, numberOfCells: cellCount,
        points: Points(dataArray: try .points(points, format: format)),
        cells: Cells(connectivity: .indices(name: "connectivity", values: indices, format: format),
                     offsets: .indices(name: "offsets", values: offsets, format: format),
                     types: .cellTypes(Array(repeating: type, count: cellCount), format: format)),
        pointData: pointData, cellData: cellData
    ), fieldData: fieldData)
    try grid.validate(at: datasetPath)
    return grid
}

private func orientationError(cell: Int) -> VTKWriter.Error {
    .invalidCellLayout(datasetPath: "UnstructuredGrid.tetrahedronMesh/Cells",
                       reason: "Tetrahedron \(cell) has zero volume or an unrepresentable orientation.")
}
