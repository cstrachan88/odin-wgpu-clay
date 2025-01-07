package wgpu_app

import "core:fmt"
import clay "shared:clay/bindings/odin/clay-odin"
import "vendor:wgpu"

MAX_UI_RECTS :: 100

Renderer :: struct {
  instance:           wgpu.Instance,
  surface:            wgpu.Surface,
  adapter:            wgpu.Adapter,
  device:             wgpu.Device,
  config:             wgpu.SurfaceConfiguration,
  queue:              wgpu.Queue,
  //
  resolution_buffer:  wgpu.Buffer,
  //
  ui_pipeline:        wgpu.RenderPipeline,
  ui_bind_group:      wgpu.BindGroup,
  ui_vertex_buffer:   wgpu.Buffer,
  ui_index_buffer:    wgpu.Buffer,
  ui_instance_buffer: wgpu.Buffer,
}

r_init_and_run :: proc() {
  r := &state.renderer

  r.instance = wgpu.CreateInstance(nil)
  r.surface = os_get_surface(r.instance)

  wgpu.InstanceRequestAdapter(r.instance, &{compatibleSurface = r.surface}, handle_request_adapter, nil)
}

@(private = "file")
handle_request_adapter :: proc "c" (
  status: wgpu.RequestAdapterStatus,
  adapter: wgpu.Adapter,
  message: cstring,
  userdata: rawptr,
) {
  context = state.ctx
  if status != .Success || adapter == nil {
    fmt.panicf("request adapter failure: [%v] %s", status, message)
  }
  state.renderer.adapter = adapter
  wgpu.AdapterRequestDevice(adapter, nil, handle_request_device, nil)
}

@(private = "file")
handle_request_device :: proc "c" (
  status: wgpu.RequestDeviceStatus,
  device: wgpu.Device,
  message: cstring,
  userdata: rawptr,
) {
  context = state.ctx
  if status != .Success || device == nil {
    fmt.panicf("request device failure: [%v] %s", status, message)
  }
  state.renderer.device = device
  on_adapter_and_device()
}

@(private = "file")
on_adapter_and_device :: proc() {
  r := &state.renderer

  width, height := os_get_render_bounds()
  r.config = wgpu.SurfaceConfiguration {
    device      = r.device,
    usage       = {.RenderAttachment},
    format      = .BGRA8Unorm,
    width       = width,
    height      = height,
    presentMode = .Fifo,
    alphaMode   = .Opaque,
  }
  wgpu.SurfaceConfigure(r.surface, &r.config)
  r.queue = wgpu.DeviceGetQueue(r.device)

  // Set up screen resolution buffer
  r.resolution_buffer = wgpu.DeviceCreateBuffer(
    r.device,
    &wgpu.BufferDescriptor{label = "Screen Resolution Buffer", usage = {.Uniform, .CopyDst}, size = 8},
  )

  // Setup ui vertex buffers
  r.ui_vertex_buffer = wgpu.DeviceCreateBufferWithDataSlice(
    r.device,
    &{label = "UI Vertex Buffer", usage = {.Vertex}},
    []f32{1, 1, -1, 1, -1, -1, 1, -1},
  )
  r.ui_index_buffer = wgpu.DeviceCreateBufferWithDataSlice(
    r.device,
    &{label = "UI Index Buffer", usage = {.Index, .Vertex}},
    []u16{0, 1, 2, 0, 2, 3},
  )
  r.ui_instance_buffer = wgpu.DeviceCreateBuffer(
    r.device,
    &{label = "UI Instance buffer", usage = {.Vertex, .CopyDst}, size = MAX_UI_RECTS * size_of(Ui_Rect)},
  )

  // Set up ui pipeline
  ui_module := wgpu.DeviceCreateShaderModule(
    r.device,
    &wgpu.ShaderModuleDescriptor {
      label = "UI Shader",
      nextInChain = &wgpu.ShaderModuleWGSLDescriptor {
        sType = .ShaderModuleWGSLDescriptor,
        code = #load("../shaders/ui_shader.wgsl"),
      },
    },
  )

  ui_bind_group_layout := wgpu.DeviceCreateBindGroupLayout(
    r.device,
    &wgpu.BindGroupLayoutDescriptor {
      label = "UI Bind Group Layout",
      entryCount = 1,
      entries = raw_data(
        []wgpu.BindGroupLayoutEntry {
          {
            binding = 0,
            visibility = {.Vertex},
            buffer = wgpu.BufferBindingLayout{type = .Uniform, hasDynamicOffset = false, minBindingSize = 8},
          },
        },
      ),
    },
  )

  r.ui_bind_group = wgpu.DeviceCreateBindGroup(
    r.device,
    &wgpu.BindGroupDescriptor {
      label = "UI Bind Group",
      layout = ui_bind_group_layout,
      entryCount = 1,
      entries = raw_data([]wgpu.BindGroupEntry{{binding = 0, offset = 0, size = 8, buffer = r.resolution_buffer}}),
    },
  )

  ui_pipeline_layout := wgpu.DeviceCreatePipelineLayout(
    r.device,
    &wgpu.PipelineLayoutDescriptor {
      label = "UI Render Pipeline Layout",
      bindGroupLayoutCount = 1,
      bindGroupLayouts = &ui_bind_group_layout,
    },
  )

  r.ui_pipeline = wgpu.DeviceCreateRenderPipeline(
    r.device,
    &wgpu.RenderPipelineDescriptor {
      label = "UI Render Pipeline",
      layout = ui_pipeline_layout,
      vertex = wgpu.VertexState {
        module = ui_module,
        entryPoint = "vs_main",
        bufferCount = 2,
        buffers = raw_data(
          []wgpu.VertexBufferLayout {
            {
              arrayStride = 8,
              stepMode = .Vertex,
              attributeCount = 1,
              attributes = &wgpu.VertexAttribute{shaderLocation = 0, offset = 0, format = .Float32x2},
            },
            {
              arrayStride = size_of(Ui_Rect),
              stepMode = .Instance,
              attributeCount = 3,
              attributes = raw_data(
                []wgpu.VertexAttribute {
                  {shaderLocation = 1, offset = u64(offset_of(Ui_Rect, pos)), format = .Float32x2},
                  {shaderLocation = 2, offset = u64(offset_of(Ui_Rect, size)), format = .Float32x2},
                  {shaderLocation = 3, offset = u64(offset_of(Ui_Rect, color)), format = .Float32x4},
                },
              ),
            },
          },
        ),
      },
      fragment = &wgpu.FragmentState {
        module = ui_module,
        entryPoint = "fs_main",
        targetCount = 1,
        targets = &wgpu.ColorTargetState {
          format = .BGRA8Unorm,
          blend = &wgpu.BlendState {
            color = {srcFactor = .SrcAlpha, dstFactor = .OneMinusSrcAlpha, operation = .Add},
            alpha = {srcFactor = .Zero, dstFactor = .One, operation = .Add},
          },
          writeMask = wgpu.ColorWriteMaskFlags_All,
        },
      },
      multisample = {count = 1, mask = 0xFFFFFFFF},
      primitive = {topology = .TriangleList},
    },
  )

  r_write_consts()

  os_run()
}

r_resize :: proc() {
  r := &state.renderer

  width, height := os_get_render_bounds()
  r.config.width, r.config.height = width, height
  wgpu.SurfaceConfigure(r.surface, &r.config)

  clay.SetLayoutDimensions({f32(width), f32(height)})

  r_write_consts()
}

r_write_consts :: proc() {
  r := &state.renderer

  width, height := os_get_render_bounds()
  resolution := []u32{width, height}
  wgpu.QueueWriteBuffer(r.queue, r.resolution_buffer, 0, raw_data(resolution), 8)
}

r_render :: proc() {
  r := &state.renderer

  curr_texture := wgpu.SurfaceGetCurrentTexture(r.surface)
  switch curr_texture.status {
    case .Success: // NOTE: Could check for `curr_texture.suboptimal` here
    case .Timeout, .Outdated, .Lost:
      if curr_texture.texture != nil do wgpu.TextureRelease(curr_texture.texture)
      r_resize()
      return
    case .OutOfMemory, .DeviceLost:
      fmt.panicf("get_current_texture status=%v", curr_texture.status)
  }

  curr_view := wgpu.TextureCreateView(curr_texture.texture, nil)
  curr_encoder := wgpu.DeviceCreateCommandEncoder(r.device, nil)

  // Update and write ui
  render_commands := clay_create()
  num_ui_rects := clay_render(&render_commands)

  // Render ui
  if num_ui_rects > 0 {
    ui_render_pass := wgpu.CommandEncoderBeginRenderPass(
      curr_encoder,
      &{
        colorAttachmentCount = 1,
        colorAttachments     = raw_data(
          []wgpu.RenderPassColorAttachment {
            {
              view       = curr_view,
              loadOp     = .Clear,
              storeOp    = .Store,
              // clearValue = {f64(state.bg.r) / 255, f64(state.bg.g) / 255, f64(state.bg.b) / 255, f64(state.bg.a) / 255},
              depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
            },
          },
        ),
      },
    )
    wgpu.RenderPassEncoderSetPipeline(ui_render_pass, r.ui_pipeline)
    wgpu.RenderPassEncoderSetBindGroup(ui_render_pass, 0, r.ui_bind_group)
    wgpu.RenderPassEncoderSetIndexBuffer(ui_render_pass, r.ui_index_buffer, .Uint16, 0, 12)
    wgpu.RenderPassEncoderSetVertexBuffer(ui_render_pass, 0, r.ui_vertex_buffer, 0, 32)
    wgpu.RenderPassEncoderSetVertexBuffer(
      ui_render_pass,
      1,
      r.ui_instance_buffer,
      0,
      u64(num_ui_rects) * size_of(Ui_Rect),
    )
    wgpu.RenderPassEncoderDrawIndexed(ui_render_pass, 6, num_ui_rects, 0, 0, 0)
    wgpu.RenderPassEncoderEnd(ui_render_pass)
    wgpu.RenderPassEncoderRelease(ui_render_pass)
  }

  command_buffer := wgpu.CommandEncoderFinish(curr_encoder, nil)
  wgpu.QueueSubmit(r.queue, {command_buffer})

  wgpu.CommandBufferRelease(command_buffer)
  wgpu.CommandEncoderRelease(curr_encoder)

  wgpu.SurfacePresent(r.surface)

  wgpu.TextureViewRelease(curr_view)
  wgpu.TextureRelease(curr_texture.texture)
}

clay_create :: proc() -> clay.ClayArray(clay.RenderCommand) {
  clay.BeginLayout()

  if clay.UI(
    clay.Layout({layoutDirection = .TOP_TO_BOTTOM, sizing = {clay.SizingGrow({}), clay.SizingGrow({})}}),
    clay.Rectangle({color = {1, 0, 0, 1}}),
  ) {
  }

  return clay.EndLayout()
}

clay_render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand)) -> u32 {
  rects := make([dynamic]Ui_Rect, context.temp_allocator)

  for i in 0 ..< render_commands.length {
    render_command := clay.RenderCommandArray_Get(render_commands, i)
    bounding_box := render_command.boundingBox

    switch (render_command.commandType) {
      case clay.RenderCommandType.None:
      case clay.RenderCommandType.Text:
      case clay.RenderCommandType.Image:
      case clay.RenderCommandType.ScissorStart:
      case clay.RenderCommandType.ScissorEnd:
      case clay.RenderCommandType.Rectangle:
        // config := render_command.config.rectangleElementConfig
        fmt.println(render_command)
        fmt.printfln("%p", render_command.config.rectangleElementConfig)
        fmt.println(render_command.config.rectangleElementConfig) // BUG: "Uncaught RuntimeError: memory access out of bounds" in js_wasm32 build

        append(
          &rects,
          // Ui_Rect{{bounding_box.x, bounding_box.y}, {bounding_box.width, bounding_box.height}, config.color},
          Ui_Rect{{bounding_box.x, bounding_box.y}, {bounding_box.width, bounding_box.height}, {1, 0, 0, 1}},
        )
      case clay.RenderCommandType.Border:
      case clay.RenderCommandType.Custom:
    }
  }

  r := &state.renderer
  wgpu.QueueWriteBuffer(r.queue, r.ui_instance_buffer, 0, raw_data(rects), len(rects) * size_of(Ui_Rect))

  return u32(len(rects))
}

Ui_Rect :: struct #align (16) {
  pos:   [2]f32,
  size:  [2]f32,
  color: [4]f32,
}
