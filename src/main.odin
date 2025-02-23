package wgpu_app

import "base:runtime"
import "core:log"

@(require) import "core:fmt"
@(require) import "core:mem"

// import clay "shared:clay/bindings/odin/clay-odin"
import clay "../../clay/bindings/odin/clay-odin"

LOG_LEVEL :: log.Level.Debug when ODIN_DEBUG else log.Level.Info

state := struct {
  ctx:          runtime.Context,
  bg:           [4]u8,
  os:           OS,
  renderer:     Renderer,
  cursor_pos:   [2]f32,
  pointer_down: bool,
  scroll_delta: [2]f32,
  show_debug:   bool,
} {
  bg = {90, 95, 100, 255},
}

main :: proc() {
  when ODIN_DEBUG {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
      if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
          fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
      }
      if len(track.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
        for entry in track.bad_free_array {
          fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
      }
      mem.tracking_allocator_destroy(&track)
    }
  }
  context.logger = log.create_console_logger(LOG_LEVEL)
  state.ctx = context

  min_memory_size: u32 = clay.MinMemorySize()
  memory := make([]u8, min_memory_size)
  defer delete(memory)

  arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(min_memory_size, raw_data(memory))
  clay.SetMeasureTextFunction(measure_text)

  os_init()

  clay.SetCullingEnabled(true)
  // clay.SetDebugModeEnabled(true)

  width, height := os_get_render_bounds()
  clay.Initialize(arena, {f32(width), f32(height)}, {handler = ui_error_handler})

  r_init_and_run()
}

finalize :: proc() {
  log.destroy_console_logger(state.ctx.logger)
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

is_debug_visible :: #force_inline proc() -> bool {
  return clay.IsDebugModeEnabled()
}
set_debug_display :: #force_inline proc(show: bool) {
  clay.SetDebugModeEnabled(show)
}
