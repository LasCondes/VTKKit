# Changelog

## 0.11.0 - 2026-10-06

- Require Swift 6.4 and Xcode 27, while keeping Swift 6 language mode.
- Raise all supported Apple platform minimums to version 27: macOS,
  iOS/iPadOS, tvOS, watchOS, and visionOS.
- Add GitHub Actions debug and release testing with the real VTK Python reader
  runtime, plus compile checks for iOS, tvOS, watchOS, and visionOS.
- Document the toolchain/platform requirements and automated verification.

This release raises deployment targets and the minimum Swift toolchain.
Applications supporting earlier environments should stay on the 0.10.x line.
The VTK document APIs and serialized formats are unchanged.

## 0.10.0 — 2026-10-03

- Add `UnstructuredGrid`/`VTUFile.triangleMesh` and `tetrahedronMesh` builders,
  with typed connectivity, checked offsets, point/cell fields and file options.
- Add optional positive tetrahedron orientation without reordering cell fields.
- Validate topology indices, component/scalar types, array uniqueness, linear
  cell sizes and bounded connectivity/face offsets. Support mixed polyhedron
  meshes with the `-1` face-offset convention for other cells.
- Decode topology from raw binary buffers without a temporary ASCII conversion,
  preserving byte order and rejecting overflow or malformed storage.
- Include `NumberOfTuples` for FieldData so readers load TimeValue and other
  dataset metadata correctly.
- Repair compressed exports: initialize stream input after the compression
  state, separate compressed header/payload base64 framing, emit standard zlib
  blocks and raw LZ4 blocks, and use the canonical final partial-block size.
  These changes affect both encoded and streaming files.
- Validate PVD series and loaded document structure. Commit writer snapshots
  after successful persistence and use atomic canonical rewrites.
- Add real VTK reader checks, configurable with `VTKKIT_PYTHON`, and bound
  subprocess runtimes while draining diagnostics to avoid test deadlocks.

Existing public entry points and document models remain available. Inputs that
previously produced unsafe or invalid VTK files now throw `VTKWriter.Error`.
Malformed compressed files written by earlier revisions should be regenerated.
