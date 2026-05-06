# tekkit2_turtle_scripts
scripts used to define turtle behavior for various automation functions

CONTEXT:
producing all wire colors, chipsets, gates, as well as pipe pulsars and gate copiers

<!-- How to use -->
you will need 

enter wireles turtle or computer (with wireless modem) console, type the following command with the corresponding filename and script name:
wget https://github.com/oli1230/tekkit2_turtle_scripts/raw/refs/heads/main/lasers/<script_name>.lua <script_name>

if you want this to be automatic, just edit a file called "startup.lua" on each machine to have the contents: shell.run("<script_name>")

you will also need to add a redstone input of some kind from the left side of the computer by default, but easily edited at the top of the trigger script.