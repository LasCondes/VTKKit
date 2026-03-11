# VTKKit

`VTKKit` is a small Swift package for writing VTK PolyData (`.vtp`),
UnstructuredGrid (`.vtu`), and PVD collection (`.pvd`) files without taking a
dependency on a larger engine or app codebase.

The package targets Swift 6 and uses plain Swift value types for the document
model. Those types are `Codable`, but XML emission stays custom because VTK XML
does not map cleanly onto Foundation's `Codable` support without adding an XML
encoder dependency.

## Scope

VTKKit currently supports a focused subset of the VTK XML ecosystem:

- ASCII, inline binary, and appended VTK PolyData XML (`.vtp`) documents
- ASCII, inline binary, and appended UnstructuredGrid XML (`.vtu`) documents
- Dataset-level `FieldData` for metadata such as `TimeValue`
- Strongly typed `DataArray` construction for VTK scalar types
- High-level builders for point clouds, triangle meshes, and PVD time series
- PVD collection (`.pvd`) meta-files that reference VTK XML datasets
- File-writing helpers for `.vtp`, `.vtu`, and `.pvd` output

The package is intentionally agnostic about application domain models. Callers
map their own data structures into the exported VTK document types.

It does not aim to cover every VTK dataset type, and it currently leaves VTK
XML compression, streaming `.pvd` mutation, and parallel/multi-piece dataset
formats out of scope.

## Design

- Public document types are Swift value types with `Sendable`, `Equatable`, and
  `Codable` conformance.
- Typed scalar protocols and `DataArray` convenience factories remove the most
  common type/payload mismatches at the call site.
- XML writing is explicit and format-aware rather than routed through a generic
  XML encoder.
- Validation runs before serialization and reports array names plus dataset
  paths for component-count, tuple-count, and cell-layout problems.

## Usage

### Typed arrays and time metadata

```swift
import Foundation
import VTKKit

let velocity = try DataArray.vectors(
    name: "Velocity",
    values: [1.0 as Float, 0.0, 0.0, 0.0, 1.0, 0.0],
    format: .binary
)

let time = FieldData.timeValue(0.25 as Double, format: .ascii)
```

### Write a point-cloud `.vtp`

```swift
import Foundation
import VTKKit

let polyData = try PolyData.pointCloud(
    points: [
        0.0 as Float, 1.0, 2.0,
        3.0, 4.0, 5.0,
    ],
    pointData: PointData(
        scalarsName: "Radius",
        dataArray: [
            .scalars(name: "Radius", values: [0.5 as Float, 0.75 as Float], format: .binary),
        ]
    ),
    fieldData: .timeValue(1.0 as Double),
    format: .binary
)

try VTKWriter.write(VTKFile(polyData: polyData), to: URL(fileURLWithPath: "particles.vtp"))
```

### Write a triangle-mesh `.vtp`

```swift
import Foundation
import VTKKit

let polyData = try PolyData.triangleMesh(
    points: [
        0.0 as Float, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
    ],
    triangleIndices: [0 as Int32, 1, 2],
    fieldData: .timeValue(2.0 as Double),
    format: .ascii
)

try VTKWriter.write(VTKFile(polyData: polyData), to: URL(fileURLWithPath: "surface.vtp"))
```

### Write an `UnstructuredGrid` `.vtu`

```swift
import Foundation
import VTKKit

let grid = UnstructuredGrid(
    piece: UnstructuredPiece(
        numberOfPoints: 3,
        numberOfCells: 1,
        points: Points(
            dataArray: try .points([
                0.0 as Float, 0.0, 0.0,
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
            ])
        ),
        cells: Cells(
            connectivity: .indices(name: "connectivity", values: [0 as Int32, 1, 2]),
            offsets: .indices(name: "offsets", values: [3 as Int32]),
            types: .cellTypes([.triangle])
        )
    ),
    fieldData: .timeValue(5.0 as Double)
)

try VTKWriter.write(VTUFile(unstructuredGrid: grid), to: URL(fileURLWithPath: "cells.vtu"))
```

### Write a `.pvd` time series

```swift
import Foundation
import VTKKit

let collection = try PVDFile.series(
    files: ["frame_0000.vtp", "frame_0001.vtp"],
    timesteps: [0.0, 1.0],
    group: "default",
    part: 0
)

try VTKWriter.write(collection, to: URL(fileURLWithPath: "series.pvd"))
```

## Notes

- `FieldData(TimeValue)` is emitted at the dataset level under `PolyData`, which
  matches the VTK XML convention for time metadata. `UnstructuredGrid` gets the
  same helper via `FieldData.timeValue(...)` or `withTimeValue(...)`.
- `PVDFile` is a ParaView-style collection file that points at VTK XML dataset
  files such as `.vtp` and `.vtu`.
- Binary payloads are written with VTK's standard length-prefixed framing and
  base64 encoding. Appended payloads are emitted in a base64-encoded
  `<AppendedData>` section with per-array offsets.
- `headerType` controls the binary length prefix size for inline binary and
  appended arrays. The package currently supports `UInt32` and `UInt64`.
- Validation catches common exporter mistakes such as wrong component counts,
  tuple-count mismatches, and inconsistent cell connectivity/offset arrays.
- `Codable` is useful for testing, intermediate representations, and persistence
  of the document model, but not as the XML backend for the VTK file format.
- Compression, zero-copy buffer APIs, streaming `.pvd` mutation, and parallel
  dataset formats are still out of scope. Generated binary XML is uncompressed.
