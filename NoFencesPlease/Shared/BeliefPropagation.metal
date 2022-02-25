//
//  BeliefPropagation.metal
//  NoFencesPlease
//
//  Created by Shahmeer Athar on 2021-12-19.
//

#include <metal_stdlib>
using namespace metal;

#define NUM_DIRECTIONS 4
#define PATCH_RADIUS 2
#define EPSILON 0.075

float dataCost(uint2 index,
               uint2 offsets,
               texture2d<float, access::read> image,
               texture2d<float, access::read> refImage) {
    float cost = 0.0;
    uint2 refImageIndex = uint2(index[0] + offsets[0], index[1] + offsets[1]);
    
    // Currently implemented as SSD; TODO: implement NCC
    for (int yOffset = -1 * PATCH_RADIUS; yOffset < PATCH_RADIUS + 1; yOffset++)
    {
        for (int xOffset = -1 * PATCH_RADIUS; xOffset < PATCH_RADIUS + 1; xOffset++)
        {
            uint2 refPixelIndex = uint2(refImageIndex[0] + xOffset, refImageIndex[1] + yOffset);
            uint2 imgPixelIndex = uint2(index[0] + xOffset, index[1] + yOffset);
            
            // TODO: Sampling is super slow!
            float diff = image.read(imgPixelIndex)[0] - refImage.read(refPixelIndex)[0];
            cost += diff * diff;
        }
    }
    
    return cost;
}

float smoothnessCost(uint2 source,
                     uint2 destination) {
    return 0.0;
}

kernel void beliefPropagationMessagePassingRound(texture2d<float, access::read> image [[texture(0)]],
                                                 texture2d<float, access::read> refImage [[texture(1)]],
                                                 texture2d<float, access::read> edgeMap [[texture(2)]],
                                                 constant int& imgHeight [[buffer(0)]],
                                                 constant int& imgWidth [[buffer(1)]],
                                                 constant int& motionDiameter [[buffer(2)]],
                                                 constant int& direction [[buffer(3)]],
                                                 constant int* directionOffset [[buffer(4)]],
                                                 constant float* MRF [[buffer(5)]],
                                                 device float* newMRF [[buffer(6)]],
                                                 constant int* edgeCoords [[buffer(7)]],
                                                 uint gid [[thread_position_in_grid]])
{
    uint2 index = uint2(edgeCoords[(gid * 2) + 1], edgeCoords[gid * 2]);
    
    int motionRadius = motionDiameter / 2;
    int numMessagesPerDirection = motionDiameter * motionDiameter;
    int numMessagesPerPixel = NUM_DIRECTIONS * numMessagesPerDirection;
    
    // index[0] is the x coordinate
    // index[1] is the y coordinate
    int pixelNum = (index[1] * imgWidth) + index[0];
    int nodeIndex = pixelNum * numMessagesPerPixel;
    
    // Calculate pixel indices for recipient messages
    int x = index[0] + directionOffset[0];
    int y = index[1] + directionOffset[1];
    uint2 destination = uint2(x, y);
    
    // Check if out of bounds
    if (y < 0 || y >= imgHeight || x < 0 || x >= imgWidth or edgeMap.read(destination)[0] == 0.0) {
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
                    int yOffset = yLabelInner - motionRadius;
                    int xOffset = xLabelInner - motionRadius;
                    uint2 offsets = uint2(xOffset, yOffset);
                    
                    if ((yOffset == 0 && xOffset == 0) || edgeMap.read(index + offsets)[0] == 0.0) {
                        // Same pixel or not an edge
                        continue;
                    }
                    
                    float cost = dataCost(index, offsets, image, refImage);
                    cost += smoothnessCost(index, destination);
                    
                    int messageNodeIndex = nodeIndex + (yLabelInner * motionDiameter * NUM_DIRECTIONS) + (xLabelInner * NUM_DIRECTIONS);
                    // TODO: These memory accesses are very inefficient... try converting textures into .R8 vs .RGBA8UNORM
                    float4 directionCosts = float4(0);
                    for (int offset = 0; offset < NUM_DIRECTIONS; offset++) {
                        directionCosts[offset] = MRF[messageNodeIndex + offset];
                    }
                    float4 multiplier = float4(1.0);
                    multiplier[direction] = 0.0;
                    cost += dot(directionCosts, multiplier);
                    
                    minCost = min(cost, minCost);
                }
            }
            
            // Pass message
            int sourceDirection = (direction + 2) % 4;
            // int messageComponentIndex = recipientPixelIndex + (sourceDirection * NUM_DIRECTIONS * numMessagesPerDirection) + (yLabelOuter * motionDiameter) + xLabelOuter;
            int messageComponentIndex = recipientPixelIndex + (yLabelOuter * motionDiameter * NUM_DIRECTIONS) + (xLabelOuter * NUM_DIRECTIONS) + sourceDirection;
            newMRF[messageComponentIndex] = minCost;
        }
    }
}
