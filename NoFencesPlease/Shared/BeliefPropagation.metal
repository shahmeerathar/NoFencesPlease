//
//  BeliefPropagation.metal
//  NoFencesPlease
//
//  Created by Shahmeer Athar on 2021-12-19.
//

#include <metal_stdlib>
using namespace metal;

kernel void beliefPropagation(texture2d<float, access::read> image [[texture(0)]],
                              texture2d<float, access::read> refImage [[texture(1)]],
                              texture2d<float, access::write> output [[texture(2)]],
                              constant float& blue [[buffer(3)]],
                              uint2 index [[thread_position_in_grid]])
{
    float4 color = float4((float) index[0] / (float) output.get_width(), (float) index[1] / (float) output.get_height(), blue, 1.0);
    output.write(color, index);
}
