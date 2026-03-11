# VTKKit

`VTKKit` is a small Swift package for writing VTK PolyData (`.vtp`),
parallel PolyData (`.pvtp`), UnstructuredGrid (`.vtu`), parallel
UnstructuredGrid (`.pvtu`), and PVD collection (`.pvd`) files without taking a
dependency on a larger engine or app codebase.

The package targets Swift 6 and uses plain Swift value types for the document
model. Those types are `Codable`, but XML emission stays custom because VTK XML
does not map cleanly onto Foundation's `Codable` support without adding an XML
encoder dependency.

## Scope

VTKKit currently supports a focused subset of the VTK XML ecosystem:

- ASCII, inline binary, and appended VTK PolyData XML (`.vtp`) documents
- ASCII, inline binary, and appended UnstructuredGrid XML (`.vtu`) documents
- ZLib, LZ4, and LZMA compression for inline binary and appended arrays
- Streaming `.vtp` and `.vtu` file writes for binary/appended payloads
- Dataset-level `FieldData` for metadata such as `TimeValue`
- Strongly typed `DataArray` construction for VTK scalar types
- Explicit `uncheckedType:` escape hatches when raw VTK type strings are unavoidable
- Low-copy `DataArray` construction from `ContiguousArray`, `UnsafeBufferPointer`, and `Data`
- High-level builders for point clouds, triangle meshes, polygon meshes, polyhedron cells, and PVD time series
- File-level builders driven by `VTKXMLFileOptions`
- PVD collection (`.pvd`) meta-files that reference VTK XML datasets
- Incremental `.pvd` mutation through `PVDSeriesWriter`
- Parallel dataset wrapper files for `.pvtp` and `.pvtu`
- Partition writers that emit piece files plus `.pvtp` / `.pvtu` manifests
- File-writing helpers for `.vtp`, `.pvtp`, `.vtu`, `.pvtu`, and `.pvd` output

The package is intentionally agnostic about application domain models. Callers
map their own data structures into the exported VTK document types.

It does not aim to cover every VTK dataset type. Serial `PolyData` and
`UnstructuredGrid` plus their parallel wrappers are the current focus.

## Design

- Public document types are Swift value types with `Sendable`, `Equatable`, and
  `Codable` conformance.
- Typed scalar protocols and `DataArray` convenience factories remove the most
  common type/payload mismatches at the call site.
- The untyped path stays available, but it is now an explicit `uncheckedType:`
  API instead of looking like the default constructor.
- Binary and appended writers can work directly from raw scalar buffers instead
  of forcing every export through intermediate whitespace-separated strings.
- `VTKWriter.write` streams serial `.vtp` / `.vtu` output directly to disk so
  large appended payloads do not require one giant in-memory XML string.
- XML encoding remains explicit and format-aware rather than routed through a
  generic XML encoder.
- Validation runs before serialization and reports array names plus dataset
  paths for component-count, tuple-count, and cell-layout problems.
- Compatibility tests are written to exercise real VTK/ParaView readers when
  those runtimes are installed locally.

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

### Write a point-cloud `.vtp` with file options

```swift
import Foundation
import VTKKit

let file = try VTKFile.pointCloud(
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
    options: .init(
        compression: .zlib,
        dataArrayFormat: .appended
    )
)

try VTKWriter.write(file, to: URL(fileURLWithPath: "particles.vtp"))
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

### Write a polygon mesh or triangulate polygon fans

```swift
import Foundation
import VTKKit

let polygonFile = try VTKFile.polygonMesh(
    points: [
        0.0 as Float, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
    ],
    polygons: [[0, 1, 2, 3]],
    options: .init(dataArrayFormat: .ascii)
)

let triangulatedFile = try VTKFile.triangulatedPolygonMesh(
    points: [
        0.0 as Float, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
    ],
    polygons: [[0, 1, 2, 3]],
    options: .init(dataArrayFormat: .ascii)
)
```

### Use low-copy buffer-backed arrays

```swift
import Foundation
import VTKKit

let points = ContiguousArray<Float>([
    0.0, 1.0, 2.0,
    3.0, 4.0, 5.0,
])

let array = try DataArray.points(
    contiguousValues: points,
    format: .appended
)

let legacyScalars = DataArray(
    uncheckedType: "Float32",
    name: "LegacyScalars",
    numberOfComponents: 1,
    values: ["1.0", "2.0"]
)
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

### Write polyhedron cells

```swift
import Foundation
import VTKKit

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
    options: .init(dataArrayFormat: .appended)
)
```

### Write a parallel `.pvtp` or `.pvtu` wrapper

```swift
import Foundation
import VTKKit

let template = try PolyData.pointCloud(
    points: [0.0 as Float, 1.0, 2.0],
    pointData: PointData(
        scalarsName: "Radius",
        dataArray: [.scalars(name: "Radius", values: [0.5 as Float])]
    )
)

let wrapper = try PVTPFile.collection(
    pieceSources: ["frame_0000_piece_0.vtp", "frame_0000_piece_1.vtp"],
    template: template
)

try VTKWriter.write(wrapper, to: URL(fileURLWithPath: "frame_0000.pvtp"))
```

### Write partitioned piece files plus manifest

```swift
import Foundation
import VTKKit

let pieces = [
    try PolyData.pointCloud(points: [0.0 as Float, 1.0, 2.0], format: .appended),
    try PolyData.pointCloud(points: [3.0 as Float, 4.0, 5.0], format: .appended),
]

try VTKWriter.writePartitionedPolyData(
    pieces: pieces,
    manifestURL: URL(fileURLWithPath: "frame_0000.pvtp"),
    options: .init(compression: .zlib, dataArrayFormat: .appended)
)
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

### Append to a `.pvd` series incrementally

```swift
import Foundation
import VTKKit

let writer = try PVDSeriesWriter(url: URL(fileURLWithPath: "series.pvd"))
try await writer.append(file: "frame_0000.vtp", timestep: 0.0, group: "default", part: 0)
try await writer.append(file: "frame_0001.vtp", timestep: 1.0, group: "default", part: 0)
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
- Serial `.vtp` and `.vtu` writes stream those payloads to disk instead of
  building one giant XML `String` before writing the file.
- When `compression` is set on `VTKFile` or `VTUFile`, binary and appended
  arrays are chunked and compressed using the VTK XML compressor header format.
- `headerType` controls the binary length prefix size for inline binary and
  appended arrays. The package currently supports `UInt32` and `UInt64`.
- `VTKXMLFileOptions` gives one place to control `byteOrder`, `headerType`,
  `compression`, and `dataArrayFormat` for higher-level file builders.
- `.pvtp` and `.pvtu` files describe piece metadata and source files. The piece
  datasets themselves are still ordinary `.vtp` and `.vtu` files.
- `PVDSeriesWriter` appends by truncating the closing footer and writing new
  `<DataSet />` lines in place when the file uses the package's canonical PVD
  layout, falling back to a full rewrite only when needed.
- Validation catches common exporter mistakes such as wrong component counts,
  tuple-count mismatches, and inconsistent cell connectivity/offset arrays.
- `Codable` is useful for testing, intermediate representations, and persistence
  of the document model, but not as the XML backend for the VTK file format.
- Reader-driven compatibility tests are included for VTK Python and ParaView,
  and they automatically skip when those runtimes are not installed.
