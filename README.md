1. Arduino IDE -> Preferences -> Additional Boards Manager URLs: https://raw.githubusercontent.com/avtolstoy/particle-arduino/master/package_particle_index.json
2. Tools -> Board -> Board Manager: Install "Particle"


- Tools -> Programmer needs to be set to "Particle DFU"
- Tools -> Burn Bootloader updates system-part1 and system-part2 on Photon/P1/Electron to the version bundled with board support plugin (flashes monolithic tinker on Core)