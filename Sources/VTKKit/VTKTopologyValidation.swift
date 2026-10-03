import Foundation

/// Decodes topology directly from raw buffers, avoiding a large intermediate ASCII string.
extension DataArray {
    func topologyIntegers(at datasetPath: String) throws(VTKWriter.Error) -> [Int] {
        guard (numberOfComponents ?? 1) == 1 else {
            throw .invalidCellLayout(datasetPath: datasetPath,
                                     reason: "Topology array '\(name)' must have one component.")
        }
        guard let scalarType = VTKScalarType(rawValue: type) else {
            throw .unsupportedDataArrayType(arrayName: name, type: type)
        }
        if let storage = binaryStorage {
            let (byteCount, overflow) = storage.valueCount.multipliedReportingOverflow(by: scalarType.byteWidth)
            guard storage.valueCount >= 0, !overflow else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Invalid raw value count for '\(name)'.")
            }
            guard storage.data.count == byteCount else {
                throw .invalidBinaryStorage(arrayName: name, type: type,
                                            expectedByteCount: byteCount, actualByteCount: storage.data.count)
            }
        }
        switch scalarType {
        case .int8: return try integers(as: Int8.self, at: datasetPath)
        case .uint8: return try integers(as: UInt8.self, at: datasetPath)
        case .int16: return try integers(as: Int16.self, at: datasetPath)
        case .uint16: return try integers(as: UInt16.self, at: datasetPath)
        case .int32: return try integers(as: Int32.self, at: datasetPath)
        case .uint32: return try integers(as: UInt32.self, at: datasetPath)
        case .int64: return try integers(as: Int64.self, at: datasetPath)
        case .uint64: return try integers(as: UInt64.self, at: datasetPath)
        case .float32, .float64:
            throw .invalidCellLayout(datasetPath: datasetPath, reason: "Topology array '\(name)' must use an integer VTK type.")
        }
    }

    private func integers<Scalar: FixedWidthInteger>(as: Scalar.Type, at datasetPath: String) throws(VTKWriter.Error) -> [Int] {
        var result: [Int] = []
        if let storage = binaryStorage {
            result.reserveCapacity(storage.valueCount)
            for offset in stride(from: 0, to: storage.data.count, by: MemoryLayout<Scalar>.size) {
                let scalar = storage.data.decodedInteger(at: offset, as: Scalar.self, byteOrder: storage.byteOrder)
                guard let value = Int(exactly: scalar) else {
                    throw .invalidCellLayout(datasetPath: datasetPath, reason: "Value '\(scalar)' in '\(name)' exceeds the supported index range.")
                }
                result.append(value)
            }
        } else {
            for token in values.split(whereSeparator: \.isWhitespace) {
                guard let scalar = Scalar(String(token)), let value = Int(exactly: scalar) else {
                    throw .invalidDataArrayValue(arrayName: name, type: type, value: String(token))
                }
                result.append(value)
            }
        }
        return result
    }
}

func uniqueTopologyArrays(_ arrays: [DataArray], at datasetPath: String) throws(VTKWriter.Error) -> [String: DataArray] {
    var result: [String: DataArray] = [:]
    for array in arrays {
        guard result.updateValue(array, forKey: array.name) == nil else {
            throw .invalidCellLayout(datasetPath: datasetPath, reason: "Duplicate topology array '\(array.name)'.")
        }
    }
    return result
}

func topologyArray(_ name: String, in arrays: [String: DataArray], at datasetPath: String) throws(VTKWriter.Error) -> DataArray {
    guard let array = arrays[name] else {
        throw .invalidCellLayout(datasetPath: datasetPath, reason: "Missing \(name) array.")
    }
    return array
}

func validateOffsets(_ offsets: [Int], valueCount: Int, cellCount: Int, arrayName: String,
                     at datasetPath: String) throws(VTKWriter.Error) {
    guard offsets.count == cellCount else {
        throw .invalidTupleCount(arrayName: arrayName, datasetPath: datasetPath,
                                 expectedTupleCount: cellCount, actualTupleCount: offsets.count)
    }
    var previous = 0
    for offset in offsets {
        guard offset >= previous, offset <= valueCount else {
            throw .invalidCellLayout(datasetPath: datasetPath,
                                     reason: "\(arrayName) must be monotonic and within 0...\(valueCount).")
        }
        previous = offset
    }
    guard previous == valueCount else {
        throw .invalidCellLayout(datasetPath: datasetPath,
                                 reason: "The final \(arrayName) value \(previous) must equal value count \(valueCount).")
    }
}

func validatePointIndices(_ indices: [Int], pointCount: Int, at datasetPath: String) throws(VTKWriter.Error) {
    for (offset, index) in indices.enumerated() where index < 0 || index >= pointCount {
        throw .invalidCellLayout(datasetPath: datasetPath,
                                 reason: "Connectivity value \(index) at index \(offset) is outside the point range 0..<\(pointCount).")
    }
}

func validateUnstructuredTopology(_ cells: Cells, cellCount: Int, pointCount: Int,
                                  at datasetPath: String) throws(VTKWriter.Error) {
    let arrays = try uniqueTopologyArrays(cells.dataArray, at: datasetPath)
    let connectivity = try topologyArray("connectivity", in: arrays, at: datasetPath).topologyIntegers(at: datasetPath)
    let offsets = try topologyArray("offsets", in: arrays, at: datasetPath).topologyIntegers(at: datasetPath)
    let typesArray = try topologyArray("types", in: arrays, at: datasetPath)
    guard typesArray.type == VTKScalarType.uint8.rawValue else {
        throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell types must use UInt8.")
    }
    let types = try typesArray.topologyIntegers(at: datasetPath)
    try validateOffsets(offsets, valueCount: connectivity.count, cellCount: cellCount,
                        arrayName: "offsets", at: datasetPath)
    guard types.count == cellCount else {
        throw .invalidTupleCount(arrayName: "types", datasetPath: datasetPath,
                                 expectedTupleCount: cellCount, actualTupleCount: types.count)
    }
    try validatePointIndices(connectivity, pointCount: pointCount, at: datasetPath)
    var start = 0
    for (cell, type) in types.enumerated() {
        let count = offsets[cell] - start
        if type == 0 { // VTK_EMPTY_CELL; available through the unchecked document API.
            guard count == 0 else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Empty cell \(cell) must have no points.")
            }
        } else if let known = UInt8(exactly: type).flatMap(VTKCellType.init(rawValue:)) {
            let minimum: Int
            let exact: Bool
            switch known {
            case .vertex: (minimum, exact) = (1, true)
            case .polyVertex: (minimum, exact) = (1, false)
            case .line: (minimum, exact) = (2, true)
            case .polyLine: (minimum, exact) = (2, false)
            case .triangle: (minimum, exact) = (3, true)
            case .triangleStrip, .polygon: (minimum, exact) = (3, false)
            case .pixel, .quad, .tetra: (minimum, exact) = (4, true)
            case .voxel, .hexahedron: (minimum, exact) = (8, true)
            case .wedge: (minimum, exact) = (6, true)
            case .pyramid: (minimum, exact) = (5, true)
            case .pentagonalPrism: (minimum, exact) = (10, true)
            case .hexagonalPrism: (minimum, exact) = (12, true)
            case .polyhedron: (minimum, exact) = (4, false)
            }
            guard exact ? count == minimum : count >= minimum else {
                throw .invalidCellLayout(datasetPath: datasetPath,
                                         reason: "Cell \(cell) of type \(known) has \(count) points; expected \(exact ? "exactly" : "at least") \(minimum).")
            }
        } else {
            // Preserve support for raw higher-order VTK cell codes outside VTKCellType.
            guard count > 0 else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell \(cell) must have at least one point.")
            }
        }
        start = offsets[cell]
    }

    if types.contains(Int(VTKCellType.polyhedron.rawValue)) || arrays["faces"] != nil || arrays["faceoffsets"] != nil {
        let faces = try topologyArray("faces", in: arrays, at: datasetPath).topologyIntegers(at: datasetPath)
        let faceOffsets = try topologyArray("faceoffsets", in: arrays, at: datasetPath).topologyIntegers(at: datasetPath)
        guard faceOffsets.count == cellCount else {
            throw .invalidTupleCount(arrayName: "faceoffsets", datasetPath: datasetPath,
                                     expectedTupleCount: cellCount, actualTupleCount: faceOffsets.count)
        }
        try validateFaces(faces, offsets: faceOffsets, connectivity: connectivity,
                          connectivityOffsets: offsets, types: types, at: datasetPath)
    }
}

private func validateFaces(_ faces: [Int], offsets: [Int], connectivity: [Int],
                           connectivityOffsets: [Int], types: [Int], at datasetPath: String) throws(VTKWriter.Error) {
    var cursor = 0
    var cellStart = 0
    for (cell, type) in types.enumerated() {
        defer { cellStart = connectivityOffsets[cell] }
        let end = offsets[cell]
        if type != Int(VTKCellType.polyhedron.rawValue) {
            // VTK readers use -1 for non-polyhedra; a repeated offset is also harmless.
            guard end == -1 || end == cursor else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Non-polyhedron cell \(cell) must not consume face data.")
            }
            continue
        }
        guard end > cursor, end <= faces.count else {
            throw .invalidCellLayout(datasetPath: datasetPath, reason: "Face offset for cell \(cell) is outside its faces payload.")
        }
        let faceCount = faces[cursor]
        cursor += 1
        guard faceCount > 0, faceCount <= (end - cursor) / 4 else {
            throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell \(cell) has an invalid or truncated face count.")
        }
        let cellNodes = Set(connectivity[cellStart..<connectivityOffsets[cell]])
        for _ in 0..<faceCount {
            guard cursor < end else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell \(cell) face data is truncated.")
            }
            let count = faces[cursor]
            cursor += 1
            guard count >= 3, count <= end - cursor else {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell \(cell) face has invalid point count or truncated connectivity.")
            }
            for index in faces[cursor..<(cursor + count)] where !cellNodes.contains(index) {
                throw .invalidCellLayout(datasetPath: datasetPath, reason: "Face references point \(index) outside cell \(cell) connectivity.")
            }
            cursor += count
        }
        guard cursor == end else {
            throw .invalidCellLayout(datasetPath: datasetPath, reason: "Cell \(cell) has trailing face data.")
        }
    }
    guard cursor == faces.count else {
        throw .invalidCellLayout(datasetPath: datasetPath, reason: "Faces payload contains unreferenced trailing data.")
    }
}
