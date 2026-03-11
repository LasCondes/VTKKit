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
