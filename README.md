<!-- 2022-09-08-22-27-15 -->

# serpentine

Study app. Could become anything and change a lot, hence the name. May become a crude messaging platform.

## Rough intial roadmap

- [x] Command line arguments, using Clap for now.
- [ ] Debugging conveniences.
- [ ] Create database.
- [ ] Create server.
- [ ] Create client.
- [ ] Connect server and client.
- [ ] Create login GUI.
- [ ] Register multiple users.
- [ ] Login multiple users.
- [ ] Send messages between users.

## App goals

Study goals and by extension app goals, in no particular order:

- [ ] Learn Zig. All code will be in Zig.
- [ ] Documentation. Learn to document using Zig properly, and make that documentation available.
- [ ] Modules, including themes.
    - [ ] Unsandboxed mods that require user trust. `.dll`s?
    - [ ] Sandboxed mods. No trust unnecessary from the user, requires interpreter?
    - [ ] Server mods.
    - [ ] Client mods.
- [ ] Concurrency. Zig async, liburing to begin with, custom event loop.
- [ ] Parallelism.
    - [ ] Threads. 1 thread per core. Integration with event loop?
    - [ ] CUDA. Videos.
- [ ] Save to file.
- [ ] Load from file.
- [ ] File streaming. Videos.
    - [ ] To.
    - [ ] From.
- [ ] Database. Planning to use YugabyteDB as scaleable.
    - [ ] Database state tracking. Such as message edit history.
- [ ] GUI. Planning to use SDL + Dear ImGui + Vulkan. SDL well supported and perhaps more useful than GLFW, Dear Imgui supports all platforms and can used directly with Zig, Vulkan supports all platforms.
    - UI persistence, such that if a UI module persists between 'pages' it should not need to be reloaded.
- [ ] Login screen.
- [ ] Networking. Planning to use WebSockets. May require custom server.
- [ ] Network streaming. Voice and video. Planning to use WebRTC.
    - [ ] To.
    - [ ] From.
- [ ] Robust encryption.
    - [ ] Local. Of files and databases.
    - [ ] Network. Of all network traffic.
- [ ] Optimisation. To the extreme.
- [ ] Localisation.
- [ ] Accessibility.
- [ ] Library. If any code is useful enough, it will be converted to a library.
- [ ] zzz. Seems like one of the better options for readable data formats where required.
- [ ] Command line arguments.

Extra:

- [ ] Investigate using Zig to transpile Zig code into JavaScript and CSS for webclient with no extra code.
