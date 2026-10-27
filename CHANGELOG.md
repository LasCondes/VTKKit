# Changelog

## 0.11.2 - 2026-10-27

- Lower the minimum Swift tools version to 6.3 and all supported Apple deployment
  targets to 26, restoring compatibility without changing library implementation,
  public APIs or VTK file formats.
- Keep the Xcode 27 reader-backed tests and platform builds, and add debug/release
  reader-backed CI coverage using Swift 6.3 on Linux.
- Limit positive Linux reader fixtures to its supported compressors, preserving
  all Apple compressor fixtures and explicit unsupported-compressor rejection tests.
- Validation: 43 macOS tests and 44 Swift 6.3.3 Linux tests pass in both debug and
  release with independent VTK 9.7.1 readers; all five Apple platform builds declare
  a 26.0 minimum. Library implementation files are unchanged.

## 0.11.1 - 2026-10-26

- Build on Windows and other non-Apple platforms, carrying the 0.10.1 fixes
  forward (see 0.10.1 below).

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

## 0.10.1 — 2026-10-26

- Build on Windows (and other non-Apple platforms).
- Stop importing `simd`. Triangulation now uses standard-library `SIMD3`
  arithmetic, so the build no longer depends on whichever module named `simd`
  happens to be visible (off Apple, another dependency's module could satisfy
  the import in one configuration and not another).
- Gate Apple's Compression framework on Darwin. Elsewhere, zlib output is
  stored DEFLATE blocks in RFC 1950 framing, readable by VTK but uncompressed;
  LZ4 and LZMA throw `invalidCompressionConfiguration`.
- Import `FoundationXML` for `XMLParser` where Foundation does not re-export it.

No behaviour change on Apple platforms.

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
