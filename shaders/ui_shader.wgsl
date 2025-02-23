@group(0) @binding(0) var<uniform> screen_resolution: vec2u;  // Pixel space
@group(0) @binding(1) var sample: sampler;                    // 
@group(0) @binding(2) var tex: texture_2d<f32>;               // 
@group(0) @binding(3) var<uniform> texture_dimensions: vec2f; // 

struct Vertex_Input {
    @location(0) vertex_pos: vec2f,    // [-1, 1]
    @location(1) pos: vec2f,           // Pixel space
    @location(2) size: vec2f,          // Pixel space
    @location(3) color: vec4f,         // 
    @location(4) corner_radius: vec4f, // Top-left, top-right, bottom-left, bottom-right (pixels)
    @location(5) font_selection: u32,  // 0 = rectangle, i - 1 = font texture index
    @location(6) font_offset: vec2f,   // [0, 1]
}

struct Vertex_Output {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
    @location(1) local_pos: vec2f,  // Local quad space [0, 1]
    @location(2) size: vec2f,
    @location(3) corner_radius: vec4f,
    @interpolate(flat) @location(4) font_selection: u32,
    @location(5) font_offset: vec2f,
}

@vertex
fn vs_main(in: Vertex_Input) -> Vertex_Output {
    let pixel_space_pos = in.pos + ((in.vertex_pos * 0.5 + 0.5) * in.size);
    let ndc_pos = (pixel_space_pos / vec2f(screen_resolution)) * 2.0 - vec2f(1.0, 1.0);

    var out: Vertex_Output;
    out.position = vec4f(ndc_pos.x, -ndc_pos.y, 0.0, 1.0);
    out.color = in.color;

    out.local_pos = in.vertex_pos * 0.5 + 0.5; // Convert [-1, 1] to [0, 1]
    out.size = in.size;
    out.corner_radius = in.corner_radius;
    out.font_selection = in.font_selection;
    out.font_offset = in.font_offset;

    return out;
}

@fragment
fn fs_main(in: Vertex_Output) -> @location(0) vec4f {
    // Font rendering
    // -------------------------------------------------------------------------
    let tex_uv = in.font_offset + in.local_pos * (in.size / texture_dimensions);
    let tex_color = textureSample(tex, sample, tex_uv);

    // TODO: Implement multiple fonts and a texture array using in.font_selection
    // TODO: MSDF Fonts
    if in.font_selection > u32(0) {
        return tex_color.xxxw * in.color;
    }

    // (Rounded) Rectangle rendering
    // -------------------------------------------------------------------------
    // Compute the local fragment position in quad space
    let frag_pos = in.local_pos * in.size;

    // Corner center positions
    let top_left = vec2f(in.corner_radius.x, in.corner_radius.x);
    let top_right = vec2f(in.size.x - in.corner_radius.y, in.corner_radius.y);
    let bottom_left = vec2f(in.corner_radius.z, in.size.y - in.corner_radius.z);
    let bottom_right = vec2f(in.size.x - in.corner_radius.w, in.size.y - in.corner_radius.w);

    // Distance to nearest corner circle
    let corner_distances = vec4f(
        length(frag_pos - top_left),
        length(frag_pos - top_right),
        length(frag_pos - bottom_left),
        length(frag_pos - bottom_right)
    );

    // Determine if fragment lies outside rounded corners
    let within_radius = vec4<bool>(
        (frag_pos.x < in.corner_radius.x) && (frag_pos.y < in.corner_radius.x), // Top-left
        (frag_pos.x > (in.size.x - in.corner_radius.y)) && (frag_pos.y < in.corner_radius.y), // Top-right
        (frag_pos.x < in.corner_radius.z) && (frag_pos.y > (in.size.y - in.corner_radius.z)), // Bottom-left
        (frag_pos.x > (in.size.x - in.corner_radius.w)) && (frag_pos.y > (in.size.y - in.corner_radius.w)) // Bottom-right
    );

    // Discard fragments that lie outside the corner radius
    if any(within_radius) && ((within_radius.x && corner_distances.x > in.corner_radius.x) || // Top-left
        (within_radius.y && corner_distances.y > in.corner_radius.y) || // Top-right
        (within_radius.z && corner_distances.z > in.corner_radius.z) || // Bottom-left
        (within_radius.w && corner_distances.w > in.corner_radius.w)) { // Bottom-right
        discard;
    }

    return in.color;
}
