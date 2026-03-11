# VTKKit

`VTKKit` is a small Swift package for writing VTK PolyData (`.vtp`) files and
PVD collection (`.pvd`) files without taking a dependency on a larger engine or
app codebase.

It currently focuses on the subset needed by `ChuteMavenEngine`:

- VTK PolyData XML document types
- PVD collection XML document types
- File-writing helpers for `.vtp` and `.pvd` output

The package is intentionally agnostic about your domain models. Callers are
expected to map their own mesh, particle, or grid types into the exported VTK
document structs.

