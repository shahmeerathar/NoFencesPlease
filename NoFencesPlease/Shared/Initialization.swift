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
    var nodes: [[MRFNode]]
    
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
    private var motionDiameter: Int { (motionRadius * 2) + 1 }
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
                print("Calculating edge flow for image \(index)")
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
        var MRF = MarkovRandomField(width: Int(referenceImageGray.extent.size.width),
                                    height: Int(referenceImageGray.extent.size.height),
                                    motionRadius: motionRadius)
        beliefPropagation(MRF: &MRF, motionField: edgeFlow)
        
        return edgeFlow
    }
    
    private func calculateDataCost() -> Int {
        // TODO: Implement NCC
        return 0
    }
    
    private func calculateSmoothnessCost() -> Int {
        // TODO: Implement w12 cost
        return 0
    }
    
    private func beliefPropagation(MRF: inout MarkovRandomField, motionField: MotionField) {
        // TODO: Implement loopy BP algorithm
        for round in 0..<numBeliefPropagationIterations {
            print("Initiating message passing round \(round)")
            for direction in Direction.allCases {
                print("Sending messages \(direction)")
                messagePassingRound(MRF: &MRF, direction: direction)
            }
        }
        
        findBestLabelling()
    }
    
    private func messagePassingRound(MRF: inout MarkovRandomField, direction: Direction) {
        switch direction {
        case .left:
            for y in 0..<MRF.height {
                for x in 1..<MRF.width {
                    print("Pixel: \(y), \(x)")
                    sendMessage(MRF: &MRF, y: y, x: x, direction: direction)
                }
            }
        case .up:
            for y in 1..<MRF.height {
                for x in 0..<MRF.width {
                    print("Pixel: \(y), \(x)")
                    sendMessage(MRF: &MRF, y: y, x: x, direction: direction)
                }
            }
        case .right:
            for y in 0..<MRF.height {
                for x in 0..<MRF.width - 1 {
                    print("Pixel: \(y), \(x)")
                    sendMessage(MRF: &MRF, y: y, x: x, direction: direction)
                }
            }
        case .down:
            for y in 0..<MRF.height - 1 {
                for x in 1..<MRF.width {
                    print("Pixel: \(y), \(x)")
                    sendMessage(MRF: &MRF, y: y, x: x, direction: direction)
                }
            }
        }
    }
    
    private func sendMessage(MRF: inout MarkovRandomField, y: Int, x: Int, direction: Direction) {
        var newMessage = Array(repeating: Array(repeating: 0, count: motionDiameter), count: motionDiameter)
        
        for yLabelOuter in 0..<motionDiameter {
            for xLabelOuter in 0..<motionDiameter {
                var minCost = Int.max
                
                for yLabelInner in 0..<motionDiameter {
                    for xLabelInner in 0..<motionDiameter {
                        var cost = 0
                        
                        cost += calculateSmoothnessCost()
                        cost += calculateDataCost()
                        let node = MRF.nodes[y][x]
                        
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
            MRF.nodes[y][x - 1].messages[Direction.right.rawValue] = newMessage
        case .up:
            MRF.nodes[y - 1][x].messages[Direction.down.rawValue] = newMessage
        case .right:
            MRF.nodes[y][x + 1].messages[Direction.left.rawValue] = newMessage
        case .down:
            MRF.nodes[y + 1][x].messages[Direction.up.rawValue] = newMessage
        }
    }
    
    private func findBestLabelling() {
        // TODO: Find best label for pixel
    }
}
