import Foundation
import Testing
@testable import VTKKit

@Suite("Unstructured mesh builders and validation")
struct VTKMeshTests {
    private let points: [Double] = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]

    @Test(arguments: [DataArrayFormat.ascii, .binary, .appended])
    func triangleBuilderPreservesFieldsAndOptions(format: DataArrayFormat) throws {
        let file = try VTUFile.triangleMesh(
            points: points, triangleIndices: [0, 1, 2] as [Int64],
            pointData: .init(scalarsName: "potential", dataArray: [.scalars(name: "potential", values: [1, 2, 3, 4] as [Double], format: format)]),
            cellData: .init(scalarsName: "region", dataArray: [.scalars(name: "region", values: [7] as [Int32], format: format)]),
            fieldData: .timeValue(0.25 as Double),
            options: .init(byteOrder: .bigEndian, headerType: .uInt64, dataArrayFormat: format))
        #expect(file.unstructuredGrid.piece.numberOfCells == 1)
        #expect(file.unstructuredGrid.piece.cells.dataArray[0].type == "Int64")
        #expect(try file.unstructuredGrid.piece.cells.dataArray[1].integerValues(at: "test") == [3])
        #expect(file.byteOrder == .bigEndian)
        #expect(file.headerType == .uInt64)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vtu")
        defer { try? FileManager.default.removeItem(at: url) }
        try VTKWriter.write(file, to: url)
        #expect(try Data(contentsOf: url) == VTKWriter.encode(file))
    }

    @Test(arguments: [1e-150, 1.0, 1e150])
    func orientationCorrectionIsScaleIndependent(scale: Double) throws {
        let fields = CellData(dataArray: [.scalars(name: "region", values: [17, 23] as [Int32])])
        let input = [1, 0, 2, 3, 0, 1, 2, 3] as [Int64]
        let grid = try UnstructuredGrid.tetrahedronMesh(points: points.map { $0 * scale },
            tetrahedronIndices: input, orientation: .positive, cellData: fields, format: .appended)
        #expect(try grid.piece.cells.dataArray[0].integerValues(at: "test") == [0, 1, 2, 3, 0, 1, 2, 3])
        #expect(grid.piece.cellData == fields)
        let preserved = try UnstructuredGrid.tetrahedronMesh(points: points.map { $0 * scale }, tetrahedronIndices: input)
        #expect(try preserved.piece.cells.dataArray[0].integerValues(at: "test") == input.map(Int.init))
    }

    @Test
    func buildersRejectInvalidGeometryAndFieldCounts() throws {
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: [0.0, 0], triangleIndices: [0, 1, 2] as [Int32]) }
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: points, triangleIndices: [0, 1] as [Int32]) }
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: points, triangleIndices: [-1, 1, 2] as [Int32]) }
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: points, triangleIndices: [0, 1, 4] as [Int64]) }
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: points, triangleIndices: [0, 1, UInt64.max]) }
        #expect(throws: VTKWriter.Error.self) {
            try VTUFile.triangleMesh(points: points, triangleIndices: [0, 1, 2] as [Int32],
                cellData: .init(dataArray: [.scalars(name: "B", values: [1.0, 2.0])]))
        }
        #expect(throws: VTKWriter.Error.self) {
            try VTUFile.tetrahedronMesh(points: points, tetrahedronIndices: [0, 1, 2, 2] as [Int32], orientation: .positive)
        }
        var nonfinite = points; nonfinite[0] = .infinity
        #expect(throws: VTKWriter.Error.self) { try VTUFile.tetrahedronMesh(points: nonfinite, tetrahedronIndices: [0, 1, 2, 3] as [Int32]) }
        let oversizedOffsets = Array(repeating: Int8(0), count: 129)
        #expect(throws: VTKWriter.Error.self) { try VTUFile.triangleMesh(points: points, triangleIndices: oversizedOffsets) }
        let empty = try VTUFile.tetrahedronMesh(points: [] as [Double], tetrahedronIndices: [] as [Int64], orientation: .positive)
        #expect(empty.unstructuredGrid.piece.numberOfCells == 0)
        #expect(throws: Never.self) { try VTKWriter.encode(empty) }
    }

    @Test
    func rawDocumentsRejectUnsafeTopologyBeforeTouchingOutput() throws {
        var file = try VTUFile.tetrahedronMesh(points: points, tetrahedronIndices: [0, 1, 2, 3] as [Int32])
        let validCells = file.unstructuredGrid.piece.cells
        let cases: [[DataArray]] = [
            [.indices(name: "connectivity", values: [-1, 1, 2, 3] as [Int32]), validCells.dataArray[1], validCells.dataArray[2]],
            [.indices(name: "connectivity", values: [0, 1, 2, 4] as [Int32]), validCells.dataArray[1], validCells.dataArray[2]],
            [validCells.dataArray[0], .indices(name: "offsets", values: [99] as [Int32]), validCells.dataArray[2]],
            [validCells.dataArray[0], validCells.dataArray[1], .cellTypes([.triangle])],
            [validCells.dataArray[0], validCells.dataArray[1], .indices(name: "types", values: [10] as [Int32])],
            [.scalars(name: "connectivity", values: [0.0, 1, 2, 3]), validCells.dataArray[1], validCells.dataArray[2]],
            validCells.dataArray + [validCells.dataArray[0]],
            [DataArray(uncheckedType: "Int32", name: "connectivity", numberOfComponents: 2, values: [0, 1, 2, 3]), validCells.dataArray[1], validCells.dataArray[2]]
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vtu")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("existing artifact".utf8)
        try original.write(to: url)
        for arrays in cases {
            file.unstructuredGrid.piece.cells = Cells(dataArray: arrays)
            #expect(throws: VTKWriter.Error.self) { try VTKWriter.encode(file) }
            #expect(throws: VTKWriter.Error.self) { try VTKWriter.write(file, to: url) }
            #expect(try Data(contentsOf: url) == original)
        }
        var surface = try VTKFile.triangleMesh(points: points, triangleIndices: [0, 1, 2])
        surface.polyData.piece.polys?.dataArray[0] = .indices(name: "connectivity", values: [0, 1, 4] as [Int32])
        #expect(throws: VTKWriter.Error.self) { try VTKWriter.encode(surface) }
    }

    @Test
    func binaryTopologyChecksStorageEndiannessAndOverflow() throws {
        var bytes = Data()
        for value in [0, 1, 2] as [Int64] { bytes.appendInteger(value, byteOrder: .bigEndian) }
        let array = DataArray(uncheckedType: "Int64", name: "connectivity", numberOfComponents: 1,
                              binaryStorage: .init(data: bytes, valueCount: 3, byteOrder: .bigEndian))
        #expect(try array.integerValues(at: "test") == [0, 1, 2])
        var broken = array; broken.binaryStorage?.valueCount = 4
        #expect(throws: VTKWriter.Error.self) { try broken.integerValues(at: "test") }
        broken.binaryStorage?.valueCount = Int.max
        #expect(throws: VTKWriter.Error.self) { try broken.integerValues(at: "test") }
        #expect(throws: VTKWriter.Error.self) { try VTKScalarType.int64.encode(storage: broken.binaryStorage!, targetByteOrder: .native, arrayName: "test") }
        broken.binaryStorage?.valueCount = -1
        #expect(throws: VTKWriter.Error.self) { try broken.integerValues(at: "test") }
        #expect(throws: VTKWriter.Error.self) { try broken.validatedTupleCount(at: "test") }
    }

    @Test
    func polyhedronValidationRejectsTruncatedPayloadAndSupportsMixedCells() throws {
        let poly = try Cells.polyhedra([[[0, 2, 1], [0, 1, 3], [1, 2, 3], [0, 3, 2]]] as [[[Int32]]])
        var file = VTUFile(unstructuredGrid: .init(piece: .init(numberOfPoints: 4, numberOfCells: 1,
            points: Points(dataArray: try .points(points)), cells: poly)))
        for invalid in [99, -2] {
            file.unstructuredGrid.piece.cells.dataArray[4] = .indices(name: "faceoffsets", values: [Int32(invalid)])
            #expect(throws: VTKWriter.Error.self) { try VTKWriter.encode(file) }
        }
        file.unstructuredGrid.piece.cells = poly
        file.unstructuredGrid.piece.cells.dataArray[3] = .indices(name: "faces", values: [Int64.max])
        file.unstructuredGrid.piece.cells.dataArray[4] = .indices(name: "faceoffsets", values: [1] as [Int32])
        #expect(throws: VTKWriter.Error.self) { try VTKWriter.encode(file) }
        let faces = try poly.dataArray[3].integerValues(at: "test")
        let mixed = Cells(dataArray: [
            .indices(name: "connectivity", values: [0, 1, 2, 0, 2, 1, 3, 0, 1, 2, 3] as [Int32]),
            .indices(name: "offsets", values: [3, 7, 11] as [Int32]),
            .cellTypes([.triangle, .polyhedron, .tetra]), poly.dataArray[3],
            .indices(name: "faceoffsets", values: [-1, Int32(faces.count), -1])
        ])
        file.unstructuredGrid.piece.numberOfCells = 3
        file.unstructuredGrid.piece.cells = mixed
        #expect(throws: Never.self) { try VTKWriter.encode(file) }
    }
}
