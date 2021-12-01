//
//  Initialization.swift
//  NoFencesPlease
//
//  Created by Muhammad Shahmeer Athar on 2021-11-16.
//

import Foundation
import CoreImage

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
        messages = Array(repeating: Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter), count: 4)
    }
}

struct MarkovRandomField {
    var width: Int
    var height: Int
    let nodes: [[MRFNode]]
    
    init(width: Int, height: Int, motionRadius: Int) {
        self.width = width
        self.height = height
        nodes = Array(repeating: Array(repeating: MRFNode(motionRadius: motionRadius), count: width), count: height)
    }
}

struct MotionField {
    // TODO: Implement struct
}

class Initializer {
    private var ciContext: CIContext
    private let patchRadius = 2
    private let motionRadius = 15
    private let numBeliefPropagationIterations = 40
    
    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }
    
    func makeInitialGuesses(grays: [CIImage?], edges: [CIImage?]) {
//        var initialObstructions = nil
//        var initialBackground = nil
//        var initialAlpha = nil
//        var obstructionMotions = nil
//        var backgroundMotions = nil
        
        var edgeFlows: [MotionField?] = Array(repeating: nil, count: grays.count)
        let refFrameIndex = grays.count / 2
        
        for index in 0..<grays.count {
            if (index != refFrameIndex) {
                let edgeFlow = calculateEdgeFlow(referenceImageGray: grays[refFrameIndex]!,
                                                 comparisonImageGray: grays[index]!,
                                                 referenceImageEdges: edges[refFrameIndex]!,
                                                 comparisonImageEdges: edges[index]!)
                edgeFlows[index] = edgeFlow
            }
        }
    }
    
    private func calculateEdgeFlow(referenceImageGray: CIImage, comparisonImageGray: CIImage, referenceImageEdges: CIImage, comparisonImageEdges: CIImage) -> MotionField {
        // Edge flow = motion field from referenceImageEdges to comparisonImageEdges
        let edgeFlow = MotionField()
        let MRF = MarkovRandomField(width: Int(referenceImageGray.extent.size.width),
                                    height: Int(referenceImageGray.extent.size.height),
                                    motionRadius: motionRadius)
        beliefPropagation(MRF: MRF, motionField: edgeFlow)
        
        return edgeFlow
    }
    
    private func calculateDataCost() {
        // TODO: Implement NCC
    }
    
    private func calculateSmoothnessCost() {
        // TODO: Implement w12 cost
    }
    
    private func beliefPropagation(MRF: MarkovRandomField, motionField: MotionField) {
        // TODO: Implement loopy BP algorithm
        for _ in 0..<numBeliefPropagationIterations {
            for direction in Direction.allCases {
                messagePassingRound(MRF: MRF, direction: direction)
            }
        }
        
        findBestLabelling()
    }
    
    private func messagePassingRound(MRF: MarkovRandomField, direction: Direction) {
        switch direction {
        case .left:
            for y in 0..<MRF.height {
                for x in 1..<MRF.width {
                    sendMessage(MRF: MRF, y: y, x: x, direction: .left)
                }
            }
        case .up:
            for y in 1..<MRF.height {
                for x in 0..<MRF.width {
                    sendMessage(MRF: MRF, y: y, x: x, direction: .up)
                }
            }
        case .right:
            for y in 0..<MRF.height {
                for x in 0..<MRF.width - 1 {
                    sendMessage(MRF: MRF, y: y, x: x, direction: .right)
                }
            }
        case .down:
            for y in 0..<MRF.height - 1 {
                for x in 1..<MRF.width {
                    sendMessage(MRF: MRF, y: y, x: x, direction: .down)
                }
            }
        }
    }
    
    private func sendMessage(MRF: MarkovRandomField, y: Int, x: Int, direction: Direction) {
        switch direction {
        case .left:
            <#code#>
        case .up:
            <#code#>
        case .right:
            <#code#>
        case .down:
            <#code#>
        }
    }
    
    private func findBestLabelling() {
        // TODO: Find best label for pixel
    }
}
