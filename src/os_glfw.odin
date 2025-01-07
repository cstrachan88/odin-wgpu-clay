#+build !js
package wgpu_app

import "core:log"
import "core:math"
import "core:strings"
import "core:time"
import "core:unicode/utf8"
import "vendor:glfw"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

OS :: struct {
  window: glfw.WindowHandle,
}

os_init :: proc() {
  if !glfw.Init() {
    panic("[glfw] init failure")
  }

  glfw.WindowHint(glfw.SCALE_TO_MONITOR, true)
  glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
  state.os.window = glfw.CreateWindow(800, 600, "ODIN / GLFW / MICROUI / WGPU", nil, nil)
  assert(state.os.window != nil)

  glfw.SetKeyCallback(state.os.window, key_callback)
  glfw.SetMouseButtonCallback(state.os.window, mouse_button_callback)
  glfw.SetCursorPosCallback(state.os.window, cursor_pos_callback)
  glfw.SetScrollCallback(state.os.window, scroll_callback)
  // glfw.SetCharCallback(state.os.window, char_callback)
  glfw.SetFramebufferSizeCallback(state.os.window, size_callback)
}

os_run :: proc() {
  for !glfw.WindowShouldClose(state.os.window) {
    glfw.PollEvents()
    do_frame()
  }

  glfw.DestroyWindow(state.os.window)
  glfw.Terminate()
}

@(private = "file")
do_frame :: proc() {
  @(static) frame_time: time.Tick
  if frame_time == {} {
    frame_time = time.tick_now()
  }

  new_frame_time := time.tick_now()
  dt := time.tick_diff(frame_time, new_frame_time)
  frame_time = new_frame_time

  frame(f32(time.duration_seconds(dt)))
}

os_get_render_bounds :: proc() -> (width, height: u32) {
  iw, ih := glfw.GetFramebufferSize(state.os.window)
  return u32(iw), u32(ih)
}

os_get_dpi :: proc() -> f32 {
  sw, sh := glfw.GetWindowContentScale(state.os.window)
  if sw != sh {
    log.warnf("dpi x (%v) and y (%v) not the same", sw, sh)
  }
  return sw
}

os_get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
  return glfwglue.GetSurface(instance, state.os.window)
}

os_set_clipboard :: proc(_: rawptr, text: string) -> bool {
  glfw.SetClipboardString(state.os.window, strings.clone_to_cstring(text, context.temp_allocator))
  return true
}

os_get_clipboard :: proc(_: rawptr) -> (string, bool) {
  clipboard := glfw.GetClipboardString(state.os.window)
  return clipboard, true
}

@(private = "file")
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
  context = state.ctx

  switch key {
    // case glfw.KEY_LEFT_SHIFT, glfw.KEY_RIGHT_SHIFT:     mu_key = .ALT
    // case glfw.KEY_LEFT_CONTROL, glfw.KEY_RIGHT_CONTROL,
    //      glfw.KEY_LEFT_SUPER, glfw.KEY_RIGHT_SUPER:     mu_key = .CTRL
    // case glfw.KEY_LEFT_ALT, glfw.KEY_RIGHT_ALT:         mu_key = .ALT
    // case glfw.KEY_BACKSPACE:                            mu_key = .BACKSPACE
    // case glfw.KEY_DELETE:                               mu_key = .DELETE
    // case glfw.KEY_ENTER:                                mu_key = .RETURN
    // case glfw.KEY_LEFT:                                 mu_key = .LEFT
    // case glfw.KEY_RIGHT:                                mu_key = .RIGHT
    // case glfw.KEY_HOME:                                 mu_key = .HOME
    // case glfw.KEY_END:                                  mu_key = .END
    // case glfw.KEY_A:                                    mu_key = .A
    // case glfw.KEY_X:                                    mu_key = .X
    // case glfw.KEY_C:                                    mu_key = .C
    case glfw.KEY_ESCAPE:
      glfw.SetWindowShouldClose(window, true)
    case:
      return
  }

  // switch action {
  // case glfw.PRESS, glfw.REPEAT: mu.input_key_down(&state.mu_ctx, mu_key)
  // case glfw.RELEASE:            mu.input_key_up  (&state.mu_ctx, mu_key)
  // case:                         return
  // }
}

@(private = "file")
mouse_button_callback :: proc "c" (window: glfw.WindowHandle, key, action, mods: i32) {
  context = state.ctx

  left_click := false

  switch key {
    case glfw.MOUSE_BUTTON_LEFT: left_click = true
  }

  if left_click {
    switch action {
      case glfw.PRESS: state.pointer_down = true
      case glfw.RELEASE: state.pointer_down = false
    }
  }
}

@(private = "file")
cursor_pos_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
  context = state.ctx
  dpi := os_get_dpi()
  state.cursor_pos = {f32(x) / dpi, f32(y) / dpi}
}

@(private = "file")
scroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
  context = state.ctx
  state.scroll_delta = {f32(x), f32(y)}
}

// @(private="file")
// char_callback :: proc "c" (window: glfw.WindowHandle, ch: rune) {
// 	context = state.ctx
// 	bytes, size := utf8.encode_rune(ch)
// 	mu.input_text(&state.mu_ctx, string(bytes[:size]))
// }

@(private = "file")
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
  context = state.ctx
  r_resize()
  do_frame()
}
