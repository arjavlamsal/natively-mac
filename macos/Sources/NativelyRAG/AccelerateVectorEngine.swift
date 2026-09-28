import Foundation
import Accelerate

/// High-throughput vector mathematics powered by Apple Silicon's Accelerate framework.
public enum AccelerateVectorEngine {
    
    /// Computes the cosine similarity between two float vectors using SIMD instructions.
    /// Returns 0.0 if vectors have unequal dimensions or zero magnitude.
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        var dot: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        
        var normASq: Float = 0.0
        vDSP_svesq(a, 1, &normASq, vDSP_Length(a.count))
        
        var normBSq: Float = 0.0
        vDSP_svesq(b, 1, &normBSq, vDSP_Length(b.count))
        
        let denominator = sqrt(normASq) * sqrt(normBSq)
        if denominator > 0 {
            return dot / denominator
        }
        return 0.0
    }
    
    /// Computes the dot product of two float vectors.
    public static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        return dot
    }
    
    /// Computes the L2 norm (Euclidean length) of a float vector.
    public static func euclideanNorm(_ a: [Float]) -> Float {
        guard !a.isEmpty else { return 0.0 }
        var sumSquares: Float = 0.0
        vDSP_svesq(a, 1, &sumSquares, vDSP_Length(a.count))
        return sqrt(sumSquares)
    }
    
    /// Returns an L2-normalized unit vector.
    public static func normalize(_ v: [Float]) -> [Float] {
        let norm = euclideanNorm(v)
        guard norm > 0 else { return v }
        var result = v
        var divisor = norm
        vDSP_vsdiv(v, 1, &divisor, &result, 1, vDSP_Length(v.count))
        return result
    }
}
