package wgpu_app

import intr "base:intrinsics"
import "core:fmt"
import "core:math/linalg"
import "vendor:wgpu"

Renderer :: struct {
  instance:          wgpu.Instance,
  surface:           wgpu.Surface,
  adapter:           wgpu.Adapter,
  device:            wgpu.Device,
  config:            wgpu.SurfaceConfiguration,
  queue:             wgpu.Queue,
  //
  resolution_buffer: wgpu.Buffer,
  //
  // ui_module:         wgpu.ShaderModule,
  ui_pipeline:       wgpu.RenderPipeline,
  ui_bind_group:     wgpu.BindGroup,
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
      vertex = wgpu.VertexState{module = ui_module, entryPoint = "vs_main"},
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

  ui_render_pass := wgpu.CommandEncoderBeginRenderPass(
    curr_encoder,
    &{
      colorAttachmentCount = 1,
      colorAttachments = raw_data(
        []wgpu.RenderPassColorAttachment {
          {
            view = curr_view,
            loadOp = .Clear,
            storeOp = .Store,
            clearValue = {f64(state.bg.r) / 255, f64(state.bg.g) / 255, f64(state.bg.b) / 255, f64(state.bg.a) / 255},
            depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
          },
        },
      ),
    },
  )
  wgpu.RenderPassEncoderSetPipeline(ui_render_pass, r.ui_pipeline)
  wgpu.RenderPassEncoderSetBindGroup(ui_render_pass, 0, r.ui_bind_group)
  wgpu.RenderPassEncoderDraw(ui_render_pass, 6, 1, 0, 0)
  wgpu.RenderPassEncoderEnd(ui_render_pass)
  wgpu.RenderPassEncoderRelease(ui_render_pass)

  command_buffer := wgpu.CommandEncoderFinish(curr_encoder, nil)
  wgpu.QueueSubmit(r.queue, {command_buffer})

  wgpu.CommandBufferRelease(command_buffer)
  wgpu.CommandEncoderRelease(curr_encoder)

  wgpu.SurfacePresent(r.surface)

  wgpu.TextureViewRelease(curr_view)
  wgpu.TextureRelease(curr_texture.texture)
}
