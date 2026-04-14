#if canImport(Metal)
import Foundation
import Metal

private struct CircleDomainMaterializeParams {
    var elementCount: UInt32
    var logSize: UInt32
    var halfCosetInitialIndex: UInt32
    var halfCosetStepSize: UInt32
    var fieldModulus: UInt32
}

private struct CircleCodewordFFTTwiddleMaterializeParams {
    var twiddleCount: UInt32
    var stage: UInt32
    var twiddleOffset: UInt32
    var logSize: UInt32
    var halfCosetInitialIndex: UInt32
    var halfCosetStepSize: UInt32
    var fieldModulus: UInt32
}

private struct CircleLineFoldTwiddleParams {
    var pairCount: UInt32
    var fieldModulus: UInt32
}

public final class CircleDomainMaterializationPlan: @unchecked Sendable {
    public static let domainPointByteCount = 2 * MemoryLayout<UInt32>.stride
    public static let codewordTwiddleByteCount = MemoryLayout<UInt32>.stride
    public static let inverseDomainElementByteCount = QM31CanonicalEncoding.elementByteCount

    public let domain: CircleDomainDescriptor
    public let materializesDomainPoints: Bool
    public let materializesCodewordTwiddles: Bool
    public let codewordTwiddleCount: Int
    public let inverseDomainRoundCount: Int
    public let inverseDomainLayerCounts: [Int]
    public let inverseDomainLayerElementOffsets: [Int]
    public let totalInverseDomainCount: Int
    public let outputCount: Int
    public let domainPointBuffer: MTLBuffer?
    public let codewordTwiddleBuffer: MTLBuffer?
    public let inverseDomainBuffer: MTLBuffer?
    public let materializationStats: GPUExecutionStats

    private let context: MetalContext
    private let domainPointByteCount: Int
    private let codewordTwiddleByteCount: Int
    private let inverseDomainByteCount: Int

    public init(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        materializeDomainPoints: Bool,
        materializeCodewordTwiddles: Bool = false,
        inverseDomainRoundCount: Int
    ) throws {
        guard domain.isCanonical,
              domain.storageOrder == .circleDomainBitReversed,
              domain.size > 1,
              materializeDomainPoints || materializeCodewordTwiddles || inverseDomainRoundCount > 0,
              inverseDomainRoundCount >= 0,
              inverseDomainRoundCount <= Int(domain.logSize) else {
            throw AppleZKProverError.invalidInputLayout
        }

        let inverseLayout = try Self.makeInverseDomainLayout(
            inputCount: domain.size,
            roundCount: inverseDomainRoundCount
        )
        let domainPointByteCount = materializeDomainPoints
            ? try checkedBufferLength(domain.size, Self.domainPointByteCount)
            : 0
        let codewordTwiddleCount = domain.size - 1
        let codewordTwiddleByteCount = materializeCodewordTwiddles
            ? try checkedBufferLength(codewordTwiddleCount, Self.codewordTwiddleByteCount)
            : 0
        let inverseDomainByteCount = try checkedBufferLength(
            inverseLayout.totalCount,
            Self.inverseDomainElementByteCount
        )
        let createdDomainPointBuffer = materializeDomainPoints
            ? try MetalBufferFactory.makePrivateBuffer(
                device: context.device,
                length: domainPointByteCount,
                label: "AppleZKProver.CircleDomain.DomainPoints"
            )
            : nil
        let createdCodewordTwiddleBuffer = materializeCodewordTwiddles
            ? try MetalBufferFactory.makePrivateBuffer(
                device: context.device,
                length: codewordTwiddleByteCount,
                label: "AppleZKProver.CircleDomain.CodewordFFTTwiddles"
            )
            : nil
        let createdInverseDomainBuffer = inverseDomainRoundCount > 0
            ? try MetalBufferFactory.makePrivateBuffer(
                device: context.device,
                length: inverseDomainByteCount,
                label: "AppleZKProver.CircleDomain.InverseDomain"
            )
            : nil
        let materializationStats = try Self.materialize(
            context: context,
            domain: domain,
            domainPointBuffer: createdDomainPointBuffer,
            domainPointByteCount: domainPointByteCount,
            codewordTwiddleBuffer: createdCodewordTwiddleBuffer,
            codewordTwiddleCount: codewordTwiddleCount,
            inverseDomainBuffer: createdInverseDomainBuffer,
            inverseDomainLayerCounts: inverseLayout.counts,
            inverseDomainLayerElementOffsets: inverseLayout.offsets
        )

        self.context = context
        self.domain = domain
        self.materializesDomainPoints = materializeDomainPoints
        self.materializesCodewordTwiddles = materializeCodewordTwiddles
        self.codewordTwiddleCount = codewordTwiddleCount
        self.inverseDomainRoundCount = inverseDomainRoundCount
        self.inverseDomainLayerCounts = inverseLayout.counts
        self.inverseDomainLayerElementOffsets = inverseLayout.offsets
        self.totalInverseDomainCount = inverseLayout.totalCount
        self.outputCount = inverseLayout.outputCount
        self.domainPointByteCount = domainPointByteCount
        self.codewordTwiddleByteCount = codewordTwiddleByteCount
        self.inverseDomainByteCount = inverseDomainByteCount
        self.domainPointBuffer = createdDomainPointBuffer
        self.codewordTwiddleBuffer = createdCodewordTwiddleBuffer
        self.inverseDomainBuffer = createdInverseDomainBuffer
        self.materializationStats = materializationStats
    }

    public func requireDomainPointBuffer() throws -> MTLBuffer {
        guard let domainPointBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        return domainPointBuffer
    }

    public func requireCodewordTwiddleBuffer() throws -> MTLBuffer {
        guard let codewordTwiddleBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        return codewordTwiddleBuffer
    }

    public func requireInverseDomainBuffer() throws -> MTLBuffer {
        guard let inverseDomainBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        return inverseDomainBuffer
    }

    public func readDomainPoints() throws -> [CirclePointM31] {
        guard materializesDomainPoints, let domainPointBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        let data = try readBufferData(
            domainPointBuffer,
            byteCount: domainPointByteCount,
            label: "AppleZKProver.CircleDomain.DomainPointsReadback"
        )
        return data.withUnsafeBytes { rawBuffer in
            let words = rawBuffer.bindMemory(to: UInt32.self)
            return (0..<domain.size).map { index in
                CirclePointM31(
                    x: words[index * 2],
                    y: words[index * 2 + 1]
                )
            }
        }
    }

    public func readCodewordTwiddles() throws -> [UInt32] {
        guard materializesCodewordTwiddles, let codewordTwiddleBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        let data = try readBufferData(
            codewordTwiddleBuffer,
            byteCount: codewordTwiddleByteCount,
            label: "AppleZKProver.CircleDomain.CodewordFFTTwiddlesReadback"
        )
        return data.withUnsafeBytes { rawBuffer in
            let words = rawBuffer.bindMemory(to: UInt32.self)
            return Array(words.prefix(codewordTwiddleCount))
        }
    }

    public func readInverseDomainLayers() throws -> [[QM31Element]] {
        guard inverseDomainRoundCount > 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        let values = try readFlatInverseDomain()
        return try inverseDomainLayerCounts.enumerated().map { roundIndex, count in
            let offset = inverseDomainLayerElementOffsets[roundIndex]
            let end = offset.addingReportingOverflow(count)
            guard !end.overflow, end.partialValue <= values.count else {
                throw AppleZKProverError.invalidInputLayout
            }
            return Array(values[offset..<end.partialValue])
        }
    }

    public func readFlatInverseDomain() throws -> [QM31Element] {
        guard inverseDomainRoundCount > 0, let inverseDomainBuffer else {
            throw AppleZKProverError.invalidInputLayout
        }
        let data = try readBufferData(
            inverseDomainBuffer,
            byteCount: inverseDomainByteCount,
            label: "AppleZKProver.CircleDomain.InverseDomainReadback"
        )
        return try QM31CanonicalEncoding.unpackMany(
            data,
            count: totalInverseDomainCount
        )
    }

    private static func materialize(
        context: MetalContext,
        domain: CircleDomainDescriptor,
        domainPointBuffer: MTLBuffer?,
        domainPointByteCount: Int,
        codewordTwiddleBuffer: MTLBuffer?,
        codewordTwiddleCount: Int,
        inverseDomainBuffer: MTLBuffer?,
        inverseDomainLayerCounts: [Int],
        inverseDomainLayerElementOffsets: [Int]
    ) throws -> GPUExecutionStats {
        let domainPointPipeline = domainPointBuffer == nil
            ? nil
            : try context.pipeline(named: "circle_domain_points_materialize")
        let codewordTwiddlePipeline = codewordTwiddleBuffer == nil
            ? nil
            : try context.pipeline(named: "circle_codeword_fft_twiddles_materialize")
        let firstFoldPipeline = inverseDomainBuffer == nil
            ? nil
            : try context.pipeline(named: "circle_first_fold_twiddles_materialize")
        let lineFoldPipeline = inverseDomainLayerCounts.count <= 1
            ? nil
            : try context.pipeline(named: "circle_line_fold_twiddles_materialize")

        let halfCoset = try domain.halfCoset
        let xScratchByteCount = inverseDomainBuffer == nil
            ? 0
            : try checkedBufferLength(domain.halfSize, MemoryLayout<UInt32>.stride)
        let xScratchA = inverseDomainBuffer == nil
            ? nil
            : try MetalBufferFactory.makePrivateBuffer(
                device: context.device,
                length: xScratchByteCount,
                label: "AppleZKProver.CircleDomain.XScratchA"
            )
        let xScratchB = inverseDomainBuffer == nil
            ? nil
            : try MetalBufferFactory.makePrivateBuffer(
                device: context.device,
                length: xScratchByteCount,
                label: "AppleZKProver.CircleDomain.XScratchB"
            )

        let start = DispatchTime.now()
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "Circle.Domain.Materialize"

        if let domainPointBuffer, let domainPointPipeline {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            var params = CircleDomainMaterializeParams(
                elementCount: try checkedUInt32(domain.size),
                logSize: domain.logSize,
                halfCosetInitialIndex: domain.halfCosetInitialIndex.rawValue,
                halfCosetStepSize: halfCoset.stepSize.rawValue,
                fieldModulus: M31Field.modulus
            )
            encoder.label = "Circle.Domain.Materialize.Points"
            encoder.setComputePipelineState(domainPointPipeline)
            encoder.setBuffer(domainPointBuffer, offset: 0, index: 0)
            encoder.setBytes(&params, length: MemoryLayout<CircleDomainMaterializeParams>.stride, index: 1)
            context.dispatch1D(encoder, pipeline: domainPointPipeline, elementCount: domain.size)
            encoder.endEncoding()
            _ = domainPointByteCount
        }

        if let codewordTwiddleBuffer, let codewordTwiddlePipeline {
            var twiddleOffset = 0
            for stage in 0..<Int(domain.logSize) {
                let twiddleCount = domain.size >> (stage + 1)
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw AppleZKProverError.failedToCreateEncoder
                }
                var params = CircleCodewordFFTTwiddleMaterializeParams(
                    twiddleCount: try checkedUInt32(twiddleCount),
                    stage: try checkedUInt32(stage),
                    twiddleOffset: try checkedUInt32(twiddleOffset),
                    logSize: domain.logSize,
                    halfCosetInitialIndex: domain.halfCosetInitialIndex.rawValue,
                    halfCosetStepSize: halfCoset.stepSize.rawValue,
                    fieldModulus: M31Field.modulus
                )
                encoder.label = "Circle.Domain.Materialize.CodewordFFTTwiddles.\(stage)"
                encoder.setComputePipelineState(codewordTwiddlePipeline)
                encoder.setBuffer(codewordTwiddleBuffer, offset: 0, index: 0)
                encoder.setBytes(&params, length: MemoryLayout<CircleCodewordFFTTwiddleMaterializeParams>.stride, index: 1)
                context.dispatch1D(encoder, pipeline: codewordTwiddlePipeline, elementCount: twiddleCount)
                encoder.endEncoding()
                twiddleOffset += twiddleCount
            }
            guard twiddleOffset == codewordTwiddleCount else {
                throw AppleZKProverError.invalidInputLayout
            }
        }

        if let inverseDomainBuffer,
           let xScratchA,
           let xScratchB,
           let firstFoldPipeline {
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw AppleZKProverError.failedToCreateEncoder
            }
            var params = CircleDomainMaterializeParams(
                elementCount: try checkedUInt32(domain.halfSize),
                logSize: domain.logSize,
                halfCosetInitialIndex: domain.halfCosetInitialIndex.rawValue,
                halfCosetStepSize: halfCoset.stepSize.rawValue,
                fieldModulus: M31Field.modulus
            )
            encoder.label = "Circle.Domain.Materialize.FirstFoldTwiddles"
            encoder.setComputePipelineState(firstFoldPipeline)
            encoder.setBuffer(inverseDomainBuffer, offset: 0, index: 0)
            encoder.setBuffer(xScratchA, offset: 0, index: 1)
            encoder.setBytes(&params, length: MemoryLayout<CircleDomainMaterializeParams>.stride, index: 2)
            context.dispatch1D(encoder, pipeline: firstFoldPipeline, elementCount: domain.halfSize)
            encoder.endEncoding()

            var currentXBuffer = xScratchA
            var nextXBuffer = xScratchB
            var currentXCount = domain.halfSize
            for roundIndex in 1..<inverseDomainLayerCounts.count {
                let pairCount = inverseDomainLayerCounts[roundIndex]
                guard pairCount == currentXCount / 2,
                      let lineFoldPipeline else {
                    throw AppleZKProverError.invalidInputLayout
                }
                guard let lineEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw AppleZKProverError.failedToCreateEncoder
                }
                var lineParams = CircleLineFoldTwiddleParams(
                    pairCount: try checkedUInt32(pairCount),
                    fieldModulus: M31Field.modulus
                )
                lineEncoder.label = "Circle.Domain.Materialize.LineTwiddles.\(roundIndex)"
                lineEncoder.setComputePipelineState(lineFoldPipeline)
                lineEncoder.setBuffer(currentXBuffer, offset: 0, index: 0)
                lineEncoder.setBuffer(
                    inverseDomainBuffer,
                    offset: inverseDomainLayerElementOffsets[roundIndex] * Self.inverseDomainElementByteCount,
                    index: 1
                )
                lineEncoder.setBuffer(nextXBuffer, offset: 0, index: 2)
                lineEncoder.setBytes(&lineParams, length: MemoryLayout<CircleLineFoldTwiddleParams>.stride, index: 3)
                context.dispatch1D(lineEncoder, pipeline: lineFoldPipeline, elementCount: pairCount)
                lineEncoder.endEncoding()

                currentXCount = pairCount
                swap(&currentXBuffer, &nextXBuffer)
            }
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }

        let end = DispatchTime.now()
        return GPUExecutionStats(
            cpuWallSeconds: Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000,
            gpuSeconds: gpuDuration(commandBuffer)
        )
    }

    private static func makeInverseDomainLayout(
        inputCount: Int,
        roundCount: Int
    ) throws -> (counts: [Int], offsets: [Int], totalCount: Int, outputCount: Int) {
        guard inputCount > 1,
              roundCount >= 0 else {
            throw AppleZKProverError.invalidInputLayout
        }
        var counts: [Int] = []
        var offsets: [Int] = []
        counts.reserveCapacity(roundCount)
        offsets.reserveCapacity(roundCount)

        var currentCount = inputCount
        var totalCount = 0
        for _ in 0..<roundCount {
            guard currentCount > 1, currentCount.isMultiple(of: 2) else {
                throw AppleZKProverError.invalidInputLayout
            }
            let nextCount = currentCount / 2
            counts.append(nextCount)
            offsets.append(totalCount)
            let nextTotal = totalCount.addingReportingOverflow(nextCount)
            guard !nextTotal.overflow else {
                throw AppleZKProverError.invalidInputLayout
            }
            totalCount = nextTotal.partialValue
            currentCount = nextCount
        }
        return (counts, offsets, totalCount, currentCount)
    }

    private func readBufferData(
        _ buffer: MTLBuffer,
        byteCount: Int,
        label: String
    ) throws -> Data {
        let readback = try MetalBufferFactory.makeSharedBuffer(
            device: context.device,
            length: byteCount,
            label: label
        )
        guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
            throw AppleZKProverError.failedToCreateCommandBuffer
        }
        commandBuffer.label = "\(label).Command"
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw AppleZKProverError.failedToCreateEncoder
        }
        blit.label = "\(label).Copy"
        if byteCount > 0 {
            blit.copy(from: buffer, sourceOffset: 0, to: readback, destinationOffset: 0, size: byteCount)
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw AppleZKProverError.commandExecutionFailed(error.localizedDescription)
        }
        return Data(bytes: readback.contents(), count: byteCount)
    }
}

private func gpuDuration(_ commandBuffer: MTLCommandBuffer) -> Double? {
    guard commandBuffer.gpuEndTime > commandBuffer.gpuStartTime else {
        return nil
    }
    return commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
}
#endif
