@group(0) @binding(0) var<uniform> screen_resolution: vec2u;

struct Vertex_Input {
    @builtin(vertex_index) vert_index: u32
}

struct Vertex_Output {
    @builtin(position) position: vec4f,
    @location(0) tex_coord: vec2f,
}

@vertex
fn vs_main(in: Vertex_Input) -> Vertex_Output {
    var positions = array<vec2f, 6>(
        vec2f(1.0, 1.0),
        vec2f(1.0, -1.0),
        vec2f(-1.0, -1.0),
        vec2f(1.0, 1.0),
        vec2f(-1.0, -1.0),
        vec2f(-1.0, 1.0),
    );
    
    var tex_coords = array<vec2f, 6>(
        vec2f(1.0, 0.0),
        vec2f(1.0, 1.0),
        vec2f(0.0, 1.0),
        vec2f(1.0, 0.0),
        vec2f(0.0, 1.0),
        vec2f(0.0, 0.0),
    );

    var out: Vertex_Output;
    out.position = vec4f(positions[in.vert_index] * 0.5, 0.0, 1.0);
    out.tex_coord = tex_coords[in.vert_index];
    return out;
}

@fragment
fn fs_main(in: Vertex_Output) -> @location(0) vec4f {
    return vec4f(in.tex_coord, 0.0, 1.0);
}
