# Zig Engine*
> *name not final

A general purpose low-level game engine written in Zig for Zig, using OpenGL & GLFW.

| Feature | Status |
| ------- | ------ |
| Text rendering | Done |
| Static mesh rendering | Done |
| OBJ Loading | Done |
| Textures | Done |
| SIMD Maths | Done |
| Object hierarchy | In progress |
| Animated Meshes | In progress |
| Immediate mode UI | Not started |
| Colliders | Not started |

This engine does not intend to handle higher level 'user-space' operations, such as:
- Loading textures (models are the exception here, since existing parsers leave a lot to be desired)
- Managing game loop state and multi-threading
- Scene / World editors
- Lighting / other advanced systems like navigation
