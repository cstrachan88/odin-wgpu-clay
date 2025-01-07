@group(0) @binding(0) var<uniform> screen_resolution: vec2u; // pixel space

struct Vertex_Input {
    @location(0) vertex_pos: vec2f, // [-1, 1]
    @location(1) pos: vec2f, // pixel space
    @location(2) size: vec2f, // pixel space
    @location(3) color: vec4f,
}

struct Vertex_Output {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
}

@vertex
fn vs_main(in: Vertex_Input) -> Vertex_Output {
    let pixel_space_pos = in.pos + ((in.vertex_pos * 0.5 + 0.5) * in.size);
    let ndc_pos = (pixel_space_pos / vec2f(screen_resolution)) * 2.0 - vec2f(1.0, 1.0);

    var out: Vertex_Output;
    out.position = vec4f(ndc_pos.x, -ndc_pos.y, 0.0, 1.0);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: Vertex_Output) -> @location(0) vec4f {
    return in.color;
}
