# WGPU / Clay UI demo project

I use [Taskfile](https://taskfile.dev/) and it's integration with VSCode to build the project. With taskfile installed and added to your path, open the folder in VSCode and hit `F5` to run. This will build and run the wgpu project with glfw as the window handler. You can directly build the project by typing `task build-debug` in the command line or clicking the integrated task runner in VSCode. Requires the [Task](https://marketplace.visualstudio.com/items?itemName=task.vscode-task) extension.

![Taskfile selection](https://github.com/user-attachments/assets/92091ec8-0592-4bbe-9829-64a03ac23006)

To run the wasm build, run `task web` and serve the `build/web` directory. I find the [Live Server](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer) extension easiest to use when using VSCode, otherwise `python -m http.server --directory`.

*****

If you don't use VSCode/Taskfile, you can use the two batch files to build the glfw and web applications.
