package wgpu_app

import "core:fmt"
import "core:image/png"
import clay "shared:clay/bindings/odin/clay-odin"
import "vendor:wgpu"

COLOR_WHITE :: clay.Color{255, 255, 255, 255}

// TODO: Use storage buffer probably
MAX_UI_RECTS :: 10000

Ui_Rect :: struct #align (16) {
  pos:            [2]f32,
  size:           [2]f32,
  color:          [4]f32,
  corner_radius:  [4]f32,
  font_selection: u32,
  font_offset:    [2]f32,
}

Document :: struct {
  title:    string,
  contents: string,
}

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
  //
  font_sampler:       wgpu.Sampler,
  font_texture:       wgpu.Texture,
  font_texture_view:  wgpu.TextureView,
  //
  texture_dim_buffer: wgpu.Buffer,
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

  // Setup font texture size buffer
  // FIXME - make sure I can fit any / all fonts in APP_FONTS
  app_font := APP_FONTS[DEFAULT_FONT_ID]
  font_dim := [2]f32{f32(app_font.font.scale_w), f32(app_font.font.scale_h)}

  r.texture_dim_buffer = wgpu.DeviceCreateBufferWithDataSlice(
    r.device,
    &wgpu.BufferWithDataDescriptor{label = "Font Texture Dimensions Buffer", usage = {.Uniform}},
    font_dim[:],
  )

  // Setup ui font
  font_img, _ := png.load_from_bytes(app_font.img, {.alpha_add_if_missing}, context.temp_allocator)

  r.font_texture = wgpu.DeviceCreateTexture(
    r.device,
    &wgpu.TextureDescriptor {
      // usage = {.TextureBinding, .CopyDst, .Sampled},
      usage         = {.TextureBinding, .CopyDst},
      // usage         = {.TextureBinding},
      dimension     = ._2D,
      size          = {u32(font_img.width), u32(font_img.height), 1},
      format        = .RGBA8Unorm,
      mipLevelCount = 1,
      sampleCount   = 1,
    },
  )
  r.font_texture_view = wgpu.TextureCreateView(r.font_texture, nil)

  r.font_sampler = wgpu.DeviceCreateSampler(
    r.device,
    &wgpu.SamplerDescriptor {
      addressModeU = .ClampToEdge,
      addressModeV = .ClampToEdge,
      addressModeW = .ClampToEdge,
      magFilter = .Nearest,
      minFilter = .Nearest,
      mipmapFilter = .Nearest,
      lodMinClamp = 0,
      lodMaxClamp = 32,
      compare = .Undefined,
      maxAnisotropy = 1,
    },
  )

  // bytesPerRow in TextureDataLayout must be aligned to 256 bytes for WebGPU. If font_img.channels * font_img.width is not a multiple of 256, this can cause issues.
  // bytes_per_row := u32((font_img.channels * font_img.width + 255) &~ 255)
  bytes_per_row := u32(font_img.channels * font_img.width)

  wgpu.QueueWriteTexture(
    r.queue,
    &wgpu.ImageCopyTexture{texture = r.font_texture},
    raw_data(font_img.pixels.buf),
    uint(font_img.channels * font_img.width * font_img.height),
    &wgpu.TextureDataLayout{bytesPerRow = bytes_per_row, rowsPerImage = u32(font_img.height)},
    &wgpu.Extent3D{u32(font_img.width), u32(font_img.height), 1},
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
      entryCount = 4,
      entries = raw_data(
        []wgpu.BindGroupLayoutEntry {
          {
            binding = 0,
            visibility = {.Vertex},
            buffer = wgpu.BufferBindingLayout{type = .Uniform, hasDynamicOffset = false, minBindingSize = 8},
          },
          {binding = 1, visibility = {.Fragment}, sampler = {type = .Filtering}},
          {
            binding = 2,
            visibility = {.Fragment},
            texture = {sampleType = .Float, viewDimension = ._2D, multisampled = false},
          },
          {
            binding = 3,
            visibility = {.Fragment},
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
      entryCount = 4,
      entries = raw_data(
        []wgpu.BindGroupEntry {
          {binding = 0, offset = 0, size = 8, buffer = r.resolution_buffer},
          {binding = 1, sampler = r.font_sampler},
          {binding = 2, textureView = r.font_texture_view},
          {binding = 3, offset = 0, size = 8, buffer = r.texture_dim_buffer},
        },
      ),
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
              attributeCount = 6,
              attributes = raw_data(
                []wgpu.VertexAttribute {
                  {shaderLocation = 1, offset = u64(offset_of(Ui_Rect, pos)), format = .Float32x2},
                  {shaderLocation = 2, offset = u64(offset_of(Ui_Rect, size)), format = .Float32x2},
                  {shaderLocation = 3, offset = u64(offset_of(Ui_Rect, color)), format = .Float32x4},
                  {shaderLocation = 4, offset = u64(offset_of(Ui_Rect, corner_radius)), format = .Float32x4},
                  {shaderLocation = 5, offset = u64(offset_of(Ui_Rect, font_selection)), format = .Uint32},
                  {shaderLocation = 6, offset = u64(offset_of(Ui_Rect, font_offset)), format = .Float32x2},
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

  // Render ui
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
            clearValue = {0, 0, 0, 1},
            depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
          },
        },
      ),
    },
  )
  num_ui_rects := clay_render(&render_commands, ui_render_pass)
  if num_ui_rects > 0 {
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
  }
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

clay_create :: proc() -> clay.ClayArray(clay.RenderCommand) {
  layout_expand := clay.Sizing {
    width  = clay.SizingGrow({}),
    height = clay.SizingGrow({}),
  }

  content_background_config := clay.RectangleElementConfig {
    color        = {90, 90, 90, 255},
    cornerRadius = {8, 8, 8, 8},
  }

  clay.BeginLayout()

  if clay.UI(
    clay.ID("OuterContainer"),
    clay.Rectangle({color = {43, 41, 51, 255}}),
    clay.Layout({layoutDirection = .TOP_TO_BOTTOM, sizing = layout_expand, padding = {16, 16}, childGap = 16}),
  ) {
    if clay.UI(
      clay.ID("HeaderBar"),
      clay.Rectangle(content_background_config),
      clay.Layout(
        {
          sizing = {clay.SizingGrow({}), clay.SizingFixed(60)},
          padding = {x = 16},
          childGap = 16,
          childAlignment = {y = .CENTER},
        },
      ),
    ) {
      render_header_button("File")
      render_header_button("Edit")
      if clay.UI(clay.Layout({sizing = {width = clay.SizingGrow({})}})) {}
      render_header_button("Upload")
      render_header_button("Media")
      render_header_button("Support")
    }
    if clay.UI(clay.ID("LowerContent"), clay.Layout({sizing = layout_expand, childGap = 16})) {
      if clay.UI(
        clay.ID("Sidebar"),
        clay.Rectangle(content_background_config),
        clay.Layout(
          {
            layoutDirection = .TOP_TO_BOTTOM,
            padding = {16, 16},
            childGap = 8,
            sizing = {clay.SizingFixed(250), clay.SizingGrow({})},
          },
        ),
      ) {
        for d in documents {
          if clay.UI(
            clay.Layout({padding = {}}),
          ) {clay.Text(d.title, clay.TextConfig({fontId = DEFAULT_FONT_ID, fontSize = 16, textColor = COLOR_WHITE}))}
        }
      }
      if clay.UI(
        clay.ID("MainContent"),
        clay.Rectangle(content_background_config),
        clay.Scroll({vertical = true}),
        clay.Layout({layoutDirection = .TOP_TO_BOTTOM, childGap = 16, padding = {16, 16}, sizing = layout_expand}),
      ) {
        selected_document := documents[selected_document_idx]
        clay.Text(
          selected_document.title,
          clay.TextConfig({fontId = DEFAULT_FONT_ID, fontSize = 24, textColor = COLOR_WHITE}),
        )
        clay.Text(
          selected_document.contents,
          clay.TextConfig({fontId = DEFAULT_FONT_ID, fontSize = 24, textColor = COLOR_WHITE}),
        )
      }
    }
  }

  return clay.EndLayout()
}

render_header_button :: proc(text: string) {
  if clay.UI(
    clay.Layout({padding = {16, 8}}),
    clay.Rectangle({color = {140, 140, 140, 255}, cornerRadius = {5, 5, 5, 5}}),
  ) {
    clay.Text(text, clay.TextConfig({fontId = DEFAULT_FONT_ID, fontSize = 16, textColor = COLOR_WHITE}))
  }
}

clay_render :: proc(render_commands: ^clay.ClayArray(clay.RenderCommand), render_pass: wgpu.RenderPassEncoder) -> u32 {
  r := &state.renderer

  rects := make([dynamic]Ui_Rect, context.temp_allocator)

  for i in 0 ..< render_commands.length {
    render_command := clay.RenderCommandArray_Get(render_commands, i)
    bounding_box := render_command.boundingBox

    switch render_command.commandType {
      case clay.RenderCommandType.None:
      case clay.RenderCommandType.Text:
        // TODO: use storage buffer?

        // TODO: incorporate config
        config := render_command.config.textElementConfig

        pos := [2]f32{bounding_box.x, bounding_box.y}

        app_font := APP_FONTS[config.fontId]

        for j in 0 ..< render_command.text.length {
          if render_command.text.chars[j] == 0 do break

          character, ok := app_font.font.characters[render_command.text.chars[j]]
          if !ok do character = app_font.error_char

          size := [2]f32{f32(character.width), f32(character.height)}
          offset := [2]f32{f32(character.x), f32(character.y)}
          scale := [2]f32{f32(app_font.font.scale_w), f32(app_font.font.scale_h)}

          append(
            &rects,
            Ui_Rect {
              pos = pos,
              color = config.textColor / 255.0,
              size = size,
              font_selection = u32(config.fontId + 1),
              font_offset = offset / scale,
            },
          )

          pos += {size.x, 0}
        }

      case clay.RenderCommandType.Image: // TODO
      case clay.RenderCommandType.ScissorStart:
        // NOTE https://stackoverflow.com/questions/73769626/setting-scissor-rectangle-before-clearing
        // https://www.gamedev.net/forums/topic/660120-gui-scissor/5175171/

        // FIXME
        // fmt.println("In scissor start")
        // fmt.println("In scissor start -", render_command^)
        // fmt.println(render_command.config.borderElementConfig)
        // fmt.println(render_command.config.customElementConfig)
        // fmt.println(render_command.config.imageElementConfig)
        // fmt.println(render_command.config.rectangleElementConfig)
        // fmt.println(render_command.config.textElementConfig)
        // NOTE: If this scissor is from the contents of the scroll container, should the padding be taken into account??

        // wgpu.RenderPassEncoderSetScissorRect(
        //   render_pass,
        //   u32(bounding_box.x),
        //   u32(bounding_box.y),
        //   u32(bounding_box.width),
        //   u32(bounding_box.height),
        // )
        // wgpu.RenderPassEncoderSetScissorRect(
        //   render_pass,
        //   u32(bounding_box.x + 16),
        //   u32(bounding_box.y + 16),
        //   u32(bounding_box.width - 32),
        //   u32(bounding_box.height - 32),
        // )
        {}

      case clay.RenderCommandType.ScissorEnd:
        // FIXME
        // fmt.println("In scissor end")
        // wgpu.RenderPassEncoderSetScissorRect(render_pass, 0, 0, r.config.width, r.config.height)
        {}

      case clay.RenderCommandType.Rectangle:
        config := render_command.config.rectangleElementConfig
        // fmt.println(render_command)
        // fmt.printfln("%p", render_command.config.rectangleElementConfig)
        // fmt.println(render_command.config.rectangleElementConfig) // BUG: "Uncaught RuntimeError: memory access out of bounds" in js_wasm32 build

        append(
          &rects,
          Ui_Rect {
            pos = {bounding_box.x, bounding_box.y},
            size = {bounding_box.width, bounding_box.height},
            color = config.color / 255.0,
            corner_radius = {
              config.cornerRadius.topLeft,
              config.cornerRadius.topRight,
              config.cornerRadius.bottomLeft,
              config.cornerRadius.bottomRight,
            },
          },
        )

      case clay.RenderCommandType.Border: // TODO
      case clay.RenderCommandType.Custom:
    }
  }

  wgpu.QueueWriteBuffer(r.queue, r.ui_instance_buffer, 0, raw_data(rects), len(rects) * size_of(Ui_Rect))

  return u32(len(rects))
}

selected_document_idx: u32 = 0
documents := [?]Document {
  {
    "Lorem 1",
    `Lorem magna adipisicing fugiat enim aliqua elit laboris ullamco. Cupidatat veniam adipisicing fugiat cupidatat. Cillum labore incididunt dolore et esse. Deserunt esse nostrud et Lorem proident ipsum aliqua aliqua anim. Sunt culpa exercitation cupidatat amet aliqua.

Minim consectetur mollit in incididunt dolore qui sit. Velit eiusmod qui cillum ut. Deserunt enim qui aliquip voluptate magna laborum elit tempor proident officia consequat. Lorem cupidatat occaecat adipisicing elit ullamco ut labore irure velit quis non consectetur cupidatat. Fugiat ut pariatur cillum non culpa elit ea dolore veniam. Excepteur elit irure cillum nostrud mollit minim enim aliquip nisi adipisicing.

Voluptate occaecat et cillum anim quis laborum exercitation aliqua. Dolore do incididunt sit non. Pariatur tempor dolor tempor labore dolor culpa mollit. Ex officia enim aliqua irure et culpa fugiat do. Nulla nulla est cillum magna Lorem sint sunt laborum culpa eu esse. Qui in excepteur eiusmod exercitation fugiat ea enim aliquip ullamco ad ex nisi in elit. Mollit et ullamco aliqua et ullamco sint aliquip cillum exercitation ipsum minim.

Occaecat dolore aliquip nostrud anim magna eu laborum cillum excepteur aliquip enim officia quis consequat. Exercitation culpa laboris excepteur incididunt aliquip ea nostrud ex quis dolor ex mollit nostrud. Lorem do anim tempor dolore fugiat aute reprehenderit adipisicing incididunt ad reprehenderit reprehenderit mollit aute. Quis fugiat sunt deserunt reprehenderit cupidatat nulla amet consequat ut tempor. Elit est laboris ea ea elit elit anim voluptate eiusmod cupidatat cupidatat incididunt ex eiusmod.

Nisi dolore ullamco amet proident magna eu do sunt esse sunt irure. Proident elit laborum labore eiusmod tempor non. Irure eiusmod velit Lorem quis nisi fugiat culpa mollit. Sunt pariatur sunt dolor veniam magna anim est elit tempor cillum ad in commodo.

Nisi mollit ad minim eu sunt tempor nostrud ipsum esse irure culpa excepteur. Cupidatat excepteur non anim labore irure excepteur dolore esse. Incididunt enim aliqua adipisicing excepteur in aliquip id ipsum. Eiusmod laboris est amet laborum dolor do. Minim ullamco nulla cupidatat aute dolore aute fugiat labore consectetur.

Labore consequat id sunt exercitation culpa ex irure ad proident ad excepteur Lorem eu irure. Tempor occaecat cillum eiusmod tempor. Qui velit sunt adipisicing dolore velit officia voluptate. Voluptate officia dolore anim dolor enim sint exercitation sunt adipisicing consectetur aute enim voluptate irure. Occaecat minim qui in proident minim reprehenderit.

Veniam ex cupidatat consectetur incididunt Lorem do sint mollit qui deserunt aliqua aute culpa id. Sit sint proident laboris tempor occaecat non culpa esse ad duis minim velit Lorem nulla. Veniam et sint voluptate ut veniam do aliquip deserunt.

Magna magna adipisicing ullamco anim incididunt sit culpa. Nulla dolor ex aute laborum veniam consequat pariatur aliquip nulla consequat. Dolor anim sit cillum consectetur dolore aute. Culpa do ullamco laborum consectetur exercitation ut consectetur adipisicing amet magna aliquip labore incididunt aute. Officia sint ipsum irure enim laborum. Quis voluptate velit laboris ipsum Lorem exercitation cillum aliquip. Et dolor deserunt officia mollit tempor voluptate exercitation minim labore.

Reprehenderit et fugiat quis officia qui. Velit ut culpa dolor quis veniam duis culpa consequat ea enim dolor sunt quis nisi. Sunt qui aute deserunt mollit incididunt dolore amet commodo do sint mollit labore. Irure culpa eiusmod eiusmod occaecat in ullamco.

Excepteur officia et cillum sunt dolore laboris elit sint. Dolor est dolore ipsum dolor. Consequat cillum ea tempor magna nulla. Deserunt dolor consequat reprehenderit do deserunt nulla. Et Lorem cillum aliquip id.

Est irure consectetur consectetur elit ipsum Lorem. Quis non culpa deserunt tempor consectetur adipisicing consequat adipisicing nulla dolore ipsum. Enim qui sit commodo nisi veniam incididunt nostrud pariatur.

Minim exercitation cupidatat occaecat eiusmod id est ea proident occaecat. Fugiat esse deserunt eiusmod Lorem fugiat tempor. Occaecat laborum adipisicing fugiat nulla quis officia proident reprehenderit irure. Elit consequat eu dolor mollit elit irure. Eiusmod aliquip qui nulla cillum velit deserunt labore velit. Qui minim nostrud quis nisi fugiat laborum est ex.

Culpa voluptate amet esse esse. Occaecat eiusmod anim excepteur et consectetur et culpa elit quis dolor tempor pariatur sint. Labore sunt est Lorem irure in deserunt labore elit veniam pariatur. Pariatur ipsum proident commodo quis laboris magna.

Veniam mollit est dolore excepteur fugiat tempor labore consectetur officia. Minim pariatur dolore voluptate veniam tempor laboris. Elit minim commodo dolore occaecat.

Reprehenderit culpa exercitation dolor qui do dolore qui commodo aliquip anim voluptate veniam. Sint sint aliquip officia aliqua. Sit exercitation adipisicing aliqua nisi ullamco occaecat culpa exercitation et irure incididunt veniam magna labore. Dolor id consectetur eu irure esse incididunt deserunt. Id nostrud et aliqua do aliquip consequat fugiat ipsum non. Elit non ullamco consectetur voluptate sit mollit tempor enim enim sit ipsum.

Elit cillum id ullamco mollit do culpa culpa nulla nulla dolore exercitation qui qui. Et consectetur nisi dolore do ut laboris. Nulla non aliquip aliquip ea mollit elit deserunt excepteur officia. Incididunt proident laboris sunt culpa do nostrud consectetur nulla ex ullamco duis ipsum velit. Quis occaecat mollit aliquip fugiat ea sint quis qui nulla consectetur quis pariatur. Mollit adipisicing et laborum veniam nisi consectetur deserunt consequat ullamco sit excepteur voluptate commodo. Nisi excepteur enim et eu exercitation sit est magna est minim ipsum amet officia.

Dolor nisi commodo incididunt laborum occaecat exercitation magna. Pariatur excepteur mollit ut Lorem incididunt consequat aute. Fugiat sunt exercitation enim Lorem mollit dolore. Excepteur minim sunt sunt adipisicing occaecat elit incididunt magna. Eiusmod ipsum ullamco laborum quis ut cupidatat occaecat pariatur deserunt sunt veniam labore excepteur consectetur. Do do Lorem esse voluptate cupidatat sint nostrud anim Lorem sint. Tempor elit culpa cillum qui labore et id fugiat et.

Ad sit aliqua aliqua veniam anim sint irure fugiat consectetur nulla duis irure. Eiusmod sint deserunt aute reprehenderit. Anim Lorem irure cupidatat esse pariatur fugiat. Laborum culpa exercitation dolore qui laboris culpa eiusmod exercitation velit est sint laboris. Anim laborum veniam proident aute aute minim ea eiusmod laborum pariatur excepteur eiusmod eu.

Pariatur deserunt ea exercitation dolore ea. Culpa enim fugiat consectetur officia pariatur fugiat Lorem Lorem amet ut cupidatat officia. Qui elit veniam sunt dolore cupidatat irure excepteur. Aute nulla voluptate ullamco Lorem elit esse esse reprehenderit aliquip. Aute in dolor et amet cupidatat ad dolore voluptate velit. Nostrud irure qui incididunt adipisicing aliquip tempor quis ipsum culpa labore amet amet non. Ea proident aliquip mollit quis ut mollit deserunt.

Sunt ut ex aute velit ipsum fugiat eu quis incididunt pariatur mollit nisi elit. Reprehenderit non esse tempor sunt est officia quis pariatur occaecat consectetur. Eiusmod sint ullamco sunt enim in ea ea nostrud commodo laborum aliquip enim id.

Laboris magna excepteur commodo reprehenderit nostrud. Nisi laborum ipsum Lorem consectetur quis minim mollit amet anim anim occaecat magna. Deserunt qui veniam ea occaecat cillum.

Laborum aute proident do aliqua nulla minim. Culpa Lorem consequat qui in occaecat nostrud mollit qui officia. Sint consequat amet proident aute minim cupidatat elit ea. Voluptate reprehenderit pariatur enim adipisicing dolore. Exercitation quis sint exercitation deserunt et non nisi qui. Laboris est sunt consequat duis cupidatat do ad. Anim ex dolore occaecat eiusmod irure Lorem aliquip cupidatat.

Sunt pariatur aliqua quis culpa nisi irure et ut minim non cupidatat officia tempor. Ullamco culpa eu ut do. Minim est enim in in aliqua Lorem et eiusmod aute. Cupidatat enim excepteur commodo velit adipisicing id ea. Laborum culpa anim anim labore incididunt anim do adipisicing. Nulla ullamco pariatur pariatur magna. Consectetur veniam officia occaecat incididunt adipisicing officia cupidatat id nisi ullamco.

Proident consequat sunt id cupidatat. Sint fugiat et excepteur et elit consequat ea officia consequat velit amet. Eiusmod laboris minim minim magna reprehenderit Lorem esse nisi dolor mollit nostrud. Deserunt cupidatat cillum cillum ea sint.

Consequat culpa reprehenderit veniam sint ad minim. Sit ipsum tempor reprehenderit enim ex. Mollit adipisicing ad quis nisi duis.

Lorem ipsum velit ullamco nostrud aute ea ipsum amet ex adipisicing laborum nulla ut elit. Reprehenderit occaecat mollit fugiat exercitation ullamco esse aute. Minim cupidatat cillum cupidatat ad mollit do consectetur commodo duis. Aliquip reprehenderit ipsum cillum ipsum id aliqua veniam occaecat. Proident nulla nisi cillum aliquip fugiat do et nisi duis deserunt pariatur do enim do.

Nulla adipisicing consequat sunt cupidatat adipisicing. Laboris laborum labore eiusmod culpa est Lorem reprehenderit. Aliqua culpa officia fugiat laborum qui labore Lorem.

Amet quis cupidatat ullamco magna ex consectetur laborum ex veniam laborum non consectetur cillum. Non amet elit duis cillum ipsum id elit. Qui commodo id id labore ex laborum ex officia est. Laboris sit nostrud do commodo cillum qui qui anim excepteur aliqua aliquip.

Laboris esse excepteur dolore in eu elit commodo. Minim quis eu reprehenderit qui exercitation est minim ipsum ut cillum sit sit. Minim amet proident nisi ad officia consectetur. Dolor consequat aliquip veniam minim incididunt minim magna.`,
  },
  {
    "Lorem 2",
    "Fugiat reprehenderit officia eiusmod duis sint laborum exercitation mollit nisi laboris ex ut. Id amet ullamco commodo esse pariatur aute aliqua Lorem commodo consectetur exercitation qui dolore occaecat. Labore irure ex ipsum sunt tempor ut est ipsum voluptate Lorem labore voluptate. Culpa ut tempor ullamco aliqua aliquip tempor ut culpa qui aliqua ex id quis. Dolor cupidatat duis amet ullamco nulla aute deserunt exercitation sunt. Aute sunt mollit ullamco adipisicing. Ad fugiat est ipsum consequat qui dolor aliquip non deserunt.",
  },
  {
    "Lorem 3",
    "Aute eu nisi exercitation cupidatat enim id commodo enim pariatur sunt enim. Ut do sunt consectetur sit anim id dolor. Eu aliquip qui deserunt labore cupidatat mollit. Id non nostrud dolor magna. Veniam adipisicing velit aliquip voluptate amet dolore labore veniam non nostrud.",
  },
  {
    "Lorem 4",
    "Sit tempor veniam anim non sint laboris esse esse culpa enim est laborum. Incididunt in qui commodo ex dolor pariatur. Cillum nostrud veniam est Lorem excepteur.",
  },
  {
    "Lorem 5",
    "Tempor incididunt dolor incididunt laborum occaecat. Ut nisi id adipisicing officia adipisicing sit dolor enim eu. Ex aliquip dolore pariatur cillum ullamco consectetur. Ipsum culpa in Lorem sunt minim laboris occaecat.",
  },
}
