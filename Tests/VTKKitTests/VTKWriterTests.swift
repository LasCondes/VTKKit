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
