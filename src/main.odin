package wgpu_app

import "base:runtime"
import clay "shared:clay/bindings/odin/clay-odin"

state := struct {
  ctx:      runtime.Context,
  bg:       [4]u8,
  os:       OS,
  renderer: Renderer,
  // cursor:          [2]i32,
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

  // mc := &state.mu_ctx
  // mu.begin(mc)
  // demo_windows(mc)
  // mu.end(mc)

  r_render()
}

measure_text :: proc "c" (text: ^clay.String, config: ^clay.TextElementConfig) -> clay.Dimensions {
  return {}
}

ui_error_handler :: proc "c" (errorData: clay.ErrorData) {
}
