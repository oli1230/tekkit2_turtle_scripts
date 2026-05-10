# tekkit2_turtle_scripts
scripts used to define turtle behavior for various automation functions


CONTEXT:
producing all wire colors, chipsets, gates, as well as pipe pulsars and gate copiers


HOW TO USE:
you will need one computer with a wireless modem, and 6 or 7 wireless turtles. without placing any assembly tables adjacent to each other, place the assembly tables under some lasers, and put a wireless turtle under each. Under the turtle you need a chest, and then a logistic chassis with a few slots. You will need to set this chassis up to be both a provider of the relavent chipsets/gates/whatever as well as a supplier (active supplier modules work best) of all of the ingredients for everything the table provides. Good luck soldier.

set up a computer somewhere with a wireless modem

enter wireles turtle or computer (with wireless modem) console, type the following command with the corresponding filename and script name:
wget https://github.com/oli1230/tekkit2_turtle_scripts/raw/refs/heads/main/lasers/<script_name>.lua <script_name>
(one script is for the computer to trigger all of the turtles - trigger_script.lua - and the rest are for turtles and their respective assembly tables)

if you want this to be automatic, just edit a file called "startup.lua" on each machine to have the contents: shell.run("<script_name>")

you will also need to add a redstone input of some kind from the left side of the computer by default, but this triggering mechanism can easily edited at the top of the trigger script.