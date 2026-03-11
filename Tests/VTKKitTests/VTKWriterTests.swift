import Foundation
import Testing
@testable import VTKKit

@Suite("VTKWriter")
struct VTKWriterTests {
    @Test
    func encodesPolyDataDocument() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    numberOfVerts: 1,
                    points: Points(
                        dataArray: DataArray(
                            uncheckedType: "Float32",
                            name: "Points",
                            numberOfComponents: 3,
                            values: [0.0, 1.0, 2.0]
                        )
                    ),
                    pointData: PointData(
                        scalarsName: "Radius",
                        dataArray: [
                            DataArray(
                                uncheckedType: "Float32",
                                name: "Radius",
                                numberOfComponents: 1,
                                values: [0.5]
                            ),
                        ]
                    ),
                    verts: Verts(
                        dataArray: [
                            DataArray(uncheckedType: "Int32", name: "connectivity", numberOfComponents: 1, values: [0]),
                            DataArray(uncheckedType: "Int32", name: "offsets", numberOfComponents: 1, values: [1]),
                        ]
                    )
                ),
                fieldData: FieldData(
                    timeValue: DataArray(
                        uncheckedType: "Float64",
                        name: "TimeValue",
                        numberOfComponents: 1,
                        values: [1.5]
                    )
                )
            )
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        #expect(xml.contains("<PolyData>\n    <FieldData>"))
        #expect(xml.contains("<DataArray type=\"Float64\" Name=\"TimeValue\" format=\"ascii\" NumberOfComponents=\"1\">1.5</DataArray>"))
        #expect(xml.contains("<PointData Scalars=\"Radius\">"))
        #expect(xml.contains("<DataArray type=\"Float32\" Name=\"Radius\" format=\"ascii\" NumberOfComponents=\"1\">0.5</DataArray>"))
        #expect(xml.contains("<Verts>"))
    }

    @Test
    func writesPVDDocumentAndCreatesParentDirectory() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(xml.contains("<Collection>"))
        #expect(xml.contains("<DataSet timestep=\"1.0\" group=\"dynamic\" part=\"1\" file=\"frame_1.vtp\" />"))
    }

    @Test
    func encodesInlineBinaryDataArray() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            uncheckedType: "Float32",
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"BigEndian\" header_type=\"UInt64\">"))
        #expect(xml.contains("<DataArray type=\"Float32\" Name=\"Points\" format=\"binary\" NumberOfComponents=\"3\">AAAAAAAAAAw/gAAAQAAAAEBAAAA=</DataArray>"))
    }

    @Test
    func encodesAppendedDataArraysAndOffsets() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            uncheckedType: "Float32",
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
                                uncheckedType: "Float32",
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"PolyData\" version=\"0.1\" byte_order=\"LittleEndian\" header_type=\"UInt32\">"))
        #expect(xml.contains("<DataArray type=\"Float32\" Name=\"Points\" format=\"appended\" NumberOfComponents=\"3\" offset=\"0\" />"))
        #expect(xml.contains("<DataArray type=\"Float32\" Name=\"Radius\" format=\"appended\" NumberOfComponents=\"1\" offset=\"24\" />"))
        #expect(xml.contains("<AppendedData encoding=\"base64\">_DAAAAAAAAAAAAIA/AAAAQA==BAAAAAAAAD8=</AppendedData>"))
    }

    @Test
    func rejectsUnsupportedBinaryType() throws {
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
                                uncheckedType: "String",
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

        let error = try requireWriterError {
            _ = try VTKWriter.encode(vtk)
        }

        guard case let .unsupportedDataArrayType(arrayName, type) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(arrayName == "Label")
        #expect(type == "String")
    }

    @Test
    func encodesCompressedBinaryDataArray() throws {
        let vtk = VTKFile(
            polyData: try PolyData.pointCloud(
                points: [1.0 as Float, 2.0, 3.0],
                format: .binary
            ),
            compression: .zlib
        )

        let data = try VTKWriter.encode(vtk)
        let xml = try #require(String(data: data, encoding: .utf8))
        let encodedArray = try #require(try extractDataArrayText(named: "Points", from: xml))
        let encodedData = try #require(Data(base64Encoded: encodedArray))
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

        #expect(xml.contains("compressor=\"vtkZLibDataCompressor\""))
        #expect(blockCount == 1)
        #expect(blockSize == 32 * 1024)
        #expect(lastBlockSize == 12)
        #expect(compressedBlockSize > 0)
        #expect(encodedData.count > byteOffset)
    }

    @Test
    func rejectsInvalidCompressionConfiguration() throws {
        let vtk = VTKFile(
            polyData: try PolyData.pointCloud(
                points: [1.0 as Float, 2.0, 3.0],
                format: .binary
            ),
            compression: VTKCompression(algorithm: .zlib, blockSize: 0)
        )

        let error = try requireWriterError {
            _ = try VTKWriter.encode(vtk)
        }

        guard case let .invalidCompressionConfiguration(reason) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(reason.contains("blockSize"))
    }

    @Test
    func encodesASCIIFromRawBinaryStorage() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains(">1.0 2.0 3.0</DataArray>"))
    }

    @Test
    func usesContiguousArrayBinaryStorage() throws {
        let points = ContiguousArray<Float>([0.0, 1.0, 2.0])
        let array = try DataArray.points(contiguousValues: points, format: .appended)

        #expect(array.binaryStorage?.valueCount == 3)
        #expect(array.binaryStorage?.byteOrder == .native)
        #expect(array.rawValueCount == 3)
    }

    @Test
    func streamingWriteMatchesEncodedPolyDataDocument() throws {
        let file = try VTKFile.pointCloud(
            points: [0.0 as Float, 1.0, 2.0, 3.0, 4.0, 5.0],
            pointData: PointData(
                scalarsName: "Radius",
                dataArray: [.scalars(name: "Radius", values: [0.5 as Float, 0.75 as Float], format: .appended)]
            ),
            fieldData: .timeValue(1.0 as Double, format: .appended),
            options: .init(
                byteOrder: .littleEndian,
                headerType: .uInt64,
                compression: .zlib,
                dataArrayFormat: .appended
            )
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("vtp")

        let encoded = try VTKWriter.encode(file)
        try VTKWriter.write(file, to: outputURL)
        let written = try Data(contentsOf: outputURL)

        #expect(written == encoded)
    }

    @Test
    func streamingWriteMatchesEncodedUnstructuredGridDocument() throws {
        let file = try VTUFile.polyhedronMesh(
            points: [
                0.0 as Float, 0.0, 0.0,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
            ],
            cells: [
                [
                    [0, 1, 2],
                    [0, 1, 3],
                    [1, 2, 3],
                    [0, 2, 3],
                ],
            ],
            options: .init(compression: .zlib, dataArrayFormat: .appended)
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("vtu")

        let encoded = try VTKWriter.encode(file)
        try VTKWriter.write(file, to: outputURL)
        let written = try Data(contentsOf: outputURL)

        #expect(written == encoded)
    }

    @Test
    func typedDataArrayInfersVTKScalarType() throws {
        let array = try DataArray(
            name: "TimeValue",
            numberOfComponents: 1,
            values: [0.25 as Double]
        )

        #expect(array.type == VTKScalarType.float64.rawValue)
        #expect(array.name == "TimeValue")
        #expect(array.values == "0.25")
    }

    @Test
    func pointCloudBuilderCreatesVertexConnectivity() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("NumberOfVerts=\"2\""))
        #expect(xml.contains("<FieldData>"))
        #expect(xml.contains("Name=\"connectivity\" format=\"binary\""))
        #expect(xml.contains("Name=\"offsets\" format=\"binary\""))
    }

    @Test
    func triangleMeshBuilderCreatesPolys() throws {
        let polyData = try PolyData.triangleMesh(
            points: [0.0 as Float, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
            triangleIndices: [0 as Int32, 1, 2],
            fieldData: .timeValue(2.0 as Double),
            format: .ascii
        )

        let vtk = VTKFile(polyData: polyData)
        let data = try VTKWriter.encode(vtk)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("NumberOfPolys=\"1\""))
        #expect(xml.contains("<Polys>"))
        #expect(xml.contains("Name=\"offsets\" format=\"ascii\" NumberOfComponents=\"1\">3</DataArray>"))
        #expect(xml.contains("Name=\"TimeValue\" format=\"ascii\" NumberOfComponents=\"1\">2.0</DataArray>"))
    }

    @Test
    func polygonMeshBuilderCreatesPolygonOffsets() throws {
        let polyData = try PolyData.polygonMesh(
            points: [
                0.0 as Float, 0.0, 0.0,
                1.0, 0.0, 0.0,
                1.0, 1.0, 0.0,
                0.0, 1.0, 0.0,
            ],
            polygons: [[0 as Int32, 1, 2, 3]],
            format: .ascii
        )
        let data = try VTKWriter.encode(VTKFile(polyData: polyData))
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("NumberOfPolys=\"1\""))
        #expect(xml.contains("Name=\"connectivity\" format=\"ascii\" NumberOfComponents=\"1\">0 1 2 3</DataArray>"))
        #expect(xml.contains("Name=\"offsets\" format=\"ascii\" NumberOfComponents=\"1\">4</DataArray>"))
    }

    @Test
    func triangulatedPolygonMeshBuilderFansPolygonIntoTriangles() throws {
        let polyData = try PolyData.triangulatedPolygonMesh(
            points: [
                0.0 as Float, 0.0, 0.0,
                1.0, 0.0, 0.0,
                1.0, 1.0, 0.0,
                0.0, 1.0, 0.0,
            ],
            polygons: [[0 as Int32, 1, 2, 3]],
            format: .ascii
        )
        let data = try VTKWriter.encode(VTKFile(polyData: polyData))
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("NumberOfPolys=\"2\""))
        #expect(xml.contains("Name=\"connectivity\" format=\"ascii\" NumberOfComponents=\"1\">0 1 2 0 2 3</DataArray>"))
        #expect(xml.contains("Name=\"offsets\" format=\"ascii\" NumberOfComponents=\"1\">3 6</DataArray>"))
    }

    @Test
    func robustTriangulatedPolygonMeshHandlesConcavePolygon() throws {
        let polyData = try PolyData.robustTriangulatedPolygonMesh(
            points: [
                0.0 as Float, 0.0, 0.0,
                2.0, 0.0, 0.0,
                2.0, 1.0, 0.0,
                1.0, 0.4, 0.0,
                0.0, 1.0, 0.0,
            ],
            polygons: [[0 as Int32, 1, 2, 3, 4]],
            format: .ascii
        )
        let data = try VTKWriter.encode(VTKFile(polyData: polyData))
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("NumberOfPolys=\"3\""))
        #expect(xml.contains("Name=\"offsets\" format=\"ascii\" NumberOfComponents=\"1\">3 6 9</DataArray>"))
        #expect(!xml.contains("Name=\"connectivity\" format=\"ascii\" NumberOfComponents=\"1\">0 1 2 0 2 3 0 3 4</DataArray>"))
    }

    @Test
    func robustTriangulatedPolygonMeshRejectsSelfIntersectingPolygon() throws {
        let error = try requireWriterError {
            _ = try PolyData.robustTriangulatedPolygonMesh(
                points: [
                    0.0 as Float, 0.0, 0.0,
                    1.0, 1.0, 0.0,
                    0.0, 1.0, 0.0,
                    1.0, 0.0, 0.0,
                ],
                polygons: [[0 as Int32, 1, 2, 3]],
                format: .ascii
            )
        }

        guard case let .invalidCellLayout(datasetPath, reason) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(datasetPath.contains("triangulatedPolygonMesh"))
        #expect(!reason.isEmpty)
    }

    @Test
    func pvdSeriesBuilder() throws {
        let pvd = try PVDFile.series(
            files: ["frame_0.vtp", "frame_1.vtp"],
            timesteps: [0.0, 1.0],
            group: "dynamic",
            part: 0
        )

        let data = try VTKWriter.encode(pvd)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<DataSet timestep=\"0.0\" group=\"dynamic\" part=\"0\" file=\"frame_0.vtp\" />"))
        #expect(xml.contains("<DataSet timestep=\"1.0\" group=\"dynamic\" part=\"0\" file=\"frame_1.vtp\" />"))
    }

    @Test
    func pvdSeriesBuilderSortsMultipleGroupsByTimestep() throws {
        let pvd = try PVDFile.series(
            groups: [
                .init(
                    group: "static",
                    files: ["static.vtp", "static.vtp"],
                    timesteps: [0.0, 1.0],
                    part: 0
                ),
                .init(
                    group: "dynamic",
                    files: ["frame_0.vtp", "frame_1.vtp"],
                    timesteps: [0.0, 1.0],
                    part: 0
                ),
            ]
        )

        #expect(
            pvd.collection.dataSet.map { "\($0.timestep):\($0.group):\($0.file)" }
                == [
                    "0.0:static:static.vtp",
                    "0.0:dynamic:frame_0.vtp",
                    "1.0:static:static.vtp",
                    "1.0:dynamic:frame_1.vtp",
                ]
        )
    }

    @Test
    func pvdSeriesWriterAppendsAndLoadsExistingDocument() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputURL = temporaryDirectory.appendingPathComponent("frames.pvd")

        let writer = try PVDSeriesWriter(url: outputURL, loadExisting: false)
        try await writer.append(file: "frame_0.vtp", timestep: 0.0, group: "dynamic", part: 0)
        try await writer.append(file: "frame_1.vtp", timestep: 1.0, group: "dynamic", part: 0)

        let reloadedWriter = try PVDSeriesWriter(url: outputURL)
        try await reloadedWriter.append(file: "frame_2.vtp", timestep: 2.0, group: "dynamic", part: 0)

        let file = try PVDFile.load(from: outputURL)

        #expect(file.collection.dataSet.count == 3)
        #expect(file.collection.dataSet.last?.file == "frame_2.vtp")
        #expect(file.collection.dataSet.last?.timestep == 2.0)
    }

    @Test
    func encodesUnstructuredGridDocument() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"UnstructuredGrid\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        #expect(xml.contains("NumberOfCells=\"1\""))
        #expect(xml.contains("<CellData Scalars=\"CellValue\">"))
        #expect(xml.contains("Name=\"types\" format=\"ascii\" NumberOfComponents=\"1\">5</DataArray>"))
    }

    @Test
    func polyhedronMeshBuilderEmitsFacesAndFaceOffsets() throws {
        let file = try VTUFile.polyhedronMesh(
            points: [
                0.0 as Float, 0.0, 0.0,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
            ],
            cells: [
                [
                    [0, 1, 2],
                    [0, 1, 3],
                    [1, 2, 3],
                    [0, 2, 3],
                ],
            ]
        )

        let data = try VTKWriter.encode(file)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("Name=\"types\" format=\"ascii\" NumberOfComponents=\"1\">42</DataArray>"))
        #expect(xml.contains("Name=\"faces\" format=\"ascii\""))
        #expect(xml.contains("Name=\"faceoffsets\" format=\"ascii\" NumberOfComponents=\"1\">17</DataArray>"))
    }

    @Test
    func fileBuilderAppliesBinaryOptions() throws {
        let file = try VTKFile.pointCloud(
            points: [0.0 as Float, 1.0, 2.0],
            options: .init(
                byteOrder: .bigEndian,
                headerType: .uInt64,
                compression: .zlib,
                dataArrayFormat: .appended
            )
        )

        let data = try VTKWriter.encode(file)
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("byte_order=\"BigEndian\""))
        #expect(xml.contains("header_type=\"UInt64\""))
        #expect(xml.contains("compressor=\"vtkZLibDataCompressor\""))
        #expect(xml.contains("format=\"appended\""))
    }

    @Test
    func encodesParallelPolyDataDocument() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"PPolyData\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        #expect(xml.contains("<PPointData Scalars=\"Radius\">"))
        #expect(xml.contains("<PPoints>"))
        #expect(xml.contains("<Piece Source=\"frame_0_piece_0.vtp\" />"))
        #expect(xml.contains("<Piece Source=\"frame_0_piece_1.vtp\" />"))
    }

    @Test
    func partitionedPolyDataWriterCreatesPiecesAndManifest() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifestURL = temporaryDirectory.appendingPathComponent("frame_0.pvtp")
        let pieces = [
            try PolyData.pointCloud(points: [0.0 as Float, 1.0, 2.0], format: .appended),
            try PolyData.pointCloud(points: [3.0 as Float, 4.0, 5.0], format: .appended),
        ]

        let manifest = try VTKWriter.writePartitionedPolyData(
            pieces: pieces,
            manifestURL: manifestURL,
            options: .init(compression: .zlib, dataArrayFormat: .appended)
        )

        #expect(manifest.polyData.pieces.count == 2)
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        #expect(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent("frame_0_piece_0.vtp").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent("frame_0_piece_1.vtp").path
            )
        )
    }

    @Test
    func encodesParallelUnstructuredGridDocument() throws {
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
        let xml = try #require(String(data: data, encoding: .utf8))

        #expect(xml.contains("<VTKFile type=\"PUnstructuredGrid\" version=\"0.1\" byte_order=\"LittleEndian\">"))
        #expect(xml.contains("<PPointData Vectors=\"Velocity\">"))
        #expect(xml.contains("<PCellData Scalars=\"CellValue\">"))
        #expect(xml.contains("<Piece Source=\"mesh_0.vtu\" />"))
        #expect(xml.contains("<Piece Source=\"mesh_1.vtu\" />"))
    }

    @Test
    func validationErrorIncludesDatasetPath() throws {
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
                                uncheckedType: "Float32",
                                name: "Velocity",
                                numberOfComponents: 3,
                                values: [1.0 as Float, 2.0]
                            ),
                        ]
                    )
                )
            )
        )

        let error = try requireWriterError {
            _ = try VTKWriter.encode(vtk)
        }

        guard case let .invalidComponentCount(arrayName, datasetPath, valueCount, numberOfComponents) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }

        #expect(arrayName == "Velocity")
        #expect(datasetPath == "PolyData/Piece/PointData")
        #expect(valueCount == 2)
        #expect(numberOfComponents == 3)
    }

    @Test
    func compatibilityWithVTKPythonReadersWhenAvailable() throws {
        guard hasPythonVTK() else {
            return
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

    @Test
    func compatibilityWithParaViewPVDReaderWhenAvailable() throws {
        guard let pvpythonPath = findExecutable(named: "pvpython") else {
            return
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

    @Test
    func modelRoundTripsThroughJSON() throws {
        let vtk = VTKFile(
            polyData: PolyData(
                piece: Piece(
                    numberOfPoints: 1,
                    points: Points(
                        dataArray: DataArray(
                            uncheckedType: "Float32",
                            name: "Points",
                            numberOfComponents: 3,
                            values: [0.0, 1.0, 2.0]
                        )
                    )
                ),
                fieldData: FieldData(
                    timeValue: DataArray(
                        uncheckedType: "Float64",
                        name: "TimeValue",
                        numberOfComponents: 1,
                        values: [0.25]
                    )
                )
            )
        )

        let data = try JSONEncoder().encode(vtk)
        let decoded = try JSONDecoder().decode(VTKFile.self, from: data)

        #expect(decoded == vtk)
    }
}

private func requireWriterError(_ body: () throws -> Void) throws -> VTKWriter.Error {
    do {
        try body()
    } catch let error as VTKWriter.Error {
        return error
    }

    throw TestSupportError.message("Expected VTKWriter.Error.")
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
