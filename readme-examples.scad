
use <compound-extrude.scad>
use <maths.scad> // matrix mult


module Tx (x) {
  translate(v = [x, 0, 0])children();
};

module Ty (y) {
  translate(v = [0, y, 0])children();
};

module Tz (z) {
  translate(v = [0, 0, z])children();
};

module wart () {
  Tz(z = 40)
  union() {
    color("yellow")
    difference() {
      sphere(r = 40);
      Tz(z = 100)cube(size = 200, center = true);
    };
    color("black")sphere(r = 15);
    Tz(z = 20)color("white")sphere(r = 10);
  };
}
// wart();


function getTranslationArr (index) = 
  let (
    offset = 500,
    xInd = index % 3,
    yIind = floor(index / 3),
    pos = [xInd * offset, yIind * offset, 0]
  )
  pos;

// the segment configuration that will be used in these examples
SEGMENTS = [
  // straight segment with [length = 200]
  [200],
  // curved segment with [curveR = 100, curveAng = 90, dirAng = 0]
  [100, 90, 0],
  // curved segment with [curveR = 100, curveAng = 90, dirAng = -90]
  [100, 90, -90]
];


module example1 (index) {
  translate(v = getTranslationArr(index = index)) 
  color("red")
  compound_extrude(segments = SEGMENTS)
  circle(r = 50);
}
// example1(index = 1);


// generate the summary
summary = summarize_segments(segments = SEGMENTS);

module example2 (index) {
  translate(v = getTranslationArr(index = index))
  union() {
    color("red")
    compound_extrude(segments = SEGMENTS)
    circle(r = 50);
    multmatrix(m = calc_normal_placement_mat(
      summary = summary,
      totLength = 130,
      offset = 50,
      dirAng = 230
    ))
    wart(); 
    multmatrix(m = calc_normal_placement_mat(
      summary = summary,
      totLength = 360,
      offset = 50,
      dirAng = 170
    ))
    wart(); 
  };
}
// example2(index = 2);


module example3 (index) {

  zTran = 50;
  zTranMat = [
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, zTran],
    [0, 0, 0, 1],
  ];
  modifiedSummary = [
    [
      summary[0][0],
      mat4_mult_mat4(zTranMat, summary[0][1]),
      mat4_mult_mat4(zTranMat, summary[0][2]),
      mat4_mult_mat4(zTranMat, summary[0][3])
    ],
    summary[1], summary[2], summary[3], summary[4],
  ];

  // translate(v = getTranslationArr(index = index))
  union() {
    color("red")
    compound_extrude(
      segments = SEGMENTS,
      summary = modifiedSummary
    )
    circle(r = 50);
    multmatrix(m = calc_normal_placement_mat(
      summary = modifiedSummary,
      totLength = 130,
      offset = 50,
      dirAng = 230
    ))
    wart(); 
    multmatrix(m = calc_normal_placement_mat(
      summary = modifiedSummary,
      totLength = 360,
      offset = 50,
      dirAng = 170
    ))
    wart(); 
  };
}
example3(index = 3);


