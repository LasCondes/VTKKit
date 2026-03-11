# VTKKit

`VTKKit` is a small Swift package for writing VTK PolyData (`.vtp`) files and
PVD collection (`.pvd`) files without taking a dependency on a larger engine or
app codebase.

The package targets Swift 6 and uses plain Swift value types for the document
model. Those types are `Codable`, but XML emission stays custom because VTK XML
does not map cleanly onto Foundation's `Codable` support without adding an XML
encoder dependency.

## Scope

VTKKit currently supports a focused subset of the VTK XML ecosystem:

- ASCII VTK PolyData XML (`.vtp`) documents
- Dataset-level `FieldData` for metadata such as `TimeValue`
- PVD collection (`.pvd`) meta-files that reference VTK XML datasets
- File-writing helpers for `.vtp` and `.pvd` output

The package is intentionally agnostic about application domain models. Callers
map their own data structures into the exported VTK document types.

It does not currently implement VTK XML `binary` or `appended` `DataArray`
encodings, and it does not aim to cover every VTK dataset type.

## Design

- Public document types are Swift value types with `Sendable`, `Equatable`, and
  `Codable` conformance.
- XML writing is explicit and format-aware rather than routed through a generic
  XML encoder.
- The API only exposes states the writer can actually serialize correctly. For
  example, `DataArray` format is currently restricted to ASCII.

## Usage

### Write a `.vtp` file

```swift
import Foundation
import VTKKit

let polyData = PolyData(
    piece: Piece(
        numberOfPoints: 3,
        numberOfPolys: 1,
        points: Points(
            dataArray: DataArray(
                type: "Float32",
                name: "Points",
                numberOfComponents: 3,
                values: [
                    0.0, 0.0, 0.0,
                    1.0, 0.0, 0.0,
                    0.0, 1.0, 0.0,
                ]
            )
        ),
        polys: Polys(
            connectivity: DataArray(
                type: "Int32",
                name: "connectivity",
                numberOfComponents: 1,
                values: [0, 1, 2]
            ),
            offsets: DataArray(
                type: "Int32",
                name: "offsets",
                numberOfComponents: 1,
                values: [3]
            )
        )
    ),
    fieldData: FieldData(
        timeValue: DataArray(
            type: "Float64",
            name: "TimeValue",
            numberOfComponents: 1,
            values: [0.0]
        )
    )
)

let file = VTKFile(polyData: polyData)
try VTKWriter.write(file, to: URL(fileURLWithPath: "triangle.vtp"))
```

### Write a `.pvd` collection

```swift
import Foundation
import VTKKit

let collection = PVDFile(
    collection: .init(
        dataSet: [
            .init(group: "default", file: "frame_0000.vtp", timestep: 0.0),
            .init(group: "default", file: "frame_0001.vtp", timestep: 1.0),
        ]
    )
)

try VTKWriter.write(collection, to: URL(fileURLWithPath: "series.pvd"))
```

## Notes

- `FieldData(TimeValue)` is emitted at the dataset level under `PolyData`, which
  matches the VTK XML convention for time metadata.
- `PVDFile` is a ParaView-style collection file that points at VTK XML dataset
  files such as `.vtp`.
- `Codable` is useful for testing, intermediate representations, and persistence
  of the document model, but not as the XML backend for the VTK file format.
