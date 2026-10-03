import Foundation
import Testing
import VTKKit

@Suite("VTK reader compatibility")
struct VTKMeshReaderTests {
    static let options: [VTKXMLFileOptions] = [
        .init(dataArrayFormat: .ascii),
        .init(byteOrder: .bigEndian, dataArrayFormat: .ascii),
        .init(dataArrayFormat: .binary),
        .init(byteOrder: .bigEndian, headerType: .uInt64, compression: .zlib, dataArrayFormat: .binary),
        .init(headerType: .uInt64, compression: .zlib, dataArrayFormat: .appended),
        .init(compression: .init(algorithm: .zlib, blockSize: 16), dataArrayFormat: .binary),
        .init(byteOrder: .bigEndian, headerType: .uInt64, compression: .lz4, dataArrayFormat: .appended),
        .init(compression: .init(algorithm: .lz4, blockSize: 16), dataArrayFormat: .binary),
        .init(headerType: .uInt64, compression: .lzma, dataArrayFormat: .appended),
        .init(byteOrder: .bigEndian, compression: .init(algorithm: .lzma, blockSize: 16), dataArrayFormat: .binary),
        .init(headerType: .uInt64, dataArrayFormat: .appended)
    ]

    @Test(.enabled(if: pythonHasVTK(), "Set VTKKIT_PYTHON to a Python interpreter with vtk installed"), arguments: options)
    func readsGeometryFieldsTimeAndOrientation(options: VTKXMLFileOptions) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let points: [Double] = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
        let file = try VTUFile.tetrahedronMesh(points: points,
            tetrahedronIndices: [1, 0, 2, 3, 0, 1, 2, 3] as [Int64], orientation: .positive,
            pointData: .init(scalarsName: "potential", dataArray: [.scalars(name: "potential", values: [1.0, 2, 3, 4], format: options.dataArrayFormat)]),
            cellData: .init(scalarsName: "region", vectorsName: "B", dataArray: [
                .scalars(name: "region", values: [17, 23] as [Int32], format: options.dataArrayFormat),
                try .vectors(name: "B", values: [1.0, 2, 3, 4, 5, 6], format: options.dataArrayFormat)
            ]), fieldData: .timeValue(0.125 as Double, format: options.dataArrayFormat), options: options)
        let tetraURL = root.appendingPathComponent("tetra.vtu")
        let triangleURL = root.appendingPathComponent("triangle.vtu")
        let emptyURL = root.appendingPathComponent("empty.vtu")
        try VTKWriter.write(file, to: tetraURL)
        #expect(try Data(contentsOf: tetraURL) == VTKWriter.encode(file))
        try VTKWriter.write(try VTUFile.triangleMesh(points: points, triangleIndices: [0, 1, 2], options: options), to: triangleURL)
        try VTKWriter.write(try VTUFile.tetrahedronMesh(points: [] as [Double],
            tetrahedronIndices: [] as [Int64], options: options), to: emptyURL)
        try pythonCheck(arguments: ["-c", """
        import sys, vtk
        import numpy as np
        def read(path):
            reader = vtk.vtkXMLUnstructuredGridReader()
            errors = []
            @vtk.calldata_type(vtk.VTK_STRING)
            def error(obj, event, message):
                errors.append(message)
            reader.AddObserver('ErrorEvent', error)
            reader.SetFileName(path)
            reader.Update()
            assert reader.GetErrorCode() == 0 and not errors, (path, errors)
            return reader.GetOutput()
        mesh = read(sys.argv[1])
        assert mesh.GetNumberOfPoints() == 4
        assert mesh.GetNumberOfCells() == 2
        assert mesh.GetPointData().GetScalars().GetName() == 'potential'
        assert mesh.GetPointData().GetArray('potential').GetTuple1(3) == 4.0
        assert mesh.GetCellData().GetScalars().GetName() == 'region'
        assert mesh.GetCellData().GetArray('region').GetTuple1(1) == 23
        assert mesh.GetCellData().GetVectors().GetName() == 'B'
        assert mesh.GetCellData().GetArray('B').GetTuple3(1) == (4.0, 5.0, 6.0)
        assert mesh.GetFieldData().GetArray('TimeValue').GetTuple1(0) == 0.125
        for i in range(2):
            cell = mesh.GetCell(i)
            assert cell.GetCellType() == vtk.VTK_TETRA
            p = [np.array(mesh.GetPoint(cell.GetPointId(j))) for j in range(4)]
            assert np.dot(p[1] - p[0], np.cross(p[2] - p[0], p[3] - p[0])) > 0
        triangle = read(sys.argv[2])
        assert triangle.GetNumberOfPoints() == 4
        assert triangle.GetNumberOfCells() == 1
        assert triangle.GetCellType(0) == vtk.VTK_TRIANGLE
        empty = read(sys.argv[3])
        assert empty.GetNumberOfPoints() == 0
        assert empty.GetNumberOfCells() == 0
        """, tetraURL.path, triangleURL.path, emptyURL.path])
    }
}

private var pythonPath: String {
    ProcessInfo.processInfo.environment["VTKKIT_PYTHON"] ?? "/usr/bin/python3"
}

private func pythonHasVTK() -> Bool {
    (try? pythonCheck(arguments: ["-c", "import vtk"])) != nil
}

private func pythonCheck(arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: pythonPath)
    process.arguments = arguments
    let errorPipe = Pipe()
    process.standardError = errorPipe
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
    defer { timeout.cancel() }
    let errors = errorPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw ReaderFailure(output: String(decoding: errors, as: UTF8.self))
    }
}

private struct ReaderFailure: Error, CustomStringConvertible {
    let output: String
    var description: String { output }
}
