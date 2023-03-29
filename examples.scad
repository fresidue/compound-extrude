//===================================== 
// Provided under MIT License
// Contributed by: Fredrik (fresidue@gmail.com)
// Mar 2023
//=====================================

/*
  examples.scad
 
  This just shows some example usages of compound_extrude
*/

use <maths.scad>
use <me-utils.scad>
use <compound-extrude.scad>


////////
//
// utils and constants
//
////////


function star_points (numPoints, outerR, innerR) =
  let (totPts = 2 * numPoints)
  let (diffAng = 360 / totPts)
  let (points = [
    for (ind = [totPts : -1 : 0]) [
      (ind % 2 == 0 ? outerR : innerR) * cos(ind * diffAng),
      (ind % 2 == 0 ? outerR : innerR) * sin(ind * diffAng),
    ],
  ])
  points;

function biased_star_points (numPoints, outerR, innerR) =
  let (starPoints = star_points(numPoints, outerR, innerR))
  let (points = [
    for (point = starPoints) point,
    [0, 50], [200, 0], [0, -50],
  ])
  points;

// used in a later example
sidenodeLayers = [
  [100, "yellow", 0],
  [50, "black", 20],
  [30, "red", 30],
  [15, "white", 40]
];
module sidenode () {
  Tz(z = 0.9 * sidenodeLayers[0][0])
  for (layer = sidenodeLayers) {
    Tz(z = layer[2])
    color(layer[1])
    difference() {
      sphere(r = layer[0]);
      Tz(z = 1.5 * layer[0])
      cube(3 * layer[0], center=true);        
    };

  }
}

// The common extrusion geometry used by all examples
TEST_SEGMENTS = [
  [500],
  [320, 180, 0],
  [300],
  [100],
  [300, 180, 315],
  [160],
  [250, 130, -16],
  [333]
];

////////
//
// Examples
//
////////

////////
// 0
////////
//
// If "points" are included the module will create a polygon and apply
//
color("red")
compound_extrude(
  points = biased_star_points(6, 100, 20),
  segments = TEST_SEGMENTS
);


////////
// 1
////////
//
// "points" and "paths" get directly applied to the polygon that gets extruded
//
Tx(1000)
color("blue")
compound_extrude(
  points = [[-50, 0], [50, 50], [50, -50], [50, 0], [-50, 50], [-50, -50]],
  paths = [[0, 1, 2, 0], [3, 4, 5, 3]],
  segments = TEST_SEGMENTS
);


////////
// 2
////////
//
// if NO "points" are included, compound_extrude acts on "children()"
//
Tx(2000)
compound_extrude(
  segments = TEST_SEGMENTS
)
circle(r = 50);


////////
// 3
////////
//
// difference seems to work, and put in 2 layers
//
color("teal")
Tx(3000)
compound_extrude(
  segments = TEST_SEGMENTS
)
difference() {
  circle(r = 80);
  circle(r = 70);
};
color("gray")
Tx(3000)
compound_extrude(
  segments = TEST_SEGMENTS
)
difference() {
  circle(r = 70);
  circle(r = 60);
};


////////
// 4
////////
//
// difference with offset to inner and outer circle so thy intersect
//
Tx(4000)
color("beige")
compound_extrude(
  segments = TEST_SEGMENTS
)
difference() {
  circle(r = 80);
  Tx(-18)
  circle(r = 75);
};


////////
// 5
////////
//
// you can extract the summary, which includes relevant computed values (so they do not have to be recalculated)
//
summary = summarize_segments(segments = TEST_SEGMENTS);
// if you have already calculated the summary, you can inject it directly into "compound_extrude", which will use it blindly, and thus not recalculate it
color("pink")
Tx(5000)
compound_extrude(
  summary=summary,
  segments=TEST_SEGMENTS
)
circle(r = 30);


////////
// 6
////////
//
// Segments can include an optional "color" string
//
colors = ["red", "blue", undef, "green", "black", "yellow", "brown"];
coloredSegments = [for (i= [0: 6])
  let (
    segment = TEST_SEGMENTS[i],
    coloredSegment = [for (arg = segment) arg, colors[i]]
  )
  coloredSegment
];
echo("coloredSegments", coloredSegments);
// coloredSegments = [for (segment in TEST_SEGMENTS) [for (arg in segment) arg, ]]
Ty(2000)
compound_extrude(
  segments = coloredSegments
)
circle(r = 50);


////////
// 7
////////
//
// We can also use the summary directly to place other objects along the extrusion in a well-defined manner
//
module tran33888 () {
  Ty(2000)
  Tx(1000)
  children();
} 
fewPlacements = [
  calc_normal_placement_mat(
    summary = summary,
    totLength = 200,
    offset = 30,
    dirAng = 12938123
  ),
  calc_normal_placement_mat(
    summary = summary,
    totLength = 1200,
    offset = 30,
    dirAng = 12938184837723423
  ),
  calc_normal_placement_mat(
    summary = summary,
    totLength = 3000,
    offset = 30,
    dirAng = 89123419234
  )
];
color("maroon")
tran33888()
compound_extrude(
  summary=summary,
  segments=TEST_SEGMENTS
)
circle(r = 30);
for (placement = fewPlacements) {
  tran33888()
  multmatrix(m = placement) 
  sidenode();
}


////////
// 8
////////
//
// if you want to introduce a gap into one of the pipes for some reason, this can be done by altering the summary[0] == "aggTransforms"
//
originalAggTransforms = summary[0];
alteredAggTransforms = [
  // keep the first 3 as before
  for (i = [0 : len(originalAggTransforms) - 1]) if(i < 3) originalAggTransforms[i],
  // translate the remainder with a Tz(-300)
  for (i = [0 : len(originalAggTransforms) - 1]) if(i >= 3)
    mat4_mult_mat4(create_translation_mat(z = -300), originalAggTransforms[i])
];
alteredSummary = [
  alteredAggTransforms, // aggTransforms (cumulative segTransforms)
  summary[1], // segTransforms (transform to end of segment when segment begins at origin)
  summary[2], // aggLengths (aggregated segLengths)
  summary[3], // segLengths (length of each segment along the origins arc)
  summary[4], // a copy of segments that is USED by "calc_normal_placement_mat" but NOT by "compound_extrude"
];
color("purple")
Ty(2000)
Tx(2000)
compound_extrude(
  summary=alteredSummary,
  segments=TEST_SEGMENTS
)
circle(r = 30);


////////
// 9
////////
//
// The calculated transforms are based off of the summary.aggTransforms, so any modifications to the aggTransforms are preserved by the placments
//
steps = 500;
stepLen = 10;
placements = [for (i = [0: steps]) calc_normal_placement_mat(
  summary = alteredSummary,
  // totLength = 5000,
  totLength = i * stepLen - 800,
  offset = 40,
  dirAng = i * 20
)];

// Do an overlay of a simple circle pipe with the add-ons
module tran22277 () {
  Ty(2000)
  Tx(3000)
  children();
};

color("purple")
tran22277()
// the main shape
compound_extrude(
  summary=alteredSummary,
  segments=TEST_SEGMENTS
)
circle(r = 30);
// and all the little boxes using the placments
for (placement = placements) {
  color("green")
  tran22277()
  multmatrix(m = placement) 
  cube(size = 20, center = false);
}
