//
//  Initialization.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-16.
//

import Foundation
import CoreImage
import Metal
import MetalKit

enum Direction: Int, CaseIterable {
    // Raw value defines index in messages for MRFNode
    case left = 0
    case up = 1
    case right = 2
    case down = 3
}

struct MRFNode {
    let observableValue: Int
    var bestLabel: Int
    var messages: [[[Int]]] // Direction, then nested labels in grid by index
    
    init(motionRadius: Int) {
        let motionDiameter = (motionRadius * 2) + 1
        
        observableValue = 0
        bestLabel = 0
        // message at index [][motionRadius][motionRadius] should be ignored because zero offset
        // offset = directionalLabel - motionRadius
        messages = Array(repeating: Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter), count: Direction.allCases.count)
    }
}

struct MarkovRandomField {
    var width: Int
    var height: Int
    var nodes: [[MRFNode]]
    
    init(width: Int, height: Int, motionRadius: Int) {
        self.width = width
        self.height = height
        nodes = Array(repeating: Array(repeating: MRFNode(motionRadius: motionRadius), count: width), count: height)
    }
}

class Initializer {
    private let ciContext: CIContext
    
    private let motionRadius: Int
    private var motionDiameter: Int
    private let patchRadius = 2
    private let numBeliefPropagationIterations = 20
    
    private var imageHeight = 0 // Required for Metal kernel
    private var imageWidth = 0 // Required for Metal kernel
    // MRF goes to the Metal kernel as a flattened array of:
    // y coordinate -> x coordinate -> message diameter y coord -> message diameter x coord -> direction 
    private var MRFSize = 0
    
    // Metal
    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    private let commandQueue: MTLCommandQueue
    private let defaultLib: MTLLibrary
    private let loopyBPMessagePassing: MTLFunction
    private let loopyBPPipelineState: MTLComputePipelineState
    private let getBeliefs: MTLFunction
    private let getBeliefsPipelineState: MTLComputePipelineState
    
    private let textureLoaderOptions = [MTKTextureLoader.Option.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                        MTKTextureLoader.Option.textureStorageMode: MTLResourceOptions.storageModePrivate.rawValue]
    
    private var refImageTexture: MTLTexture? = nil
    
    private let threadsPerGroupWidth: Int
    private let threadsPerGroupHeight: Int
    private var threadsPerGroup = MTLSizeMake(0, 0, 0)
    private var threadsPerGrid = MTLSizeMake(0, 0, 0)
    
    var output: [CIImage?] = Array(repeating: nil, count: 5)
    
    init(ciContext: CIContext, motionRadius: Int) {
        self.ciContext = ciContext
        self.motionRadius = motionRadius
        motionDiameter = (motionRadius * 2) + 1
        
        // Metal: expensive operations
        device = Metal.MTLCreateSystemDefaultDevice()!
        textureLoader = MTKTextureLoader(device: device)
        commandQueue = device.makeCommandQueue()!
        defaultLib = device.makeDefaultLibrary()!
        
        loopyBPMessagePassing = defaultLib.makeFunction(name: "beliefPropagationMessagePassingRound")!
        loopyBPPipelineState = try! device.makeComputePipelineState(function: loopyBPMessagePassing)
        getBeliefs = defaultLib.makeFunction(name: "getBeliefs")!
        getBeliefsPipelineState = try! device.makeComputePipelineState(function: getBeliefs)
        
        threadsPerGroupWidth = loopyBPPipelineState.threadExecutionWidth
        threadsPerGroupHeight = loopyBPPipelineState.maxTotalThreadsPerThreadgroup / threadsPerGroupWidth
    }
    
    func makeInitialGuesses(grays: [CIImage?], edgeMaps: [CIImage?], edgeCoordinates: [Array<[Int]>?]) -> [CIImage?] {
//        var initialObstructions = nil
//        var initialBackground = nil
//        var initialAlpha = nil
//        var obstructionMotions = nil
//        var backgroundMotions = nil
        
        var edgeFlows: [MTLTexture?] = Array(repeating: nil, count: grays.count)
        
        let refFrameIndex = grays.count / 2
        let refImage = ciContext.createCGImage(grays[refFrameIndex]!, from: grays[refFrameIndex]!.extent)!
        refImageTexture = try! textureLoader.newTexture(cgImage: refImage, options: textureLoaderOptions)
        imageHeight = Int(refImage.height)
        imageWidth = Int(refImage.width)
        MRFSize = imageHeight * imageWidth * Direction.allCases.count * motionDiameter * motionDiameter
        
        for index in 0..<grays.count {
            if (index != refFrameIndex) {
                print("Calculating edge flow for image \(index)")
                threadsPerGroup = MTLSizeMake(min(loopyBPPipelineState.maxTotalThreadsPerThreadgroup, edgeCoordinates[index]!.count), 1, 1)
                threadsPerGrid = MTLSizeMake(edgeCoordinates[index]!.count, 1, 1)
                // These edge flows should be *from* an image to the reference image
                let edgeFlowTexture = beliefPropagation(edgeMap: edgeMaps[index]!, image: grays[index]!, referenceImageGray: grays[refFrameIndex]!, edgeCoordinates: edgeCoordinates[index]!)
                let edgeFlowImage = CIImage(mtlTexture: edgeFlowTexture, options: nil)
                edgeFlows[index] = edgeFlowTexture
                output[index] = edgeFlowImage
                break
            }
        }
        
        return output
    }
    
    func getLabelOffset(label: Int) -> Int {
        return label - motionRadius
    }
    
    private func beliefPropagation(edgeMap: CIImage, image: CIImage, referenceImageGray: CIImage, edgeCoordinates: Array<[Int]>) -> MTLTexture {
        // Create textures to pass to Metal kernel
        let cgImage = ciContext.createCGImage(image, from: image.extent)!
        let imageTexture = try! textureLoader.newTexture(cgImage: cgImage, options: textureLoaderOptions)
        
        let cgEdgeMap = ciContext.createCGImage(edgeMap, from: edgeMap.extent)!
        let edgeMapTexture = try! textureLoader.newTexture(cgImage: cgEdgeMap, options: textureLoaderOptions)
        
        let MRFBufferOne = device.makeBuffer(length: MemoryLayout<Float>.stride * MRFSize, options: MTLResourceOptions.storageModeShared)
        let MRFBufferTwo = device.makeBuffer(length: MemoryLayout<Float>.stride * MRFSize, options: MTLResourceOptions.storageModeShared)
        
        let edgeCoordByteCount = MemoryLayout<Int32>.stride * 2 * edgeCoordinates.count
        let edgeCoordPtr = UnsafeMutableRawPointer.allocate(byteCount: edgeCoordByteCount, alignment: MemoryLayout<Int32>.alignment)
        for (index, element) in edgeCoordinates.enumerated() {
            var offsetPtr = edgeCoordPtr.advanced(by: 2 * MemoryLayout<Int32>.stride * index)
            offsetPtr.storeBytes(of: Int32(element[0]), as: Int32.self)
            offsetPtr = offsetPtr.advanced(by: MemoryLayout<Int32>.stride)
            offsetPtr.storeBytes(of: Int32(element[1]), as: Int32.self)
        }
        let edgeCoordBuffer = device.makeBuffer(bytes: edgeCoordPtr, length: edgeCoordByteCount, options: .storageModeShared)
        
        // We keep flip flopping every iteration between which buffer is new and old to prevent copying slowing down our algorithm
        let MRFBuffers = [MRFBufferOne, MRFBufferTwo]
        var oldBuffer = 0
        var newBuffer = 1
        
        // Direction offsets per coordinate: [X Offset, Y Offset]
        let DirectionOffsets = [Direction.left: [Int32(-1), Int32(0)],
                                Direction.up: [Int32(0), Int32(-1)],
                                Direction.right: [Int32(1), Int32(0)],
                                Direction.down: [Int32(0), Int32(1)]]
        
        for round in 0..<numBeliefPropagationIterations {
            print("Initiating message passing round \(round)")
            
            for direction in Direction.allCases {
                print("Sending messages \(direction)")
                
                var mtlDir = Int32(direction.rawValue)
                var mtlDirOffset = DirectionOffsets[direction]!
                let MRFBuffer = MRFBuffers[oldBuffer]
                let newMRFBuffer = MRFBuffers[newBuffer]
                
                // Setting up and executing Metal kernel for message passing round
                let commandBuffer = commandQueue.makeCommandBuffer()!
                let encoder = commandBuffer.makeComputeCommandEncoder()!
                encoder.setComputePipelineState(loopyBPPipelineState)
                
                encoder.setTexture(imageTexture, index: 0)
                encoder.setTexture(refImageTexture, index: 1)
                encoder.setTexture(edgeMapTexture, index: 2)
                encoder.setBytes(&imageHeight, length: MemoryLayout<Int32>.stride, index: 0)
                encoder.setBytes(&imageWidth, length: MemoryLayout<Int32>.stride, index: 1)
                encoder.setBytes(&motionDiameter, length: MemoryLayout<Int32>.stride, index: 2)
                encoder.setBytes(&mtlDir, length: MemoryLayout<Int32>.stride, index: 3)
                encoder.setBytes(&mtlDirOffset, length: MemoryLayout<Int32>.stride * 2, index: 4)
                encoder.setBuffer(MRFBuffer, offset: 0, index: 5)
                encoder.setBuffer(newMRFBuffer, offset: 0, index: 6)
                encoder.setBuffer(edgeCoordBuffer, offset: 0, index: 7)
                
                encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                
                encoder.endEncoding()
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                // Flip which buffer is new/old
                oldBuffer = 1 - oldBuffer
                newBuffer = 1 - newBuffer
            }
        }
        
        return findBestLabelling(MRF: MRFBuffers[oldBuffer]!)
    }
    
    private func findBestLabelling(MRF: MTLBuffer) -> MTLTexture {
        print("\nFinding best labelling\n\n")
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder =  commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(getBeliefsPipelineState)
        
        let edgeFlowTextureDescriptor = MTLTextureDescriptor()
        edgeFlowTextureDescriptor.pixelFormat = MTLPixelFormat.rgba8Unorm
        edgeFlowTextureDescriptor.usage = [MTLTextureUsage.shaderWrite, MTLTextureUsage.shaderRead]
        edgeFlowTextureDescriptor.width = imageWidth
        edgeFlowTextureDescriptor.height = imageHeight
        let edgeFlow = device.makeTexture(descriptor: edgeFlowTextureDescriptor)!
        
        encoder.setTexture(edgeFlow, index: 0)
        encoder.setBuffer(MRF, offset: 0, index: 0)
        encoder.setBytes(&motionDiameter, length: MemoryLayout<Int32>.stride, index: 1)
        encoder.setBytes(&imageWidth, length: MemoryLayout<Int32>.stride, index: 2)
        
        threadsPerGroup = MTLSizeMake(getBeliefsPipelineState.threadExecutionWidth, getBeliefsPipelineState.maxTotalThreadsPerThreadgroup / getBeliefsPipelineState.threadExecutionWidth, 1)
        threadsPerGrid = MTLSizeMake(edgeFlow.width, edgeFlow.height, 1)
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return edgeFlow
    }
    
    // MARK: Functions for CPU-based loopy belief propagation - not currently used
    
    private func calculateDataCost(image: CIImage, imageY: Int, imageX: Int, refImage: CIImage, refImageY: Int, refImageX: Int) -> Int {
        // TODO: Implement NCC
        return 1
    }
    
    private func calculateSmoothnessCost() -> Int {
        // TODO: Implement w12 cost
        return 0
    }
    
    private func messagePassingRound(previousMRF: MarkovRandomField, direction: Direction, edgeCoordinates: Set<[Int]>, image: CIImage, refImage: CIImage) -> MarkovRandomField {
        var newMRF = MarkovRandomField(width: previousMRF.width, height: previousMRF.height, motionRadius: motionRadius)
        
        for (index, edgeCoordinate) in edgeCoordinates.enumerated() {
            let yCoord = edgeCoordinate[0]
            let xCoord = edgeCoordinate[1]
            print("Coordinates: \(edgeCoordinate) (\(index + 1) of \(edgeCoordinates.count))")
            sendMessage(previousMRF: previousMRF, newMRF: &newMRF, y: yCoord, x: xCoord, direction: direction, edgeCoordinates: edgeCoordinates, image: image, refImage: refImage)
        }
        
        return newMRF
    }
    
    private func sendMessage(previousMRF: MarkovRandomField, newMRF: inout MarkovRandomField, y: Int, x: Int, direction: Direction, edgeCoordinates: Set<[Int]>, image: CIImage, refImage: CIImage) {
        var newMessage = Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter)
        
        for yLabelOuter in 0..<motionDiameter {
            for xLabelOuter in 0..<motionDiameter {
                var minCost = Int.max
                
                for yLabelInner in 0..<motionDiameter {
                    for xLabelInner in 0..<motionDiameter {
                        let yOffset = getLabelOffset(label: yLabelOuter)
                        let xOffset = getLabelOffset(label: xLabelOuter)
                        
                        var cost = calculateDataCost(image: image, imageY: y, imageX: x, refImage: refImage, refImageY: y + yOffset, refImageX: x + xOffset)
                        cost += calculateSmoothnessCost()
                        let node = previousMRF.nodes[y][x]
                        
                        for directionCase in Direction.allCases {
                            if direction != directionCase {
                                cost += node.messages[directionCase.rawValue][yLabelInner][xLabelInner]
                            }
                        }
                        
                        minCost = min(minCost, cost)
                    }
                }
                
                newMessage[yLabelOuter][xLabelOuter] = minCost
            }
        }
        
        switch direction {
        case .left:
            newMRF.nodes[y][x - 1].messages[Direction.right.rawValue] = newMessage
        case .up:
            newMRF.nodes[y - 1][x].messages[Direction.down.rawValue] = newMessage
        case .right:
            newMRF.nodes[y][x + 1].messages[Direction.left.rawValue] = newMessage
        case .down:
            newMRF.nodes[y + 1][x].messages[Direction.up.rawValue] = newMessage
        }
    }
}
