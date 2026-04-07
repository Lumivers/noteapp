#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1280, 720);

  POINT cursor_pos;
  GetCursorPos(&cursor_pos);
  HMONITOR monitor = MonitorFromPoint(cursor_pos, MONITOR_DEFAULTTONEAREST);

  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitor_info);

  // Use a stable origin first; we will recenter with actual window pixel size.
  Win32Window::Point origin(10, 10);
  if (!window.Create(L"noteapp", origin, size)) {
    return EXIT_FAILURE;
  }

  HWND hwnd = window.GetHandle();
  RECT window_rect = {};
  GetWindowRect(hwnd, &window_rect);
  const int window_width = window_rect.right - window_rect.left;
  const int window_height = window_rect.bottom - window_rect.top;

  const RECT work_area = monitor_info.rcWork;
  const int centered_x = work_area.left + (work_area.right - work_area.left - window_width) / 2;
  const int centered_y = work_area.top + (work_area.bottom - work_area.top - window_height) / 2;

  SetWindowPos(
      hwnd, nullptr, centered_x, centered_y, 0, 0,
      SWP_NOZORDER | SWP_NOSIZE | SWP_NOACTIVATE);

  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
