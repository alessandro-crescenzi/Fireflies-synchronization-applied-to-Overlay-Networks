globals [
  infinity         ; used to represent the distance between two turtles with no path between them
  highlight-string ; message that appears on the node properties monitor

  average-path-length-of-lattice       ; average path length of the initial lattice
  average-path-length                  ; average path length in the current network

  clustering-coefficient-of-lattice    ; the clustering coefficient of the initial lattice
  clustering-coefficient               ; the clustering coefficient of the current network (avg. across nodes)

  number-rewired                       ; number of edges that have been rewired
  rewire-one?                          ; these two variables record which button was last pushed
  rewire-all?
  upper-cycle-length
  lower-cycle-length
]

turtles-own [
  clock        ;; each firefly's clock
  threshold    ;; the clock tick at which a firefly stops its flash
  reset-level  ;; the clock tick a firefly will reset to when it is triggered by other flashing
  distance-from-other-turtles ; list of distances of this node from other turtles
  my-clustering-coefficient   ; the current clustering coefficient of this node
  cycle-length
  natural-cycle-length
  first-cycle-length
  first-flash
]

links-own [
  rewired? ; keeps track of whether the link has been rewired or not
]

;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

to startup
  set highlight-string ""
end

to setup
  clear-all

  set upper-cycle-length 115
  set lower-cycle-length 85

  ; set the global variables
  set infinity 99999      ; this is an arbitrary choice for a large number
  set number-rewired 0    ; initial count of rewired edges
  set highlight-string "" ; clear the highlight monitor

  ; make the nodes and arrange them in a circle in order by who number
  set-default-shape turtles "circle"
  create-turtles num-nodes [
    set first-cycle-length random(300)
    set first-flash 0
    set natural-cycle-length lower-cycle-length + (random (upper-cycle-length - lower-cycle-length))
    set cycle-length natural-cycle-length
    set clock random (round cycle-length)
    set threshold flash-length
    set reset-level threshold
    set size 2  ;; easier to see
    set color gray - 2
  ]
  layout-circle (sort turtles) max-pxcor - 1

  ; Fix the color scheme
  ask links [ set color gray + 2 ]

  wire-lattice

  ; Calculate the initial average path length and clustering coefficient
  set average-path-length find-average-path-length
  set clustering-coefficient find-clustering-coefficient

  set average-path-length-of-lattice average-path-length
  set clustering-coefficient-of-lattice clustering-coefficient

  ; Create the initial lattice
  ifelse network-type = "Lattice" [ wire-lattice ] [ rewire ]

  reset-ticks
end

to go
  ask turtles [
    increment-clock
    look
    recolor
  ]
  tick
end

;;;;;;;;;;;;;;;;;;;;;
;; Main Procedures ;;
;;;;;;;;;;;;;;;;;;;;;

to rewire-me ; turtle procedure
  ; node-A remains the same
  let node-A end1
  ; as long as A is not connected to everybody
  if [ count link-neighbors ] of end1 < (count turtles - 1) [
    ; find a node distinct from A and not already a neighbor of "A"
    let node-B one-of turtles with [ (self != node-A) and (not link-neighbor? node-A) ]
    ; wire the new edge
    ask node-A [ create-link-with node-B [ set color cyan set rewired? true ] ]

    set number-rewired number-rewired + 1
    die ; remove the old edge
  ]
end

to rewire
  ; confirm we have the right amount of turtles, otherwise reinitialize
  if count turtles != num-nodes [ setup ]

  let rewiring-probability 1
  if network-type = "Small World" [ set rewiring-probability 0.1 ]

  ; record which button was pushed
  set rewire-one? false
  set rewire-all? true

  ; we keep generating networks until we get a connected one since apl doesn't mean anything
  ; in a non-connected network
  let connected? false
  while [ not connected? ] [
    ; kill the old lattice and create new one
    ask links [ die ]
    wire-lattice
    set number-rewired 0

    ; ask each link to maybe rewire, according to the rewiring-probability slider
    ask links [
      if (random-float 1) < rewiring-probability [ rewire-me ]
    ]

    ; if the apl is infinity, it means our new network is not connected. Reset the lattice.
    ifelse find-average-path-length = infinity [ set connected? false ] [ set connected? true ]
    if network-type = "Random" [ ifelse find-clustering-coefficient < (clustering-coefficient-of-lattice * 0.1) [set connected? true] [set connected? false] ]
    if network-type = "Small World" [ ifelse find-clustering-coefficient > (clustering-coefficient-of-lattice * 0.8) [set connected? true] [set connected? false] ]
  ]

  ; calculate the statistics and visualize the data
  set clustering-coefficient find-clustering-coefficient
  set average-path-length find-average-path-length
  update-plots
end

;;;;;;;;;;;;;;;;
;; Clustering computations ;;
;;;;;;;;;;;;;;;;

to-report in-neighborhood? [ hood ]
  report ( member? end1 hood and member? end2 hood )
end


to-report find-clustering-coefficient

  let cc infinity

  ifelse all? turtles [ count link-neighbors <= 1 ] [
    ; it is undefined
    ; what should this be?
    set cc 0
  ][
    let total 0
    ask turtles with [ count link-neighbors <= 1 ] [ set my-clustering-coefficient "undefined" ]
    ask turtles with [ count link-neighbors > 1 ] [
      let hood link-neighbors
      set my-clustering-coefficient (2 * count links with [ in-neighborhood? hood ] /
                                         ((count hood) * (count hood - 1)) )
      ; find the sum for the value at turtles
      set total total + my-clustering-coefficient
    ]
    ; take the average
    set cc total / count turtles with [count link-neighbors > 1]
  ]

  report cc
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Path length computations ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Procedure to calculate the average-path-length (apl) in the network. If the network is not
; connected, we return `infinity` since apl doesn't really mean anything in a non-connected network.
to-report find-average-path-length

  let apl 0

  ; calculate all the path-lengths for each node
  find-path-lengths

  let num-connected-pairs sum [length remove infinity (remove 0 distance-from-other-turtles)] of turtles

  ; In a connected network on N nodes, we should have N(N-1) measurements of distances between pairs.
  ; If there were any "infinity" length paths between nodes, then the network is disconnected.
  ifelse num-connected-pairs != (count turtles * (count turtles - 1)) [
    ; This means the network is not connected, so we report infinity
    set apl infinity
  ][
    set apl (sum [sum distance-from-other-turtles] of turtles) / (num-connected-pairs)
  ]

  report apl
end

; Implements the Floyd Warshall algorithm for All Pairs Shortest Paths
; It is a dynamic programming algorithm which builds bigger solutions
; from the solutions of smaller subproblems using memoization that
; is storing the results. It keeps finding incrementally if there is shorter
; path through the kth node. Since it iterates over all turtles through k,
; so at the end we get the shortest possible path for each i and j.
to find-path-lengths
  ; reset the distance list
  ask turtles [
    set distance-from-other-turtles []
  ]

  let i 0
  let j 0
  let k 0
  let node1 one-of turtles
  let node2 one-of turtles
  let node-count count turtles
  ; initialize the distance lists
  while [i < node-count] [
    set j 0
    while [ j < node-count ] [
      set node1 turtle i
      set node2 turtle j
      ; zero from a node to itself
      ifelse i = j [
        ask node1 [
          set distance-from-other-turtles lput 0 distance-from-other-turtles
        ]
      ][
        ; 1 from a node to it's neighbor
        ifelse [ link-neighbor? node1 ] of node2 [
          ask node1 [
            set distance-from-other-turtles lput 1 distance-from-other-turtles
          ]
        ][ ; infinite to everyone else
          ask node1 [
            set distance-from-other-turtles lput infinity distance-from-other-turtles
          ]
        ]
      ]
      set j j + 1
    ]
    set i i + 1
  ]
  set i 0
  set j 0
  let dummy 0
  while [k < node-count] [
    set i 0
    while [i < node-count] [
      set j 0
      while [j < node-count] [
        ; alternate path length through kth node
        set dummy ( (item k [distance-from-other-turtles] of turtle i) +
                    (item j [distance-from-other-turtles] of turtle k))
        ; is the alternate path shorter?
        if dummy < (item j [distance-from-other-turtles] of turtle i) [
          ask turtle i [
            set distance-from-other-turtles replace-item j distance-from-other-turtles dummy
          ]
        ]
        set j j + 1
      ]
      set i i + 1
    ]
    set k k + 1
  ]

end

;;;;;;;;;;;;;;;;;;;;;
;; Edge Operations ;;
;;;;;;;;;;;;;;;;;;;;;

; creates a new lattice
to wire-lattice
  ; iterate over the turtles
  let n 0
  while [ n < count turtles ] [
    ; make edges with the next two neighbors
    ; this makes a lattice with average degree of 4
    make-edge turtle n
              turtle ((n + 1) mod count turtles)
              "default"
    ; Make the neighbor's neighbor links curved
    make-edge turtle n
              turtle ((n + 2) mod count turtles)
              "curve"
    set n n + 1
  ]

  ; Because of the way NetLogo draws curved links between turtles of ascending
  ; `who` number, two of the links near the top of the network will appear
  ; flipped by default. To avoid this, we used an inverse curved link shape
  ; ("curve-a") which makes all of the curves face the same direction.
  ask link 0 (count turtles - 2) [ set shape "curve-a" ]
  ask link 1 (count turtles - 1) [ set shape "curve-a" ]
end

; Connects two nodes
to make-edge [ node-A node-B the-shape ]
  ask node-A [
    create-link-with node-B  [
      set shape the-shape
      set rewired? false
    ]
  ]
end

;;;;;;;;;;;;;;;;;;
;; Highlighting ;;
;;;;;;;;;;;;;;;;;;

to highlight
  ; remove any previous highlights
  ask turtles [ set color gray + 2 ]
  ask links   [ set color gray + 2 ]

  ; if the mouse is in the View, go ahead and highlight
  if mouse-inside? [ do-highlight ]

  ; force updates since we don't use ticks
  display
end

to do-highlight
  ; getting the node closest to the mouse
  let min-d min [ distancexy mouse-xcor mouse-ycor ] of turtles
  let node one-of turtles with [count link-neighbors > 0 and distancexy mouse-xcor mouse-ycor = min-d]

  if node != nobody [
    ; highlight the chosen node
    ask node [
      set color white
      let pairs (length remove infinity distance-from-other-turtles)
      let my-apl (sum remove infinity distance-from-other-turtles) / pairs

      ; show node's statistics
      let coefficient-description ifelse-value my-clustering-coefficient = "undefined"
        ["undefined for single-link"]
        [precision my-clustering-coefficient 3]
      set highlight-string (word "clustering coefficient = " coefficient-description
        " and avg path length = " precision my-apl 3
        " (for " pairs " turtles )")
    ]

    let neighbor-nodes [ link-neighbors ] of node
    let direct-links [ my-links ] of node

    ; highlight neighbors
    ask neighbor-nodes [
      set color orange
      ; highlight edges connecting the chosen node to its neighbors
      ask my-links [
        ifelse (end1 = node or end2 = node)
          [ set color orange ]
          [ if (member? end1 neighbor-nodes and member? end2 neighbor-nodes) [ set color yellow ]
        ]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;
;;   Sync part   ;;
;;;;;;;;;;;;;;;;;;;

to increment-clock ; turtle procedure
  set clock (clock + 1)
  if clock = first-cycle-length and first-flash = 0 [
   set first-flash 1
   set clock 0
  ]
  if clock = cycle-length and first-flash = 1 [
    set clock 0
  ]
end


to look ; turtle procedure
  if count link-neighbors with [color = yellow] >= flashes-to-reset [
    let _sin (sin ( 2 * pi * ( clock / cycle-length ) ) ) / (2 * pi)
    let _max  0
    if _sin > 0 [ set _max _sin ]
    let _min 0
    if _sin < 0 [ set _min _sin ]
    let omega_l 1 / upper-cycle-length
    let omega_u 1 / lower-cycle-length
    let omega 1 / natural-cycle-length
    let omega_i 1 / cycle-length
    set omega_i ( omega_i + 0.01 * ( omega - omega_i) + _max * ( omega_l - omega_i ) - _min * ( omega_u - omega_i ) )
    set cycle-length round ( 1 / omega_i )
    if cycle-length < lower-cycle-length [ set cycle-length lower-cycle-length ]
    if cycle-length > upper-cycle-length [ set cycle-length upper-cycle-length ]
  ]
end

to recolor ; turtle procedure
  ifelse (clock < threshold)
    [ show-turtle
      set color yellow ]
  [ set color gray - 2]
      ;ifelse show-dark-fireflies?
        ;[ show-turtle ]
       ;[ hide-turtle ] ]
end


; Copyright 2015 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
10
50
438
479
-1
-1
12.0
1
10
1
1
1
0
0
0
1
-17
17
-17
17
1
1
0
ticks
30.0

SLIDER
120
10
435
43
num-nodes
num-nodes
10
100
28.0
1
1
NIL
HORIZONTAL

MONITOR
445
100
990
145
highlighted node properties
highlight-string
3
1
11

BUTTON
445
65
990
98
NIL
highlight
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
50
485
222
530
clustering-coefficient (cc)
clustering-coefficient
3
1
11

MONITOR
225
485
397
530
average-path-length (apl)
average-path-length
3
1
11

BUTTON
11
10
116
43
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
650
10
789
55
network-type
network-type
"Lattice" "Small World" "Random"
2

BUTTON
445
160
630
193
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
645
160
830
193
go-forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
445
255
602
288
show-dark-nodes?
show-dark-nodes?
0
1
-1000

SLIDER
655
250
827
283
flash-length
flash-length
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
660
325
832
358
flashes-to-reset
flashes-to-reset
0
10
1.0
1
1
NIL
HORIZONTAL

PLOT
1005
315
1565
670
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-y-range 0 num-nodes" ""
PENS
"flashing" 1.0 0 -2674135 true "" "plot count turtles with [color = yellow]"

@#$#@#$#@
## WHAT IS IT?

This model explores the formation of networks that result in the "small world" phenomenon -- the idea that a person is only a couple of connections away from any other person in the world.

A popular example of the small world phenomenon is the network formed by actors appearing in the same movie (e.g., "[Six Degrees of Kevin Bacon](https://en.wikipedia.org/wiki/Six_Degrees_of_Kevin_Bacon)"), but small worlds are not limited to people-only networks. Other examples range from power grids to the neural networks of worms. This model illustrates some general, theoretical conditions under which small world networks between people or things might occur.

## HOW IT WORKS

This model is an adaptation of the [Watts-Strogatz model](https://en.wikipedia.org/wiki/Watts-Strogatz_model) proposed by Duncan Watts and Steve Strogatz (1998). It begins with a network where each person (or "node") is connected to his or her two neighbors on either side. Using this a base, we then modify the network by rewiring nodes–changing one end of a connected pair of nodes and keeping the other end the same. Over time, we analyze the effect this rewiring has the on various connections between nodes and on the properties of the network.

Particularly, we're interested in identifying "small worlds." To identify small worlds, the "average path length" (abbreviated "apl") and "clustering coefficient" (abbreviated "cc") of the network are calculated and plotted after a rewiring is performed. Networks with _short_ average path lengths and _high_ clustering coefficients are considered small world networks. See the **Statistics** section of HOW TO USE IT on how these are calculated.

## HOW TO USE IT

The NUM-NODES slider controls the size of the network. Choose a size and press SETUP.

Pressing the REWIRE-ONE button picks one edge at random, rewires it, and then plots the resulting network properties in the "Network Properties Rewire-One" graph. The REWIRE-ONE button _ignores_ the REWIRING-PROBABILITY slider. It will always rewire one exactly one edge in the network that has not yet been rewired _unless_ all edges in the network have already been rewired.

Pressing the REWIRE-ALL button starts with a new lattice (just like pressing SETUP) and then rewires all of the edges edges according to the current REWIRING-PROBABILITY. In other words, it `asks` each `edge` to roll a die that will determine whether or not it is rewired. The resulting network properties are then plotted on the "Network Properties Rewire-All" graph. Changing the REWIRING-PROBABILITY slider changes the fraction of edges rewired during each run. Running REWIRE-ALL at multiple probabilities produces a range of possible networks with varying average path lengths and clustering coefficients.

When you press HIGHLIGHT and then point to a node in the view it color-codes the nodes and edges. The node itself turns white. Its neighbors and the edges connecting the node to those neighbors turn orange. Edges connecting the neighbors of the node to each other turn yellow. The amount of yellow between neighbors gives you a sort of indication of the clustering coefficient for that node. The NODE-PROPERTIES monitor displays the average path length and clustering coefficient of the highlighted node only. The AVERAGE-PATH-LENGTH and CLUSTERING-COEFFICIENT monitors display the values for the entire network.

### Statistics

**Average Path Length**: Average path length is calculated by finding the shortest path between all pairs of nodes, adding them up, and then dividing by the total number of pairs. This shows us, on average, the number of steps it takes to get from one node in the network to another.

In order to find the shortest paths between all pairs of nodes we use the [standard dynamic programming algorithm by Floyd Warshall] (https://en.wikipedia.org/wiki/Floyd-Warshall_algorithm). You may have noticed that the model runs slowly for large number of nodes. That is because the time it takes for the Floyd Warshall algorithm (or other "all-pairs-shortest-path" algorithm) to run grows polynomially with the number of nodes.

**Clustering Coefficient**: The clustering coefficient of a _node_ is the ratio of existing edges connecting a node's neighbors to each other to the maximum possible number of such edges. It is, in essence, a measure of the "all-my-friends-know-each-other" property. The clustering coefficient for the entire network is the average of the clustering coefficients of all the nodes.

### Plots

1. The "Network Properties Rewire-One" visualizes the average-path-length and clustering-coefficient of the network as the user increases the number of single-rewires in the network.

2. The "Network Properties Rewire-All" visualizes the average-path-length and clustering coefficient of the network as the user manipulates the REWIRING-PROBABILITY slider.

These two plots are separated because the x-axis is slightly different.  The REWIRE-ONE x-axis is the fraction of edges rewired so far, whereas the REWIRE-ALL x-axis is the probability of rewiring.

The plots for both the clustering coefficient and average path length are normalized by dividing by the values of the initial lattice. The monitors CLUSTERING-COEFFICIENT and AVERAGE-PATH-LENGTH give the actual values.

## THINGS TO NOTICE

Note that for certain ranges of the fraction of nodes rewired, the average path length decreases faster than the clustering coefficient. In fact, there is a range of values for which the average path length is much smaller than clustering coefficient. (Note that the values for average path length and clustering coefficient have been normalized, so that they are more directly comparable.) Networks in that range are considered small worlds.

## THINGS TO TRY

Can you get a small world by repeatedly pressing REWIRE-ONE?

Try plotting the values for different rewiring probabilities and observe the trends of the values for average path length and clustering coefficient.  What is the relationship between rewiring probability and fraction of nodes? In other words, what is the relationship between the rewire-one plot and the rewire-all plot?

Do the trends depend on the number of nodes in the network?

Set NUM-NODES to 80 and then press SETUP. Go to BehaviorSpace and run the VARY-REWIRING-PROBABILITY experiment. Try running the experiment multiple times without clearing the plot (i.e., do not run SETUP again).  What range of rewiring probabilities result in small world networks?

## EXTENDING THE MODEL

Try to see if you can produce the same results if you start with a different type of initial network. Create new BehaviorSpace experiments to compare results.

In a precursor to this model, Watts and Strogatz created an "alpha" model where the rewiring was not based on a global rewiring probability. Instead, the probability that a node got connected to another node depended on how many mutual connections the two nodes had. The extent to which mutual connections mattered was determined by the parameter "alpha." Create the "alpha" model and see if it also can result in small world formation.

## NETLOGO FEATURES

Links are used extensively in this model to model the edges of the network. The model also uses custom link shapes for neighbor's neighbor links.

Lists are used heavily in the procedures that calculates shortest paths.

## RELATED MODELS

See other models in the Networks section of the Models Library, such as Giant Component and Preferential Attachment.

Check out the NW Extension General Examples model to see how similar models might implemented using the built-in NW extension.

## CREDITS AND REFERENCES

This model is adapted from: Duncan J. Watts, Six Degrees: The Science of a Connected Age (W.W. Norton & Company, New York, 2003), pages 83-100.

The work described here was originally published in: DJ Watts and SH Strogatz. Collective dynamics of 'small-world' networks, Nature, 393:440-442 (1998).

The small worlds idea was first made popular by Stanley Milgram's famous experiment (1967) which found that two random US citizens where on average connected by six acquaintances (giving rise to the popular "six degrees of separation" expression): Stanley Milgram. The Small World Problem, Psychology Today, 2: 60-67 (1967).

This experiment was popularized into a game called "six degrees of Kevin Bacon" which you can find more information about here: https://oracleofbacon.org

Thanks to Connor Bain for updating this model in 2020.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2015).  NetLogo Small Worlds model.  http://ccl.northwestern.edu/netlogo/models/SmallWorlds.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2015 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2015 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
setup
repeat 5 [rewire-one]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary-rewiring-probability" repetitions="5" runMetricsEveryStep="false">
    <go>rewire-all</go>
    <timeLimit steps="1"/>
    <exitCondition>rewiring-probability &gt; 1</exitCondition>
    <metric>average-path-length</metric>
    <metric>clustering-coefficient</metric>
    <steppedValueSet variable="rewiring-probability" first="0" step="0.025" last="1"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve
3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve-a
-3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
