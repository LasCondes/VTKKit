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
        self.init(
            type: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: numberOfComponents,
            values: values
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

    static func scalars<Scalar: VTKScalarValue>(
        name: String,
        values: [Scalar],
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        DataArray(
            type: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            values: values
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

    static func indices<Scalar: VTKIntegerScalarValue>(
        name: String,
        values: [Scalar],
        format: DataArrayFormat = .ascii
    ) -> DataArray {
        DataArray(
            type: Scalar.vtkScalarType.rawValue,
            name: name,
            format: format,
            numberOfComponents: 1,
            values: values
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
}

public extension PVDFile {
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
        values.split(whereSeparator: \.isWhitespace).count
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
        try values.split(whereSeparator: \.isWhitespace).map { token in
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
