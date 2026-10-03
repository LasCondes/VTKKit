# Changelog

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
