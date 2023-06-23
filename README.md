# LowPower-Contest
Simple plugin for PrimeTime, created as part of the "Synthesis and Optimization of Digital Systems" course at Polytechnic of Turin.

## Goal of the plugin
The goal of the project was to minimize the leakage power consumption by trying to find the best combination of HVT and LVT cells while satisfying some constraints:
- the slack of the most critical path of the circuit had to be positive ( >= 0 );
- the fanout endpoint cost for each cell in the circuit had to be lower than a certain threshold specified to the main function as an argument;
- cells had to maintain the same footprint (same size and area).

The execution time of the algorithm was also constrained in order for it to not take too much time in finding a solution to the problem.

## Expected parameters
Two arguments are expected by the program:
- **slackThreshold**: endpoints with a slack lower than this value are defined as **violating endpoints** (value ranging from 0 to 0.1ns);
- **maxFanoutEndpointCost**: the maximum fanout endpoint cost for each cell in the circuit.

## Algorithm
An explanation of the algorithm used inside the plugin for finding a combination of HVT and LVT cells to better reduce the leakage power consumption can be found inside the .pdf inside the repository.

## Authors 
- [Matteo Isoldi](https://github.com/bOhYee)
- [Filippo Marostica](https://github.com/filippomarostica)
- [Elena Roncolino](https://github.com/elenaroncolino)