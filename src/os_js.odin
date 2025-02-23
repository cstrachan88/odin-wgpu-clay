package wgpu_app

import "core:sys/wasm/js"
import "core:unicode"
import "core:unicode/utf8"
import "vendor:wgpu"

OS :: struct {
  initialized: bool,
  clipboard:   [dynamic]byte,
}

os_init :: proc() {
  state.os.clipboard.allocator = context.allocator
  // assert(js.add_window_event_listener(.Key_Down, nil, key_down_callback))
  // assert(js.add_window_event_listener(.Key_Up, nil, key_up_callback))
  assert(js.add_window_event_listener(.Mouse_Down, nil, mouse_down_callback))
  assert(js.add_window_event_listener(.Mouse_Up, nil, mouse_up_callback))
  assert(js.add_event_listener("wgpu-canvas", .Mouse_Move, nil, mouse_move_callback))
  assert(js.add_window_event_listener(.Wheel, nil, scroll_callback))
  assert(js.add_window_event_listener(.Resize, nil, size_callback))
}

// NOTE: frame loop is done by the runtime.js repeatedly calling `step`.
os_run :: proc() {
  state.os.initialized = true
}

@(private = "file", export)
step :: proc(dt: f32) -> bool {
  context = state.ctx

  if !state.os.initialized {
    return true
  }

  frame(dt)
  return true
}

os_fini :: proc() {
  // js.remove_window_event_listener(.Key_Down, nil, key_down_callback)
  // js.remove_window_event_listener(.Key_Up, nil, key_up_callback)
  js.remove_window_event_listener(.Mouse_Down, nil, mouse_down_callback)
  js.remove_window_event_listener(.Mouse_Up, nil, mouse_up_callback)
  js.remove_event_listener("wgpu-canvas", .Mouse_Move, nil, mouse_move_callback)
  js.remove_window_event_listener(.Wheel, nil, scroll_callback)
  js.remove_window_event_listener(.Resize, nil, size_callback)
}

os_get_render_bounds :: proc() -> (width, height: u32) {
  rect := js.get_bounding_client_rect("body")
  dpi := os_get_dpi()
  return u32(f32(rect.width) * dpi), u32(f32(rect.height) * dpi)
}

os_get_dpi :: proc() -> f32 {
  ratio := f32(js.device_pixel_ratio())
  return ratio
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
  return wgpu.InstanceCreateSurface(
    instance,
    &wgpu.SurfaceDescriptor {
      nextInChain = &wgpu.SurfaceDescriptorFromCanvasHTMLSelector {
        sType = .SurfaceDescriptorFromCanvasHTMLSelector,
        selector = "#wgpu-canvas",
      },
    },
  )
}

os_set_clipboard :: proc(_: rawptr, text: string) -> bool {
  // TODO: Use browser APIs
  clear(&state.os.clipboard)
  append(&state.os.clipboard, text)
  return true
}

os_get_clipboard :: proc(_: rawptr) -> (string, bool) {
  // TODO: Use browser APIs
  return string(state.os.clipboard[:]), true
}

@(private = "file")
mouse_down_callback :: proc(e: js.Event) {
  context = state.ctx

  // LEFT
  if e.data.mouse.button == 0 {
    state.pointer_down = true
  }

  js.event_prevent_default()
}

@(private = "file")
mouse_up_callback :: proc(e: js.Event) {
  context = state.ctx

  // LEFT
  if e.data.mouse.button == 0 {
    state.pointer_down = false
  }

  js.event_prevent_default()
}

@(private = "file")
mouse_move_callback :: proc(e: js.Event) {
  context = state.ctx
  state.cursor_pos = {f32(e.data.mouse.offset.x), f32(e.data.mouse.offset.y)} * os_get_dpi()
}

@(private = "file")
scroll_callback :: proc(e: js.Event) {
  context = state.ctx
  state.scroll_delta = {f32(e.data.wheel.delta.x), f32(e.data.wheel.delta.y)}
}

@(private = "file")
size_callback :: proc(e: js.Event) {
  context = state.ctx
  r_resize()
}
