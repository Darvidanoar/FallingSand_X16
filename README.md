# FallingSand_X16
My first Commander X16 6502 assembler coding attempt. I thought I'd try a simple 'Falling Sand' excercise.

![Falling sand](/FallingSand.png)

The objectives were to learn how to:
- use the ca65 assembler
- communicate with the VERA
- set a graphics mode
- plot pixels using the VERA
- read pixel values back from the VERA

I'm fairly new to 6502 assember and have plenty to learn, but this was a fun first challenge.

## Basic method of play
There is a colour palette at the top of the screen where the player can point and click the mouse to select a colour.  Then, the user can hold the mouse down anywhere in the 'play area' to drop sand pixels.
The sand pixels will fall to the bottom of the screen and pile up.

## The algorithm
Falling sand pixels are tracked in a 256 element array, starting at memory location $0C00.  
Each element of the array consists of four bytes:
- Colour of the sand pixel
- VRAM_Bank_Addr
- VRAM_Low_Addr
- VRAM_High_Addr

A zero value in the Colour byte signifies that the array element is empty and available for use.
The three address bytes contain the current memory address of the sand pixel in video RAM.

As the user holds down the mouse, sand pixels are added to the 256 element array.  

The program iterates through the array, checking to see if there is an empty (black) pixel below, below-right or below-left that the sand pixel can fall into.
If yes, then:
1. the address bytes in the array element are updated with the new pixel location;
1. the old pixel location is painted black; and
1. the new pixel location is painted with the pixel colour value from the first byte of the array element.

If there is no empty (black) pixel that the the sand pixel can fall into, then we assume we're at the bottom and the colour value in the array element is set to zero to indicate that this array element is now free for re-use.

The code's far from perfect and I may continue to fiddle with it and see if it can be turned into some sort of game.  However, I thought in its current form it might at least serve as sample code for someone who is also learning. 

## Acknowledgements
Thanks go to Matt Heffernan (The Retro Desk) for his excellent YouTube course on programming the Commander X16. This was a massive help.  

Thanks also go to David Murray, Kevin Williams and the Commander X16 team for making this machine a reality.
