## WHAT IS IT?

This model is an application of the [Firefiles Synchronization model](http://ccl.northwestern.edu/netlogo/models/Fireflies) for the [synchronization of Overlay Networks](https://en.wikipedia.org/wiki/Overlay_network). This model takes inspiration from ["Firefly-inspired Heartbeat Synchronization in Overlay Networks"](https://doi.org/10.1109/SASO.2007.25).

## HOW IT WORKS

This model wants to evaluate the application of the Ermentrout Synchronization model to different types of networks (lattice, small world and random) and different number of nodes (from 10 to 100).  

## HOW TO USE IT

The NUM-NODES slider controls the size of the network.
The FLASH-LENGTH slider controls the length of the flash in terms of ticks.
The SILENCE-TIME-BASELINE slider controls the length of ticks between one emission and the next one. It is a relative measure of synchronization, through this you che change che meaning of synchronization.
The NETWORK-TYPE chooser let you choose between 3 kind of network (Lattice, Small World and Random).
The FLASHES-TO-RESET slider controls how many flashes a node mush see to recompute its own cycle-length. 
The CONTINUE-AFTER-SYNC? toggle sets if you want to continue the simulation after the sync happened.

Choose one or more of these parameters and press SETUP.

### Statistics



### Plots

1. The "Number of simoultaneously flashing nodes" visualizes the number of flashing nodes that simoultaneously are flashing. You will see something only after 3 secs, that is the warm up period that you must wait to let the nework to setup. After about 10 secs you will see consecutive peaks. The bigger they are the more the nodes are flashing together.

2. The "Cycle-length of the first 10 nodes" visualizes the value of the first 10 nodes of the network. This is to show the trend of the cycle lengh of the nodes and shows how they change to be synchronized.


## CREDITS AND REFERENCES

This model is adapted from:

Wilensky, U. (1997). [NetLogo Fireflies model](http://ccl.northwestern.edu/netlogo/models/Fireflies). Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

and 

Wilensky, U. (2015). [NetLogo Small Worlds model](http://ccl.northwestern.edu/netlogo/models/SmallWorlds). Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

and it is a Netlogo implementation of:

O. Babaoglu, T. Binci, M. Jelasity and A. Montresor, "Firefly-inspired Heartbeat Synchronization in Overlay Networks*," First International Conference on Self-Adaptive and Self-Organizing Systems (SASO 2007), Cambridge, MA, USA, 2007, pp. 77-86, doi: https://doi.org/10.1109/SASO.2007.25

## HOW TO CITE

If you mention the model or the NetLogo software in a publication, you are asked to include the citations below.

For the model itself:

* Crescenzi, A. (2023). [Fireflies synchronization applied to Overlay Networks](https://github.com/alessandro-crescenzi/Fireflies-synchronization-applied-to-Overlay-Networks)

Please cite the NetLogo software as:

* Wilensky, U. (1999). [NetLogo](http://ccl.northwestern.edu/netlogo/). Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright (c) 2023 Alessandro Crescenzi - alessandrocrescenzi@outlook.com

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

<!-- 2023 -->
