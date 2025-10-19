# Learn OpenGL (https://learnopengl.com/) examples in Odin
This repo contains code for the examples from the [Learn OpenGl](https://learnopengl.com/) site but written in Odin. At the end of each chapter on the site, there is a link to C++ source code. This project replicates that but again, using Odin.

## What you need before you start
- You will need to install Odin. The [Getting Started](https://odin-lang.org/docs/install/) guide has different options you can follow.
- If you have Odin already, I suggest that you update it. I will be using the most recent build of odin as of the time I uploaded this repo onto github.
- You will need a text editor or IDE. This project was a put together in [VS Code](https://code.visualstudio.com/) (and on Win11)
- That's it. Odin ships with the libraries needed to follow along with the tutorials on learnopengl. Plus the additional assets required are contained in the project.

## Changes compared the C++ versions
For starters, Odin is not an object-oriented language while C++ is. In the original C++ versions, OOP is used in certain chapters. In this project there are places where I will use functions to minimize code repetition and to make the code a lot more readable.

Also, this is not going to be a "direct translation" from C++ to Odin. There are concepts in Odin that are just different or let me say, interpreted differently. Because of that, I shall try my best using comments, to explain what exactly the Odin code is doing in contrast to it's C++ counterpart.

## How to run the projects
This is not one large Odin project, instead it is a collection of smaller Odin projects grouped by chapters. To run each project, you will need to enter each folder and run the project from there. Simply run ```odin run .``` and you will be good to go.
```
cd 1-4-a-hello-triangle/
odin run .
```

## If you get stuck or need help
- Bugs in my code could cause you to get stuck. If you catch a bug, please submit an issue
- I highly recommend visiting [Learn OpenGL](https://learnopengl.com/) to get in-depth explanations (outside of code) of how things work.
- If you need assistance with Odin and OpenGL, I highly recommend joining two Discord servers
  - [Odin Programming Language](https://discord.gg/Dh7vnfff)
  - [Karl's Community](https://discord.gg/UvTaBesN)
- If you are new to Odin and are interested in learning it, I recommend checking the [Odin website](https://odin-lang.org/). You can also follow [Ginger Bill (Creator of Odin) on Youtube](https://www.youtube.com/@GingerGames). You can also checkout [Karl's Youtube Channel](https://www.youtube.com/@karl_zylinski) and I recommend buying his book [Odin Book](https://odinbook.com/).
- It goes without saying but using web search engines helps
- In case you use ChatGPT or equivalent, just keep in mind that unlike search engine results, these programs tend to return just 1 solution or result that they deem most accurate/relevant. As opposed to a list of different results that you could compare and analyze yourself. That 1 result may not always be correct (I speak from experience 😭)

## Notes
### Chapter 3 Modeling Loading With Assimp (Not Working 100%)
- To use the [Assimp](https://github.com/assimp/assimp) library for odin to follow along with learnopengl.org import oding bindings library [Odin-Assimp](https://github.com/CoolDove/odin-assimp/tree/master)
- To follow  along with this project you can import this library into the shared folder of where you have installed your odin repo locally. For example it could be that you installed/cloned odin to ```C:\Odin```. 
- Open your terminal in this location and cd into the ```shared``` directory so that it becomes ```C:\Odin\shared```
- Clone the odin-assimp library into this directory by running ```git clone https://github.com/CoolDove/odin-assimp.git```
- This will allow you to use the assimp library in all your odin projects moving forward. Simply add the following import statement at the top of your odin file ```import assimp "shared:odin-assimp"```
- I added this just so that I could follow along with learnopengl. However, I highly recommend using the cgltf package I describe next.

### Chapter 3 Model Loading With CGLTF (Works 100% for simple models)
- To use the [cgltf package](https://pkg.odin-lang.org/vendor/cgltf/) simply import it from vendor as it ships with odin.
- Just add ```import "vendor:cgltf"``` at the top of your file. In my implementation I import it as ```import cg "vendor:cgltf"```.
- This will be the loader used for the rest of the lessons
- NOTE: This is not a "production ready" solution. Models that are more complex in structure may need the ```asset_importer.odin``` file to be updated to work correctly. 

### Chapter 4 Differences in how the final application build looks
- There is a slight (or maybe not so slight) difference in my application build compared to what learnopengl has as their application build. In this chapter it is the first time we use random number generation and if I were to guess, that is where the cause of the difference may lie. However, this goal of the chapters are met regardless of the visual difference.

### Chapter 5 - Point Shadows not working
- For some reason, shadows are not being cast as seen in the Point Shadows section on LearnOpenGL. The odin code is more or less identical to it's C++ counter part.
- I have a couple of guesses why.
  - Something to do with the graphics card I'm using. It's an IntelHD or UHD. Maybe the way cubemaps are drawn or how the card is instructed to draw them is different (I really have no idea).
  - Something about the opengl specification regarding cubemap generation has changed from the time this chapter was published over at learnopengl.org (more than a decade ago, but again... I really have no idea).
  - Something to do with the shaders. Specifically the geometry shader and how it constructs the shadows. I did notice that trying to uncomment sections of the code in the fragment shader that are meant to be used for testing shadow generation and depth values generation cause a segmentation fault when trying to run the program. So I'm guessing that the GLSL code probably needs some kind of update. Maybe things have change (but as always... I really have no idea).
- If you manage to figure out how to get shadows working, please share the find.

### Chapter 7 - Debugging
- This chapter deals with debugging and the tools you might find helpful when working in OpenGL. So there was not too much I did in terms of "translating" c++ code to odin. But the ```main.odin``` file in this chapter's folder contains 2 functions that help you get started with getting openGl errors and window context errors (from GLFW).

## TODO
- [x] Chapter 1 - Getting Started
- [x] Chapter 2 - Lighting
- [x] Chapter 3 - Model Loading
- [x] Chapter 4 - Advanced OpenGL
- [x] Chapter 5 - Advanced Lighting
- [x] Chapter 6 - PBR
- [x] Chapter 7 - Debugging
- [ ] Chapter 8 - Text Rendering
- [ ] Chapter 9 - 2D Game