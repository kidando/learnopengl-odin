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

## TODO
- [x] Chapter 1 - Getting Started
- [x] Chapter 2 - Lighting
- [ ] Chapter 3 - Model Loading
- [ ] Chapter 4 - Advanced OpenGL
- [ ] Chapter 5 - Advanced Lighting
- [ ] Chapter 6 - PBR
- [ ] Chapter 7 - Debugging
- [ ] Chapter 8 - Text Rendering
- [ ] Chapter 9 - 2D Game