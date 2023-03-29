//===================================== 
// Provided under MIT License
// Contributed by: Fredrik (fresidue@gmail.com)
// Mar 2023
//=====================================

/*
  me-utils.scad

  Some locally used modules that are used internally, not really intended as exports, and put here to not clutter up the global namespace

*/

use <maths.scad>


// some transform module shortcuts 
 
module Rz (ang) {
  rotate(a = ang, v = [0, 0, 1])children();
}

module Rx (ang) {
  rotate(a = ang, v = [1, 0, 0])children();
}

module Tx (x) {
  translate(v = [x, 0, 0])children();
}

module Ty (y) {
  translate(v = [0, y, 0])children();
}

module Tz (z) {
  translate(v = [0, 0, z])children();
}

module C(colorStr) {
  if (colorStr == undef) {
    Tx(0)children();
  } else {
    color(colorStr)children();
  }
}

// generators for transform matrices

function isSegStraight (seg) = len(seg) == 1 || len(seg) == 2;


function isSegCurve (seg) = len(seg) == 3 || len(seg) == 4;


function create_translation_mat(x=0, y=0, z=0) = [
  [1, 0, 0, x],
  [0, 1, 0, y],
  [0, 0, 1, z],
  [0, 0, 0, 1]
];

function create_id_mat() = [
  [1, 0, 0, 0],
  [0, 1, 0, 0],
  [0, 0, 1, 0],
  [0, 0, 0, 1]
];

function create_curve_mat(curveR, curveAng, dirAng) =
  let (
    rotQuat = quat([cos(dirAng + 90), sin(dirAng + 90), 0], curveAng),
    rotMat = quat_to_mat4(rotQuat),
    tranMat = create_translation_mat(
      x = curveR * (1 - cos(curveAng)) * cos(dirAng),
      y = curveR * (1 - cos(curveAng)) * sin(dirAng),
      z = curveR * (sin(curveAng))
    ),
    curveMat = mat4_mult_mat4(tranMat, rotMat)
  )
  curveMat;

function create_seg_transform_mat(seg, relPos = 1) =
  let (
    isStraight = isSegStraight(seg),
    trans = (
      isStraight ? 
      create_translation_mat(
        z = seg[0] * relPos
      ) :
      create_curve_mat(
        curveR = seg[0],
        curveAng = seg[1] * relPos,
        dirAng = seg[2]
      )
    )
  )
  trans;

function create_aggregate_transform_mats(aggTransforms, segTransforms, totTransforms) = 
  let(currTot = len(aggTransforms) + len(segTransforms))
  assert(currTot == totTransforms, "Invalid numTot found")
  let (
    prevAggTransform = aggTransforms[len(aggTransforms) - 1],
    currSegTransform = segTransforms[0],
    nextAggTransform = currSegTransform == undef ? undef : mat4_mult_mat4(prevAggTransform, currSegTransform),
    nextAggTransforms = currSegTransform == undef ? undef : [for (aggTransform = aggTransforms) aggTransform, nextAggTransform], // add one (push)  
    nextSegTransforms = (
      len(segTransforms) == 0 ? undef : (
        len(segTransforms) == 1 ? [] : (
          [for (i = [1 : len(segTransforms) - 1]) segTransforms[i]] // remove the first one (shift)
        )
      )
    ),
    // recursive!!
    resAggs = currSegTransform == undef ? aggTransforms : create_aggregate_transform_mats(
      aggTransforms = nextAggTransforms,
      segTransforms = nextSegTransforms,
      totTransforms = totTransforms
    )
  )
  resAggs;

  function create_placement_mat (dirAng, offset) =
    let (
      quatX = quat(axis = [0, 1, 0], angle = 90),
      matRotX = quat_to_mat4(q = quatX),
      quatDir = quat(axis = [0, 0, 1], angle = dirAng),
      matRotDir = quat_to_mat4(q = quatDir),
      matTranX = create_translation_mat(x = offset),
      matTot = mat4_mult_mat4(
        m1 = matRotDir,
        m2 = mat4_mult_mat4(
          m1 = matTranX,
          m2 = matRotX
        )
      )
    )
    matTot;

//
// segment length & addr functions
//

function calcSegLen (seg) =
  let (
    isStraight = isSegStraight(seg),
    segLen = isStraight ? seg[0] : 2 * PI * seg[0] * seg[1] / 360
  )
  segLen;

function calcAggSegLengths (aggLengths, segLengths) =
  let (
    isDone = len(segLengths) == 0,
    prevAggLength = aggLengths[len(aggLengths) - 1],
    currSegLength = isDone ? 0 : segLengths[0],
    nextAggLength = isDone ? 0 : prevAggLength + currSegLength,
    nextAggLengths = isDone ? [] : [for (aggLength = aggLengths) aggLength, nextAggLength], // add one
    nextSegLengths = (isDone || len(segLengths) == 1) ? [] : [for (i = [1 : len(segLengths) - 1]) segLengths[i]], // remove the first one (shift)
    resLengths = isDone ? aggLengths : calcAggSegLengths( // recursive!!
      aggLengths = nextAggLengths,
      segLengths = nextSegLengths
    )
  )
  resLengths;

function normalizeAddr (addr, maxAddr) =
  let (
    addrInd = floor(addr),
    addrRem = addr - addrInd,
    normAddr = addrInd <= 0 ? [0, addr] :
      addrInd >= maxAddr ? [maxAddr - 1, addr - maxAddr + 1] :
      [addrInd, addrRem]
  )
  normAddr;

function getLengthNormalizedAddr (totLength, aggSegLengths, segLengths) =
  let (
    numSegs = len(segLengths),
    filteredAggLengths = [for (i = [0 : numSegs -1]) aggSegLengths[i]],
    shorterLengths = [for (aggLength = filteredAggLengths) if (aggLength < totLength) aggLength],
    addrInd = max(0, len(shorterLengths) - 1),
    addrIndLength = len(shorterLengths) == 0 ? 0 : shorterLengths[len(shorterLengths) - 1],
    lengthRem = totLength - addrIndLength,
    addrRem = lengthRem / segLengths[addrInd],
    normAddr = [addrInd, addrRem]
  )
  normAddr;
