//
//  BeliefPropagation.metal
//  NoFencesPlease
//
//  Created by Shahmeer Athar on 2021-12-19.
//

#include <metal_stdlib>
using namespace metal;

#define NUM_DIRECTIONS 4

float dataCost() {
    return 0.0;
}

float smoothnessCost() {
    return 0.0;
}

kernel void beliefPropagationMessagePassingRound(texture2d<float, access::read> image [[texture(0)]],
                                                 texture2d<float, access::read> refImage [[texture(1)]],
                                                 texture2d<float, access::read> edgeMap [[texture(2)]],
                                                 device float* MRF [[buffer(0)]],
                                                 device float* newMRF [[buffer(1)]],
                                                 constant int& imgHeight [[buffer(2)]],
                                                 constant int& imgWidth [[buffer(3)]],
                                                 constant int& motionDiameter [[buffer(4)]],
                                                 constant int& direction [[buffer(5)]],
                                                 constant int* directionOffset [[buffer(6)]],
                                                 uint2 index [[thread_position_in_grid]])
{
    if (edgeMap.read(index)[0] == 0.0) {
        return;
    }
    
    int numMessagesPerDirection = motionDiameter * motionDiameter;
    int numMessagesPerPixel = NUM_DIRECTIONS * numMessagesPerDirection;
    
    // index[1] is the y coordinate
    // index[0] is the x coordinate
    int pixelNum = (index[1] * imgWidth) + index[0];
    int nodeIndex = pixelNum * numMessagesPerPixel;
    
    // Calculate pixel indices for recipient messages
    int x = index[0] + directionOffset[0];
    int y = index[1] + directionOffset[1];
    
    // Check if out of bounds
    if (y < 0 || y >= imgHeight || x < 0 || x >= imgWidth) {
        return;
    }
    
    // Calculate index in MRF buffer
    int recipientPixelIndex = ((y * imgWidth) + x) * numMessagesPerPixel;
    
    // Propagate beliefs!
    for (int yLabelOuter = 0; yLabelOuter < motionDiameter; yLabelOuter++) {
        for (int xLabelOuter = 0; xLabelOuter < motionDiameter; xLabelOuter++) {
            float minCost = INFINITY;
            
            for (int yLabelInner = 0; yLabelInner < motionDiameter; yLabelInner++) {
                for (int xLabelInner = 0; xLabelInner < motionDiameter; xLabelInner++) {
                    // int yOffset = yLabelOuter - motionDiameter;
                    // int xOffset = xLabelInner - motionDiameter;
                    
                    float cost = dataCost();
                    cost += smoothnessCost();
                    
                    for (int directionCase = 0; directionCase < NUM_DIRECTIONS; directionCase++) {
                        if (directionCase != direction) {
                            int messageIndex = nodeIndex + (directionCase * NUM_DIRECTIONS * numMessagesPerDirection) + (yLabelInner * motionDiameter) + xLabelInner;
                            cost += MRF[messageIndex];
                        }
                    }
                    
                    minCost = min(cost, minCost);
                }
            }
            
            // Pass message
            int sourceDirection = (direction + 2) % 4;
            int messageComponentIndex = recipientPixelIndex + (sourceDirection * NUM_DIRECTIONS * numMessagesPerDirection) + (yLabelOuter * motionDiameter) + xLabelOuter;
            newMRF[messageComponentIndex] = minCost;
        }
    }
}
