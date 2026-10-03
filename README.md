# VTKKit

`VTKKit` is a small Swift package for writing VTK PolyData (`.vtp`),
parallel PolyData (`.pvtp`), UnstructuredGrid (`.vtu`), parallel
UnstructuredGrid (`.pvtu`), and PVD collection (`.pvd`) files without taking a
dependency on a larger engine or app codebase.

The package targets Swift 6 and uses plain Swift value types for the document
model. Those types are `Codable`, but XML emission stays custom because VTK XML
does not map cleanly onto Foundation's `Codable` support without adding an XML
encoder dependency.

## Installation

Add the package to your Swift package dependencies:

```swift
.package(url: "https://github.com/LasCondes/VTKKit.git", from: "0.10.0")
```

Then add `VTKKit` to the consuming target's dependencies, or add the same
repository URL through Xcode's Package Dependencies settings.

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
- High-level builders for point clouds, triangle/polygon surfaces, unstructured triangle/tetrahedron meshes, polyhedron cells, and PVD time series
- Optional positive tetrahedron orientation with cell-data ordering preserved
- Optional ear-clipping triangulation for simple planar concave polygons
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

let robustTriangulatedFile = try VTKFile.robustTriangulatedPolygonMesh(
    points: [
        0.0 as Float, 0.0, 0.0,
        2.0, 0.0, 0.0,
        2.0, 1.0, 0.0,
        1.0, 0.4, 0.0,
        0.0, 1.0, 0.0,
    ],
    polygons: [[0, 1, 2, 3, 4]],
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

### Write a tetrahedron mesh with cell fields

```swift
import Foundation
import VTKKit

let file = try VTUFile.tetrahedronMesh(
    points: [
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ],
    tetrahedronIndices: [1, 0, 2, 3] as [Int64],
    orientation: .positive,
    cellData: CellData(
        scalarsName: "Region",
        dataArray: [.scalars(name: "Region", values: [7] as [Int32], format: .appended)]
    ),
    fieldData: .timeValue(0.25 as Double),
    options: .init(headerType: .uInt64, compression: .zlib, dataArrayFormat: .appended)
)
try VTKWriter.write(file, to: URL(fileURLWithPath: "volume.vtu"))
```

`UnstructuredGrid` and `VTUFile` both provide `triangleMesh` and
`tetrahedronMesh` builders. Points are flat xyz coordinates; indices are flat
groups of three or four. Integer literals default to `Int32`; typed arrays can
use `Int64` or another supported integer type. Generated offsets must fit that
type. Point/cell fields are checked against mesh sizes before a builder returns.

The default `.preserve` orientation keeps the supplied node order. `.positive`
enforces [VTK's tetrahedron right-hand rule](https://vtk.org/doc/nightly/html/classvtkTetra.html),
swapping the first two nodes when needed without reordering cells or their
associated fields. It rejects zero-volume cells. Edge normalization avoids
cubic determinant overflow/underflow for very large or small mesh units. All
coordinates supplied to these builders must be finite.

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

### Build a globally timestep-sorted multi-group `.pvd`

```swift
import Foundation
import VTKKit

let collection = try PVDFile.series(
    groups: [
        .init(
            group: "static",
            files: ["static.vtp", "static.vtp"],
            timesteps: [0.0, 1.0],
            part: 0
        ),
        .init(
            group: "dynamic",
            files: ["frame_0000.vtp", "frame_0001.vtp"],
            timesteps: [0.0, 1.0],
            part: 0
        ),
    ]
)
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
  Field arrays include `NumberOfTuples`, which VTK readers need to load metadata.
- `PVDFile` is a ParaView-style collection file that points at VTK XML dataset
  files such as `.vtp` and `.vtu`.
- Binary payloads are written with VTK's standard length-prefixed framing and
  base64 encoding. Appended payloads are emitted in a base64-encoded
  `<AppendedData>` section with per-array offsets.
- Serial `.vtp` and `.vtu` writes stream those payloads to disk instead of
  building one giant XML `String` before writing the file.
- When `compression` is set on `VTKFile` or `VTUFile`, binary and appended
  arrays are chunked and compressed using the VTK XML compressor header format.
  Compressed headers and payloads are base64-encoded separately. ZLib blocks use
  RFC 1950 framing; LZ4 blocks use the raw format expected by VTK; LZMA uses XZ.
- `headerType` controls the binary length prefix size for inline binary and
  appended arrays. The package currently supports `UInt32` and `UInt64`.
- `VTKXMLFileOptions` gives one place to control `byteOrder`, `headerType`,
  `compression`, and `dataArrayFormat` for higher-level file builders.
- `PVDFile.series(groups:)` merges multiple groups and sorts the combined
  collection by timestep while preserving the caller's group order as the
  tie-breaker for identical timesteps.
- `.pvtp` and `.pvtu` files describe piece metadata and source files. The piece
  datasets themselves are still ordinary `.vtp` and `.vtu` files.
- `PVDSeriesWriter` appends by truncating the closing footer and writing new
  `<DataSet />` lines in place when the file uses the package's canonical PVD
  layout, falling back to a full rewrite only when needed.
- `triangulatedPolygonMesh` still offers the fast first-vertex fan path via
  `strategy: .fan`. `robustTriangulatedPolygonMesh` uses ear clipping for
  simple planar polygons without holes, and rejects self-intersecting or
  non-planar input instead of emitting invalid triangles.
- Validation catches common exporter mistakes such as wrong component counts,
  tuple-count mismatches, out-of-range point IDs, duplicate topology arrays,
  invalid cell sizes and unsafe connectivity/face offsets. Topology is decoded
  directly from binary buffers, without first creating an ASCII copy. The raw
  API can represent higher-order cell codes; cardinality checks cover the cell
  types in `VTKCellType`.
- PVD times must be finite, part numbers nonnegative and file references
  nonempty. Invalid or failed mutations do not advance `PVDSeriesWriter`'s
  snapshot; canonical rewrites are atomic. Loading validates the collection
  document structure.
- `Codable` is useful for testing, intermediate representations, and persistence
  of the document model, but not as the XML backend for the VTK file format.
- Reader-driven compatibility tests are included for VTK Python and ParaView,
  and they automatically skip when those runtimes are not installed.

## Verification

```sh
swift test -c release
python3 -m venv .build/vtk-python
.build/vtk-python/bin/python -m pip install -r Tests/requirements-vtk.txt
VTKKIT_PYTHON="$PWD/.build/vtk-python/bin/python" swift test -c release
```

The optional Python environment is only for tests. VTKKit itself has no Python
or third-party runtime dependency. Reader tests check triangle/tetrahedron
geometry, scalar/vector fields, time metadata and orientation across 11 ASCII,
inline and appended configurations, both byte orders, UInt32/UInt64 headers,
all three compressors and multiple compression blocks. They also verify the
PolyData and parallel wrappers. The latest local run used VTK 9.7.1.

ParaView PVD-reader verification runs when `pvpython` is on `PATH`. It is
independent of the VTK Python checks. See [CHANGELOG.md](CHANGELOG.md) for the
compatibility fixes and stricter validation behavior.
