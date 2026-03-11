import Foundation
import simd

public enum PolygonTriangulationStrategy: String, Sendable, Codable, CaseIterable {
    case fan
    case earClipping
}

func earClippedPolygons<
    PointScalar: VTKFloatingPointScalarValue,
    IndexScalar: VTKIntegerScalarValue
>(
    polygons: [[IndexScalar]],
    points: [PointScalar],
    datasetPath: String
) throws -> [IndexScalar] {
    guard points.count.isMultiple(of: 3) else {
        throw VTKWriter.Error.invalidComponentCount(
            arrayName: "Points",
            datasetPath: datasetPath,
            valueCount: points.count,
            numberOfComponents: 3
        )
    }

    let pointPositions = stride(from: 0, to: points.count, by: 3).map {
        SIMD3<Double>(
            Double(points[$0]),
            Double(points[$0 + 1]),
            Double(points[$0 + 2])
        )
    }

    var triangles: [IndexScalar] = []
    triangles.reserveCapacity(polygons.reduce(into: 0) { $0 += max(0, ($1.count - 2) * 3) })

    for (polygonIndex, polygon) in polygons.enumerated() {
        let polygonPath = datasetPath + "/polygon[\(polygonIndex)]"
        let normalizedPolygon = try normalizedPolygonIndices(
            polygon,
            pointCount: pointPositions.count,
            datasetPath: polygonPath
        )
        let projectedPolygon = try projectedPolygon(
            normalizedPolygon,
            pointPositions: pointPositions,
            datasetPath: polygonPath
        )
        triangles.append(
            contentsOf: try earClip(
                projectedPolygon,
                datasetPath: polygonPath
            )
        )
    }

    return triangles
}

private struct ProjectedPolygon<IndexScalar: VTKIntegerScalarValue> {
    let indices: [IndexScalar]
    let points2D: [SIMD2<Double>]
    let signedArea: Double
}

private func normalizedPolygonIndices<IndexScalar: VTKIntegerScalarValue>(
    _ polygon: [IndexScalar],
    pointCount: Int,
    datasetPath: String
) throws -> [IndexScalar] {
    var normalized = polygon
    if normalized.count > 3, normalized.first == normalized.last {
        normalized.removeLast()
    }

    guard normalized.count >= 3 else {
        throw VTKWriter.Error.invalidCellLayout(
            datasetPath: datasetPath,
            reason: "Polygon must contain at least 3 unique vertices."
        )
    }

    for index in normalized {
        guard let integerIndex = Int(exactly: index), integerIndex >= 0, integerIndex < pointCount else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Polygon references out-of-range point index '\(index)'."
            )
        }
    }

    return normalized
}

private func projectedPolygon<IndexScalar: VTKIntegerScalarValue>(
    _ polygon: [IndexScalar],
    pointPositions: [SIMD3<Double>],
    datasetPath: String
) throws -> ProjectedPolygon<IndexScalar> {
    let polygon3D = polygon.map { pointPositions[Int(exactly: $0)!] }
    let normal = newellNormal(polygon3D)
    let normalLength = simd_length(normal)
    guard normalLength > 1e-12 else {
        throw VTKWriter.Error.invalidCellLayout(
            datasetPath: datasetPath,
            reason: "Polygon is degenerate and does not define a stable plane."
        )
    }

    let unitNormal = normal / normalLength
    let origin = polygon3D[0]
    let scale = polygon3D.reduce(0.0) { current, point in
        max(current, simd_length(point - origin))
    }
    let planarityTolerance = max(1e-9, scale * 1e-6)
    for point in polygon3D {
        let distance = abs(simd_dot(unitNormal, point - origin))
        guard distance <= planarityTolerance else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Polygon is not planar within tolerance \(planarityTolerance)."
            )
        }
    }

    let axis = dominantAxis(of: unitNormal)
    let points2D = polygon3D.map { project($0, dropping: axis) }
    if isSelfIntersectingPolygon2D(points2D) {
        throw VTKWriter.Error.invalidCellLayout(
            datasetPath: datasetPath,
            reason: "Polygon is self-intersecting and cannot be triangulated."
        )
    }
    let signedArea = polygonArea(points2D)
    guard abs(signedArea) > 1e-12 else {
        throw VTKWriter.Error.invalidCellLayout(
            datasetPath: datasetPath,
            reason: "Projected polygon area is zero."
        )
    }

    return ProjectedPolygon(indices: polygon, points2D: points2D, signedArea: signedArea)
}

private func earClip<IndexScalar: VTKIntegerScalarValue>(
    _ polygon: ProjectedPolygon<IndexScalar>,
    datasetPath: String
) throws -> [IndexScalar] {
    var remaining = Array(polygon.indices.indices)
    var triangles: [IndexScalar] = []
    triangles.reserveCapacity(max(0, (polygon.indices.count - 2) * 3))

    let orientation = polygon.signedArea > 0 ? 1.0 : -1.0
    let epsilon = max(1e-12, abs(polygon.signedArea) * 1e-12)

    while remaining.count > 3 {
        var earFound = false

        for offset in remaining.indices {
            let previous = remaining[(offset + remaining.count - 1) % remaining.count]
            let current = remaining[offset]
            let next = remaining[(offset + 1) % remaining.count]

            let a = polygon.points2D[previous]
            let b = polygon.points2D[current]
            let c = polygon.points2D[next]

            let turn = crossZ(b - a, c - a) * orientation
            guard turn > epsilon else {
                continue
            }

            let containsVertex = remaining.contains { candidate in
                guard candidate != previous, candidate != current, candidate != next else {
                    return false
                }
                return pointInTriangle(
                    polygon.points2D[candidate],
                    a: a,
                    b: b,
                    c: c,
                    orientation: orientation,
                    epsilon: epsilon
                )
            }

            guard containsVertex == false else {
                continue
            }

            triangles.append(polygon.indices[previous])
            triangles.append(polygon.indices[current])
            triangles.append(polygon.indices[next])
            remaining.remove(at: offset)
            earFound = true
            break
        }

        guard earFound else {
            throw VTKWriter.Error.invalidCellLayout(
                datasetPath: datasetPath,
                reason: "Could not triangulate polygon with ear clipping. The polygon may be self-intersecting or degenerate."
            )
        }
    }

    triangles.append(polygon.indices[remaining[0]])
    triangles.append(polygon.indices[remaining[1]])
    triangles.append(polygon.indices[remaining[2]])
    return triangles
}

private func isSelfIntersectingPolygon2D(_ points: [SIMD2<Double>]) -> Bool {
    guard points.count >= 3 else {
        return false
    }

    for edgeIndex in points.indices {
        let edgeStart = points[edgeIndex]
        let edgeEnd = points[(edgeIndex + 1) % points.count]

        for otherEdgeIndex in points.indices {
            guard abs(edgeIndex - otherEdgeIndex) > 1 else {
                continue
            }
            guard edgeIndex != 0 || otherEdgeIndex != points.count - 1 else {
                continue
            }
            guard otherEdgeIndex != 0 || edgeIndex != points.count - 1 else {
                continue
            }
            guard edgeIndex < otherEdgeIndex else {
                continue
            }

            let otherStart = points[otherEdgeIndex]
            let otherEnd = points[(otherEdgeIndex + 1) % points.count]
            if segmentsIntersect(
                edgeStart,
                edgeEnd,
                otherStart,
                otherEnd
            ) {
                return true
            }
        }
    }

    return false
}

private func newellNormal(_ points: [SIMD3<Double>]) -> SIMD3<Double> {
    guard points.count >= 3 else {
        return .zero
    }

    var normal = SIMD3<Double>(repeating: 0)
    for index in points.indices {
        let current = points[index]
        let next = points[(index + 1) % points.count]
        normal.x += (current.y - next.y) * (current.z + next.z)
        normal.y += (current.z - next.z) * (current.x + next.x)
        normal.z += (current.x - next.x) * (current.y + next.y)
    }
    return normal
}

private func dominantAxis(of vector: SIMD3<Double>) -> Int {
    let absolute = SIMD3(abs(vector.x), abs(vector.y), abs(vector.z))
    if absolute.x >= absolute.y, absolute.x >= absolute.z {
        return 0
    }
    if absolute.y >= absolute.z {
        return 1
    }
    return 2
}

private func project(_ point: SIMD3<Double>, dropping axis: Int) -> SIMD2<Double> {
    switch axis {
    case 0:
        return SIMD2(point.y, point.z)
    case 1:
        return SIMD2(point.x, point.z)
    default:
        return SIMD2(point.x, point.y)
    }
}

private func polygonArea(_ polygon: [SIMD2<Double>]) -> Double {
    guard polygon.count >= 3 else {
        return 0
    }

    var area = 0.0
    for index in polygon.indices {
        let current = polygon[index]
        let next = polygon[(index + 1) % polygon.count]
        area += (current.x * next.y) - (next.x * current.y)
    }
    return area * 0.5
}

private func crossZ(_ lhs: SIMD2<Double>, _ rhs: SIMD2<Double>) -> Double {
    lhs.x * rhs.y - lhs.y * rhs.x
}

private func pointInTriangle(
    _ point: SIMD2<Double>,
    a: SIMD2<Double>,
    b: SIMD2<Double>,
    c: SIMD2<Double>,
    orientation: Double,
    epsilon: Double
) -> Bool {
    let ab = crossZ(b - a, point - a) * orientation
    let bc = crossZ(c - b, point - b) * orientation
    let ca = crossZ(a - c, point - c) * orientation
    return ab >= -epsilon && bc >= -epsilon && ca >= -epsilon
}

private func segmentsIntersect(
    _ p1: SIMD2<Double>,
    _ p2: SIMD2<Double>,
    _ q1: SIMD2<Double>,
    _ q2: SIMD2<Double>
) -> Bool {
    let epsilon = 1e-12
    let d1 = crossZ(q2 - q1, p1 - q1)
    let d2 = crossZ(q2 - q1, p2 - q1)
    let d3 = crossZ(p2 - p1, q1 - p1)
    let d4 = crossZ(p2 - p1, q2 - p1)

    if ((d1 > epsilon && d2 < -epsilon) || (d1 < -epsilon && d2 > epsilon))
        && ((d3 > epsilon && d4 < -epsilon) || (d3 < -epsilon && d4 > epsilon)) {
        return true
    }

    if abs(d1) <= epsilon && onSegment(q1, q2, p1) { return true }
    if abs(d2) <= epsilon && onSegment(q1, q2, p2) { return true }
    if abs(d3) <= epsilon && onSegment(p1, p2, q1) { return true }
    if abs(d4) <= epsilon && onSegment(p1, p2, q2) { return true }

    return false
}

private func onSegment(
    _ start: SIMD2<Double>,
    _ end: SIMD2<Double>,
    _ point: SIMD2<Double>
) -> Bool {
    let epsilon = 1e-12
    return point.x >= min(start.x, end.x) - epsilon
        && point.x <= max(start.x, end.x) + epsilon
        && point.y >= min(start.y, end.y) - epsilon
        && point.y <= max(start.y, end.y) + epsilon
}
