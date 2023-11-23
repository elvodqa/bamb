package main

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import "shared:freetype"

import "core:os"
import "core:fmt"
import "core:time"
import "core:strings"


Character :: struct {
    textureID : u32,
    size : glm.vec2,
    bearing : glm.vec2,
    advance: u32
}

textUniforms: gl.Uniforms
vao, vbo : u32
characters: map[u8]Character

main :: proc() {

    
   
    WINDOW_WIDTH  :: 1280
	WINDOW_HEIGHT :: 720

    userName := os.get_env("USERNAME")

    title := strings.concatenate({"bamb (USER: ", userName, ")"})

    window := sdl.CreateWindow(strings.clone_to_cstring(title), sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, {.OPENGL})
	if window == nil {
		fmt.eprintln("Failed to create window")
		return
	}
	defer sdl.DestroyWindow(window)

    
    when ODIN_OS == .Darwin {
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MAJOR_VERSION, 4)
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MINOR_VERSION, 1)
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_FLAGS, cast(i32)sdl.GLcontextFlag.FORWARD_COMPATIBLE_FLAG)
    } else {
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MAJOR_VERSION, 4)
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MINOR_VERSION, 6)
        sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
        
    }
    

    // vsync
    sdl.GL_SetSwapInterval(1)

    gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

    when ODIN_OS == .Darwin {
        gl.load_up_to(4, 6, sdl.GL_GetProcAddress)
    } else {
	    gl.load_up_to(4, 1, sdl.gl_set_proc_address)
    }

   
    frameStart, frameTime: u32
    maxFPS :: 60

    ft: freetype.Library
    freetype.Init_FreeType(&ft)

    face: freetype.Face
    if err := freetype.New_Face(ft, "fonts/OpenSans-Regular.ttf", 0, &face); err != 0 {
        fmt.eprintln("Failed to load font")
        return
    }

    freetype.Set_Pixel_Sizes(face, 0, 20)

    if err := freetype.Load_Char(face, 'x', freetype.LOAD_RENDER); err != 0 {
        fmt.eprintln("Failed to load glyph")
        return
    }

   

    characters = make(map[u8]Character)

    gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

    for c:u32=0; c < 128; c += 1 {
        if err := freetype.Load_Char(face, c, freetype.LOAD_RENDER); err != 0 {
            fmt.eprintln("Failed to load glyph")
            continue
        }
        texture : u32
        gl.GenTextures(1, &texture)
        gl.BindTexture(gl.TEXTURE_2D, texture)
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, cast(i32)face.glyph.bitmap.width, cast(i32)face.glyph.bitmap.rows, 0, gl.RED, gl.UNSIGNED_BYTE, face.glyph.bitmap.buffer)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        char := Character {
            textureID = texture,
            size = glm.vec2{cast(f32)face.glyph.bitmap.width, cast(f32)face.glyph.bitmap.rows},
            bearing = glm.vec2{cast(f32)face.glyph.bitmap_left, cast(f32)face.glyph.bitmap_top},
            advance = cast(u32)face.glyph.advance.x,
        }
       // map_insert(characters, c, char)
        characters[u8(c)] = char
    }


    freetype.Done_Face(face)
    freetype.Done_FreeType(ft)

    textShader, ok := gl.load_shaders_file("shaders/text.vert", "shaders/text.frag")
    if !ok {
        fmt.eprintln("Failed to load shaders")
        return
    }
    defer gl.DeleteProgram(textShader)

    textUniforms = gl.get_uniforms_from_program(textShader)
    defer delete(textUniforms)

    gl.UseProgram(textShader)
    
    projection := glm.mat4Ortho3d(0, cast(f32)WINDOW_WIDTH, cast(f32)WINDOW_HEIGHT, 0, -1, 1)
    gl.UniformMatrix4fv(textUniforms["projection"].location, 1, gl.FALSE, &projection[0][0])

    view := glm.identity(glm.mat4x4)
    gl.UniformMatrix4fv(textUniforms["view"].location, 1, gl.FALSE, &view[0][0])

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(f32) * 6 * 4, nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)



    b: strings.Builder
    strings.builder_init(&b)

    loop: for {
        frameStart = sdl.GetTicks()
    
		event: sdl.Event
		for sdl.PollEvent(&event) != false {
			#partial switch event.type {
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
				case .ESCAPE:
					
				}
                case .TEXTINPUT:
                   strings.write_rune(&b, rune(event.text.text[0]))
                    
			case .QUIT:
				break loop 
            }
		}

        gl.Enable(gl.BLEND)
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

		gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
		gl.ClearColor(0, 0, 0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.UseProgram(textShader)

        render_text(strings.to_string(b), 10, 10, 1.0, glm.vec3{1.0, 1.0, 1.0})
       
		sdl.GL_SwapWindow(window)	

       
       
        frameTime = sdl.GetTicks() - frameStart
        if frameTime < 1000/maxFPS {
            sdl.Delay(1000/maxFPS - frameTime)
        }
	}
}

render_text :: proc(text: string, x: i32, y: i32, scale: f32, color: glm.vec3) {
    _x := x
    _y := y

    model := glm.mat4Translate(glm.vec3{cast(f32)x, cast(f32)y, 0.0}) * glm.mat4Scale(glm.vec3{scale, scale, 1.0}) 
    gl.UniformMatrix4fv(textUniforms["model"].location, 1, gl.FALSE, &model[0][0])
    
    gl.Uniform3f(textUniforms["textColor"].location, color.x, color.y, color.z)
    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindVertexArray(vao)

    for c in text {
        ch := characters[u8(c)]

        // y is inverted so we need to flip it
        xpos := _x + cast(i32)ch.bearing.x * cast(i32)scale
        ypos := _y - (cast(i32)ch.size.y - cast(i32)ch.bearing.y) * -cast(i32)scale 

        w := cast(i32)ch.size.x * cast(i32)scale
        h := cast(i32)ch.size.y * cast(i32)scale * -1

        vertices := [6][4]f32 {
            {cast(f32)xpos, cast(f32)ypos + cast(f32)h, 0.0, 0.0},
            {cast(f32)xpos, cast(f32)ypos, 0.0, 1.0},
            {cast(f32)xpos + cast(f32)w, cast(f32)ypos, 1.0, 1.0},

            {cast(f32)xpos, cast(f32)ypos + cast(f32)h, 0.0, 0.0},
            {cast(f32)xpos + cast(f32)w, cast(f32)ypos, 1.0, 1.0},
            {cast(f32)xpos + cast(f32)w, cast(f32)ypos + cast(f32)h, 1.0, 0.0},
        }

        gl.BindTexture(gl.TEXTURE_2D, ch.textureID)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
        gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(vertices), &vertices[0])
        gl.BindBuffer(gl.ARRAY_BUFFER, 0)

        gl.DrawArrays(gl.TRIANGLES, 0, 6)

        _x += (cast(i32)ch.advance >> 6) * cast(i32)scale
    }
    gl.BindVertexArray(0)
    gl.BindTexture(gl.TEXTURE_2D, 0)
}
