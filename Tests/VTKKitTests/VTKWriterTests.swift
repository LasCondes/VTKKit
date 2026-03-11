import Foundation
import XCTest
@testable import VTKKit

final class VTKWriterTests: XCTestCase {
    func testEncodesPolyDataDocument() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    numberOfVerts: 1,
                    points: Points(
                        dataArray: DataArray(
                            type: "Float32",
                            name: "Points",
                            numberOfComponents: 3,
                            values: [0.0, 1.0, 2.0]
                        )
                    ),
                    pointData: PointData(
                        scalarsName: "Radius",
                        dataArray: [
                            DataArray(
                                type: "Float32",
                                name: "Radius",
                                numberOfComponents: 1,
                                values: [0.5]
                            ),
                        ]
                    ),
                    verts: Verts(
                        dataArray: [
                            DataArray(type: "Int32", name: "connectivity", numberOfComponents: 1, values: [0]),
                            DataArray(type: "Int32", name: "offsets", numberOfComponents: 1, values: [1]),
                        ]
                    )
                ),
                fieldData: FieldData(
                    timeValue: DataArray(
                        type: "Float64",
                        name: "TimeValue",
                        numberOfComponents: 1,
                        values: [1.5]
                    )
                )
            )
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        XCTAssertTrue(xml.contains("<PolyData>\n    <FieldData>"))
        XCTAssertTrue(xml.contains("<DataArray type=\"Float64\" Name=\"TimeValue\" format=\"ascii\" NumberOfComponents=\"1\">1.5</DataArray>"))
        XCTAssertTrue(xml.contains("<PointData Scalars=\"Radius\">"))
        XCTAssertTrue(xml.contains("<DataArray type=\"Float32\" Name=\"Radius\" format=\"ascii\" NumberOfComponents=\"1\">0.5</DataArray>"))
        XCTAssertTrue(xml.contains("<Verts>"))
    }

    func testWritesPVDDocumentAndCreatesParentDirectory() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputURL = temporaryDirectory
            .appendingPathComponent("scene")
            .appendingPathExtension("pvd")

        let pvd = PVDFile(
            collection: .init(
                dataSet: [
                    .init(group: "static", file: "static.vtp", timestep: 0),
                    .init(group: "dynamic", file: "frame_0.vtp", timestep: 0),
                    .init(group: "dynamic", file: "frame_1.vtp", timestep: 1),
                ]
            )
        )

        try VTKWriter.write(pvd, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(xml.contains("<Collection>"))
        XCTAssertTrue(xml.contains("<DataSet timestep=\"1.0\" group=\"dynamic\" part=\"1\" file=\"frame_1.vtp\" />"))
    }

    func testEncodesInlineBinaryDataArray() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            type: "Float32",
                            name: "Points",
                            format: .binary,
                            numberOfComponents: 3,
                            values: [1.0, 2.0, 3.0]
                        )
                    )
                )
            ),
            byteOrder: .bigEndian,
            headerType: .uInt64
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"BigEndian\" header_type=\"UInt64\">"))
        XCTAssertTrue(xml.contains("<DataArray type=\"Float32\" Name=\"Points\" format=\"binary\" NumberOfComponents=\"3\">AAAAAAAAAAw/gAAAQAAAAEBAAAA=</DataArray>"))
    }

    func testEncodesAppendedDataArraysAndOffsets() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            type: "Float32",
                            name: "Points",
                            format: .appended,
                            numberOfComponents: 3,
                            values: [0.0, 1.0, 2.0]
                        )
                    ),
                    pointData: PointData(
                        scalarsName: "Radius",
                        dataArray: [
                            DataArray(
                                type: "Float32",
                                name: "Radius",
                                format: .appended,
                                numberOfComponents: 1,
                                values: [0.5]
                            ),
                        ]
                    )
                )
            )
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"LittleEndian\" header_type=\"UInt32\">"))
        XCTAssertTrue(xml.contains("<DataArray type=\"Float32\" Name=\"Points\" format=\"appended\" NumberOfComponents=\"3\" offset=\"0\" />"))
        XCTAssertTrue(xml.contains("<DataArray type=\"Float32\" Name=\"Radius\" format=\"appended\" NumberOfComponents=\"1\" offset=\"24\" />"))
        XCTAssertTrue(xml.contains("<AppendedData encoding=\"base64\">_DAAAAAAAAAAAAIA/AAAAQA==BAAAAAAAAD8=</AppendedData>"))
    }

    func testRejectsUnsupportedBinaryType() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: try DataArray.points([0.0 as Float, 1.0, 2.0])
                    ),
                    pointData: PointData(
                        scalarsName: "Label",
                        dataArray: [
                            DataArray(
                                type: "String",
                                name: "Label",
                                format: .binary,
                                numberOfComponents: 1,
                                values: ["invalid"]
                            ),
                        ]
                    )
                )
            )
        )

        XCTAssertThrowsError(try VTKWriter.encode(vtk)) { error in
            guard case let VTKWriter.Error.unsupportedDataArrayType(arrayName, type) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(arrayName, "Label")
            XCTAssertEqual(type, "String")
        }
    }

    func testEncodesCompressedBinaryDataArray() throws {
        let vtk = VTKFile(
            polyData: try PolyData.pointCloud(
                points: [1.0 as Float, 2.0, 3.0],
                format: .binary
            ),
            compression: .zlib
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))
        let encodedArray = try XCTUnwrap(extractDataArrayText(named: "Points", from: xml))
        let encodedData = try XCTUnwrap(Data(base64Encoded: encodedArray))
        var byteOffset = 0
        let blockCount = try readHeaderValue(
            from: encodedData,
            at: &byteOffset,
            headerType: .uInt32,
            byteOrder: .littleEndian
        )
        let blockSize = try readHeaderValue(
            from: encodedData,
            at: &byteOffset,
            headerType: .uInt32,
            byteOrder: .littleEndian
        )
        let lastBlockSize = try readHeaderValue(
            from: encodedData,
            at: &byteOffset,
            headerType: .uInt32,
            byteOrder: .littleEndian
        )
        let compressedBlockSize = try readHeaderValue(
            from: encodedData,
            at: &byteOffset,
            headerType: .uInt32,
            byteOrder: .littleEndian
        )

        XCTAssertTrue(xml.contains("compressor=\"vtkZLibDataCompressor\""))
        XCTAssertEqual(blockCount, 1)
        XCTAssertEqual(blockSize, 32 * 1024)
        XCTAssertEqual(lastBlockSize, 12)
        XCTAssertGreaterThan(compressedBlockSize, 0)
        XCTAssertGreaterThan(encodedData.count, byteOffset)
    }

    func testRejectsInvalidCompressionConfiguration() throws {
        let vtk = VTKFile(
            polyData: try PolyData.pointCloud(
                points: [1.0 as Float, 2.0, 3.0],
                format: .binary
            ),
            compression: VTKCompression(algorithm: .zlib, blockSize: 0)
        )

        XCTAssertThrowsError(try VTKWriter.encode(vtk)) { error in
            guard case let VTKWriter.Error.invalidCompressionConfiguration(reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertTrue(reason.contains("blockSize"))
        }
    }

    func testEncodesASCIIFromRawBinaryStorage() throws {
        let rawData = [1.0 as Float, 2.0, 3.0].withUnsafeBufferPointer { Data(buffer: $0) }
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: try DataArray(
                            name: "Points",
                            format: .ascii,
                            numberOfComponents: 3,
                            scalarType: Float.self,
                            data: rawData,
                            valueCount: 3
                        )
                    )
                )
            )
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains(">1.0 2.0 3.0</DataArray>"))
    }

    func testUsesContiguousArrayBinaryStorage() throws {
        let points = ContiguousArray<Float>([0.0, 1.0, 2.0])
        let array = try DataArray.points(contiguousValues: points, format: .appended)

        XCTAssertEqual(array.binaryStorage?.valueCount, 3)
        XCTAssertEqual(array.binaryStorage?.byteOrder, .native)
        XCTAssertEqual(array.rawValueCount, 3)
    }

    func testTypedDataArrayInfersVTKScalarType() throws {
        let array = try DataArray(
            name: "TimeValue",
            numberOfComponents: 1,
            values: [0.25 as Double]
        )

        XCTAssertEqual(array.type, VTKScalarType.float64.rawValue)
        XCTAssertEqual(array.name, "TimeValue")
        XCTAssertEqual(array.values, "0.25")
    }

    func testPointCloudBuilderCreatesVertexConnectivity() throws {
        let polyData = try PolyData.pointCloud(
            points: [0.0 as Float, 1.0, 2.0, 3.0, 4.0, 5.0],
            pointData: PointData(
                scalarsName: "Radius",
                dataArray: [
                    .scalars(name: "Radius", values: [0.5 as Float, 0.75 as Float]),
                ]
            ),
            fieldData: .timeValue(1.0 as Double),
            format: .binary
        )

        let vtk = VTKFile(polyData: polyData)
        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("NumberOfVerts=\"2\""))
        XCTAssertTrue(xml.contains("<FieldData>"))
        XCTAssertTrue(xml.contains("Name=\"connectivity\" format=\"binary\""))
        XCTAssertTrue(xml.contains("Name=\"offsets\" format=\"binary\""))
    }

    func testTriangleMeshBuilderCreatesPolys() throws {
        let polyData = try PolyData.triangleMesh(
            points: [0.0 as Float, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            triangleIndices: [0 as Int32, 1, 2],
            fieldData: .timeValue(2.0 as Double),
            format: .ascii
        )

        let vtk = VTKFile(polyData: polyData)
        let data = try VTKWriter.encode(vtk)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("NumberOfPolys=\"1\""))
        XCTAssertTrue(xml.contains("<Polys>"))
        XCTAssertTrue(xml.contains("Name=\"offsets\" format=\"ascii\" NumberOfComponents=\"1\">3</DataArray>"))
        XCTAssertTrue(xml.contains("Name=\"TimeValue\" format=\"ascii\" NumberOfComponents=\"1\">2.0</DataArray>"))
    }

    func testPVDSeriesBuilder() throws {
        let pvd = try PVDFile.series(
            files: ["frame_0.vtp", "frame_1.vtp"],
            timesteps: [0.0, 1.0],
            group: "dynamic",
            part: 0
        )

        let data = try VTKWriter.encode(pvd)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<DataSet timestep=\"0.0\" group=\"dynamic\" part=\"0\" file=\"frame_0.vtp\" />"))
        XCTAssertTrue(xml.contains("<DataSet timestep=\"1.0\" group=\"dynamic\" part=\"0\" file=\"frame_1.vtp\" />"))
    }

    func testPVDSeriesWriterAppendsAndLoadsExistingDocument() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputURL = temporaryDirectory.appendingPathComponent("frames.pvd")

        let writer = try PVDSeriesWriter(url: outputURL, loadExisting: false)
        try await writer.append(file: "frame_0.vtp", timestep: 0.0, group: "dynamic", part: 0)
        try await writer.append(file: "frame_1.vtp", timestep: 1.0, group: "dynamic", part: 0)

        let reloadedWriter = try PVDSeriesWriter(url: outputURL)
        try await reloadedWriter.append(file: "frame_2.vtp", timestep: 2.0, group: "dynamic", part: 0)

        let file = try PVDFile.load(from: outputURL)

        XCTAssertEqual(file.collection.dataSet.count, 3)
        XCTAssertEqual(file.collection.dataSet.last?.file, "frame_2.vtp")
        XCTAssertEqual(file.collection.dataSet.last?.timestep, 2.0)
    }

    func testEncodesUnstructuredGridDocument() throws {
        let file = VTUFile(
            unstructuredGrid: UnstructuredGrid(
                piece: UnstructuredPiece(
                    numberOfPoints: 3,
                    numberOfCells: 1,
                    points: Points(
                        dataArray: try .points([0.0 as Float, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0])
                    ),
                    cells: Cells(
                        connectivity: .indices(name: "connectivity", values: [0 as Int32, 1, 2]),
                        offsets: .indices(name: "offsets", values: [3 as Int32]),
                        types: .cellTypes([.triangle])
                    ),
                    cellData: CellData(
                        scalarsName: "CellValue",
                        dataArray: [
                            .scalars(name: "CellValue", values: [1.0 as Float]),
                        ]
                    )
                ),
                fieldData: .timeValue(5.0 as Double)
            )
        )

        let data = try VTKWriter.encode(file)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"UnstructuredGrid\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        XCTAssertTrue(xml.contains("NumberOfCells=\"1\""))
        XCTAssertTrue(xml.contains("<CellData Scalars=\"CellValue\">"))
        XCTAssertTrue(xml.contains("Name=\"types\" format=\"ascii\" NumberOfComponents=\"1\">5</DataArray>"))
    }

    func testEncodesParallelPolyDataDocument() throws {
        let template = try PolyData.pointCloud(
            points: [0.0 as Float, 1.0, 2.0],
            pointData: PointData(
                scalarsName: "Radius",
                dataArray: [.scalars(name: "Radius", values: [0.5 as Float])]
            )
        )
        let file = try PVTPFile.collection(
            pieceSources: ["frame_0_piece_0.vtp", "frame_0_piece_1.vtp"],
            template: template,
            ghostLevel: 0
        )

        let data = try VTKWriter.encode(file)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"PPolyData\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        XCTAssertTrue(xml.contains("<PPointData Scalars=\"Radius\">"))
        XCTAssertTrue(xml.contains("<PPoints>"))
        XCTAssertTrue(xml.contains("<Piece Source=\"frame_0_piece_0.vtp\" />"))
        XCTAssertTrue(xml.contains("<Piece Source=\"frame_0_piece_1.vtp\" />"))
    }

    func testEncodesParallelUnstructuredGridDocument() throws {
        let template = UnstructuredGrid(
            piece: UnstructuredPiece(
                numberOfPoints: 3,
                numberOfCells: 1,
                points: Points(
                    dataArray: try .points([0.0 as Float, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0])
                ),
                cells: Cells(
                    connectivity: .indices(name: "connectivity", values: [0 as Int32, 1, 2]),
                    offsets: .indices(name: "offsets", values: [3 as Int32]),
                    types: .cellTypes([.triangle])
                ),
                pointData: PointData(
                    vectorsName: "Velocity",
                    dataArray: [try .vectors(name: "Velocity", values: [1.0 as Float, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0])]
                ),
                cellData: CellData(
                    scalarsName: "CellValue",
                    dataArray: [.scalars(name: "CellValue", values: [1.0 as Float])]
                )
            )
        )
        let file = try PVTUFile.collection(
            pieceSources: ["mesh_0.vtu", "mesh_1.vtu"],
            template: template
        )

        let data = try VTKWriter.encode(file)
        let xml = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(xml.contains("<VTKFile type=\"PUnstructuredGrid\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        XCTAssertTrue(xml.contains("<PPointData Vectors=\"Velocity\">"))
        XCTAssertTrue(xml.contains("<PCellData Scalars=\"CellValue\">"))
        XCTAssertTrue(xml.contains("<Piece Source=\"mesh_0.vtu\" />"))
        XCTAssertTrue(xml.contains("<Piece Source=\"mesh_1.vtu\" />"))
    }

    func testValidationErrorIncludesDatasetPath() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: try DataArray.points([0.0 as Float, 1.0, 2.0])
                    ),
                    pointData: PointData(
                        vectorsName: "Velocity",
                        dataArray: [
                            DataArray(
                                type: "Float32",
                                name: "Velocity",
                                numberOfComponents: 3,
                                values: [1.0 as Float, 2.0]
                            ),
                        ]
                    )
                )
            )
        )

        XCTAssertThrowsError(try VTKWriter.encode(vtk)) { error in
            guard case let VTKWriter.Error.invalidComponentCount(arrayName, datasetPath, valueCount, numberOfComponents) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(arrayName, "Velocity")
            XCTAssertEqual(datasetPath, "PolyData/Piece/PointData")
            XCTAssertEqual(valueCount, 2)
            XCTAssertEqual(numberOfComponents, 3)
        }
    }

    func testCompatibilityWithVTKPythonReadersWhenAvailable() throws {
        guard hasPythonVTK() else {
            throw XCTSkip("Python vtk runtime is not installed.")
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let polyData = try PolyData.pointCloud(
            points: [0.0 as Float, 1.0, 2.0, 3.0, 4.0, 5.0],
            pointData: PointData(
                scalarsName: "Radius",
                dataArray: [.scalars(name: "Radius", values: [0.5 as Float, 0.75])]
            ),
            format: .appended
        )
        let vtpURL = temporaryDirectory.appendingPathComponent("cloud.vtp")
        try VTKWriter.write(VTKFile(polyData: polyData, compression: .zlib), to: vtpURL)

        let vtuGrid = UnstructuredGrid(
            piece: UnstructuredPiece(
                numberOfPoints: 3,
                numberOfCells: 1,
                points: Points(
                    dataArray: try .points([0.0 as Float, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0], format: .appended)
                ),
                cells: Cells(
                    connectivity: .indices(name: "connectivity", values: [0 as Int32, 1, 2], format: .appended),
                    offsets: .indices(name: "offsets", values: [3 as Int32], format: .appended),
                    types: .cellTypes([.triangle], format: .appended)
                )
            )
        )
        let vtuURL = temporaryDirectory.appendingPathComponent("mesh.vtu")
        try VTKWriter.write(VTUFile(unstructuredGrid: vtuGrid, compression: .zlib), to: vtuURL)

        let pvtpURL = temporaryDirectory.appendingPathComponent("cloud.pvtp")
        try VTKWriter.write(
            PVTPFile(
                polyData: PPolyData(
                    pointData: polyData.piece.pointData.map(PPointData.init),
                    points: PPoints(polyData.piece.points),
                    pieces: [.init(source: "cloud.vtp")]
                )
            ),
            to: pvtpURL
        )

        let pvtuURL = temporaryDirectory.appendingPathComponent("mesh.pvtu")
        try VTKWriter.write(
            PVTUFile(
                unstructuredGrid: PUnstructuredGrid(
                    pointData: vtuGrid.piece.pointData.map(PPointData.init),
                    cellData: vtuGrid.piece.cellData.map(PCellData.init),
                    points: PPoints(vtuGrid.piece.points),
                    pieces: [.init(source: "mesh.vtu")]
                )
            ),
            to: pvtuURL
        )

        try runProcess(
            executable: "/usr/bin/python3",
            arguments: [
                "-c",
                vtkPythonCompatibilityScript(
                    vtpPath: vtpURL.path,
                    vtuPath: vtuURL.path,
                    pvtpPath: pvtpURL.path,
                    pvtuPath: pvtuURL.path
                ),
            ]
        )
    }

    func testCompatibilityWithParaViewPVDReaderWhenAvailable() throws {
        guard let pvpythonPath = findExecutable(named: "pvpython") else {
            throw XCTSkip("pvpython is not installed.")
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let frame0URL = temporaryDirectory.appendingPathComponent("frame_0.vtp")
        let frame1URL = temporaryDirectory.appendingPathComponent("frame_1.vtp")
        let pvdURL = temporaryDirectory.appendingPathComponent("frames.pvd")

        let polyData = try PolyData.pointCloud(points: [0.0 as Float, 1.0, 2.0], format: .binary)
        try VTKWriter.write(VTKFile(polyData: polyData), to: frame0URL)
        try VTKWriter.write(VTKFile(polyData: polyData.withTimeValue(1.0 as Double)), to: frame1URL)
        try VTKWriter.write(
            try PVDFile.series(
                files: ["frame_0.vtp", "frame_1.vtp"],
                timesteps: [0.0, 1.0],
                group: "dynamic",
                part: 0
            ),
            to: pvdURL
        )

        try runProcess(
            executable: pvpythonPath,
            arguments: [
                "-c",
                paraViewCompatibilityScript(pvdPath: pvdURL.path),
            ]
        )
    }

    func testModelRoundTripsThroughJSON() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            type: "Float32",
                            name: "Points",
                            numberOfComponents: 3,
                            values: [0.0, 1.0, 2.0]
                        )
                    )
                ),
                fieldData: FieldData(
                    timeValue: DataArray(
                        type: "Float64",
                        name: "TimeValue",
                        numberOfComponents: 1,
                        values: [0.25]
                    )
                )
            )
        )

        let data = try JSONEncoder().encode(vtk)
        let decoded = try JSONDecoder().decode(VTKFile.self, from: data)

        XCTAssertEqual(decoded, vtk)
    }
}

private func extractDataArrayText(named name: String, from xml: String) throws -> String? {
    let pattern = #"<DataArray[^>]*Name=\""# + NSRegularExpression.escapedPattern(for: name) + #"\"[^>]*>([^<]+)</DataArray>"#
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
    guard let match = regex.firstMatch(in: xml, range: range),
          let captureRange = Range(match.range(at: 1), in: xml) else {
        return nil
    }

    return String(xml[captureRange])
}

private func readHeaderValue(
    from data: Data,
    at byteOffset: inout Int,
    headerType: BinaryDataHeaderType,
    byteOrder: ByteOrder
) throws -> Int {
    let value: Int
    switch headerType {
    case .uInt32:
        value = Int(data.decodedInteger(at: byteOffset, as: UInt32.self, byteOrder: byteOrder))
        byteOffset += MemoryLayout<UInt32>.size
    case .uInt64:
        value = Int(data.decodedInteger(at: byteOffset, as: UInt64.self, byteOrder: byteOrder))
        byteOffset += MemoryLayout<UInt64>.size
    }
    return value
}

private func hasPythonVTK() -> Bool {
    do {
        try runProcess(
            executable: "/usr/bin/python3",
            arguments: ["-c", "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('vtk') else 1)"]
        )
        return true
    } catch {
        return false
    }
}

private func findExecutable(named name: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["which", name]

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }

    guard process.terminationStatus == 0,
          let path = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
          path.isEmpty == false else {
        return nil
    }

    return path
}

private func runProcess(executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let standardError = Pipe()
    process.standardError = standardError
    process.standardOutput = Pipe()

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let stderr = String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw TestSupportError.message("External compatibility runtime failed: \(stderr)")
    }
}

private func vtkPythonCompatibilityScript(
    vtpPath: String,
    vtuPath: String,
    pvtpPath: String,
    pvtuPath: String
) -> String {
    """
    import vtk

    checks = [
        (vtk.vtkXMLPolyDataReader(), \(pythonStringLiteral(vtpPath)), 2, 2),
        (vtk.vtkXMLUnstructuredGridReader(), \(pythonStringLiteral(vtuPath)), 3, 1),
        (vtk.vtkXMLPPolyDataReader(), \(pythonStringLiteral(pvtpPath)), 2, 2),
        (vtk.vtkXMLPUnstructuredGridReader(), \(pythonStringLiteral(pvtuPath)), 3, 1),
    ]

    for reader, path, expected_points, expected_cells in checks:
        reader.SetFileName(path)
        reader.Update()
        output = reader.GetOutput()
        assert output.GetNumberOfPoints() == expected_points, (path, output.GetNumberOfPoints(), expected_points)
        assert output.GetNumberOfCells() == expected_cells, (path, output.GetNumberOfCells(), expected_cells)
    """
}

private func paraViewCompatibilityScript(pvdPath: String) -> String {
    """
    from paraview.simple import OpenDataFile

    source = OpenDataFile(\(pythonStringLiteral(pvdPath)))
    assert source is not None
    source.UpdatePipeline()
    assert len(list(source.TimestepValues)) == 2
    """
}

private func pythonStringLiteral(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
}

private enum TestSupportError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
