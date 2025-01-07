package wgpu_app

import "base:runtime"
import clay "shared:clay/bindings/odin/clay-odin"

state := struct {
  ctx:          runtime.Context,
  bg:           [4]u8,
  os:           OS,
  renderer:     Renderer,
  cursor_pos:   [2]f32,
  pointer_down: bool,
  scroll_delta: [2]f32,
} {
  bg = {90, 95, 100, 255},
}

main :: proc() {
  state.ctx = context

  min_memory_size: u32 = clay.MinMemorySize()
  memory := make([]u8, min_memory_size)
  defer delete(memory)

  arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(min_memory_size, raw_data(memory))
  clay.SetMeasureTextFunction(measure_text)

  os_init()

  width, height := os_get_render_bounds()
  clay.Initialize(arena, {f32(width), f32(height)}, {handler = ui_error_handler})

  r_init_and_run()
}

frame :: proc(dt: f32) {
  free_all(context.temp_allocator)

  // Update UI
  clay.SetPointerState(state.cursor_pos, state.pointer_down)
  clay.UpdateScrollContainers(false, state.scroll_delta, dt)
  clay.SetLayoutDimensions({f32(state.renderer.config.width), f32(state.renderer.config.height)})

  r_render()
}

ui_error_handler :: proc "c" (errorData: clay.ErrorData) {
}
