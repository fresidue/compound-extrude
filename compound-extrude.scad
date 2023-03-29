//===================================== 
// Provided under MIT License
// Contributed by: Fredrik (fresidue@gmail.com)
// Mar 2023
//=====================================

/*
  compound-extrude.scad

  NOTE: this is the file to "use", but note that it depends       on both <maths.scad> and <me-utils.scad>
 
  compound_extrude provides a tool to create an extended extrusion, with both straight and curved sections, that stack consecutively.

*/

use <maths.scad>
use <me-utils.scad>


/*
  calc_normal_placement_mat

  This function calculates the transform necessary to take an item from the extrusion base (i.e. the origin by construction), to a point "offset" from the center of the extrusion in "dirAng" direction, at any distance along the entire extrusion

  parameters:
    summary - the output from an earlier "summarize_segments" call
    totLength - the target length along the total extrusion for the placement
    offset - the offset from the center (i.e. translated origin) of the placement
    dirAng - the direction axially from the extrustion in which the offset is applied
    segAddr - an optional alternative to totLength, which interprets numbers such as 1.55 to mean "55% along the length of segments[1]"

    returns a 4X4 matrix which can be used with e.g.
      multmatrix(res)cube();
*/
function calc_normal_placement_mat (summary, totLength, offset, dirAng, segAddr=undef, extendEnds = true) = 
  let (
    aggTransforms = summary[0],
    aggSegLengths = summary[2],
    segLengths = summary[3],
    segments = summary[4],
    maxAddr = len(aggTransforms) - 1,
    maxLength = aggSegLengths[len(aggSegLengths) - 1],
    validateAddr = [for (i = [0])
      // basics
      assert(segAddr != undef || totLength != undef, "segAddr or totLength must be included")
      assert(segAddr == undef || segAddr < 0 || segAddr >= 0, "segAddr must be a number if included")
      assert(totLength == undef || totLength < 0 || totLength >= 0, "totLength must be a number if included")
      assert(offset < 0 || offset >= 0, "offset must be a number")
      assert(dirAng < 0 || dirAng >= 0, "dirAng must be a number")
      // input specific
      assert(segAddr == undef || extendEnds || segAddr >= 0, str("segAddr must be >=0 when extendEnds = false. {segAddr = ", segAddr, "}"))
      assert(segAddr == undef || extendEnds || segAddr <= maxAddr, str("segAddr must be <=maxAddr when extendEnds = false {segAddr = ", segAddr, ", maxAddr = ", maxAddr, "}"))
      assert(totLength == undef || extendEnds || totLength >= 0, str("totLength must be >=0 when extendEnds = false. {totLength = ", totLength, "}"))
      assert(totLength == undef || extendEnds || totLength <= maxLength, str("totLength must be <=maxLength when extendEnds = false {totLength = ", totLength, ", maxLength = ", maxLength, "}"))
      true
    ],
    normAddr = segAddr != undef ? normalizeAddr(segAddr, maxAddr) :
      getLengthNormalizedAddr(
        totLength = totLength,
        aggSegLengths = aggSegLengths,
        segLengths = segLengths
      ),
    // the transform matrices
    // 1 - to the base of the segment
    baseMat = aggTransforms[normAddr[0]],
    // 2 - along segment center
    interpMat = create_seg_transform_mat(
      seg = segments[normAddr[0]],
      relPos = normAddr[1]
    ),
    // 3 - offset and radial orientation
    placementMat = create_placement_mat(
      dirAng = dirAng, 
      offset = offset
    ),
    // combine
    total_mat = mat4_mult_mat4(baseMat, (
      mat4_mult_mat4(interpMat, placementMat)
    ))
  )
  total_mat;

/*
  summarize_segments

  This function creates a list that summarizes/characterizes a segment list (note that the input segment list IS in fact included in the output as summary[4])

  parameters:
    segments - a list of straight and curved segments
      For a straight segment [len, color] where color is optional (i.e. len(straightSeg == 1 || len(straightSeg) == 2)
        len - number >= 0
        color - (optional) color string
      For a curved segment [curveR, curveAng, dirAng, color] where color is optional (i.e. len(curvedSeg) == 3 || len(curvedSeg) == 4)
        curveR - number > 0, the radius of curvature of the segment
        curveAng - number, the angle in degrees swept out by the segment
        dirAng - number, the angle in toward which the segments curves (default for dirAng = 0 is along the x-axis)

  returns:
    summary - a list with 5 elements
      [0] - a list of aggTransforms to the beginnings and ends of each segment (the matrix to the beginning of segment[i] is aggTransforms[i], and the matrix to the end of segment[i] is aggTransforms[i + 1]), meaning that len(aggTransf)
      [1] - a list of individual segment transforms the origin to the end of the segment, given that segment starts at the origin (these can be multiplied together to get the aggTransforms)
      [2] - aggSegLengths, a list of the aggregated lengths before and after each segment (like aggTransforms, there len(aggSegLengths) = len(segments) + 1)
      [3] - segLengths, a list of the lengths of each segment
      [4] - the input segments themseleves (dirty but useful)
    returns a 4X4 matrix which can be used with e.g.
      multmatrix(res)cube();
*/

function summarize_segments (segments) =
  let (
    numSegs = len(segments),
    validation = [for (i = [0 : numSegs - 1])
      let (
        segment = segments[i],
        isCurve = isSegCurve(segment),
        isStraight = isSegStraight(segment)
      )
      assert(isCurve || isStraight, str("Invalid segment length. Must be either 1 (or 2 with optional color), which provide [length, color] for a straight segment; or 3 (or 4 with optional color), which are [curveR, curveAng, dirAng] for a curved segment), but we found ", len(segment)))
      assert(!isStraight || segment[0] > 0, str("Invalid straight segment length found at index ", i, " which is negative"))
      assert(!isStraight || segment[1] == undef || str(segment[1])==segment[1], str("Invalid straight segment color found at index ", i, " which must be a string WHEN included"))

      assert(!isCurve || segment[0] > 0, str("Invalid curved segment curveR (i.e. segment[0]) found at index ", i, " which is negative"))
      assert(!isCurve || segment[1] >= 0  || segment[1] < 0, str("Invalid curved segment curveAng (i.e. segment[1]) found at index ", i, " which must be a number"))
      assert(!isCurve || segment[2] >= 0  || segment[2] < 0, str("Invalid curved segment dirAng (i.e. segment[2]) found at index ", i, " which must be a number"))
      assert(!isCurve || segment[3] == undef || str(segment[3])==segment[3], str("Invalid curved segment color found at index ", i, " which must be a string WHEN included"))
      true
    ],
    segTransforms = [for (segInd = [0 : numSegs - 1]) create_seg_transform_mat(segments[segInd])],
    initAggTransforms = [create_id_mat()],
    aggTransforms = create_aggregate_transform_mats(
      aggTransforms = initAggTransforms,
      segTransforms = [for (segTransform = segTransforms) segTransform], // copy as gets mutated
      totTransforms = len(segTransforms) + 1
    ),
    segLengths = [for (segment = segments) calcSegLen(segment)],
    aggLengths = calcAggSegLengths([0], segLengths),
    combinedTransforms = [
      aggTransforms,
      segTransforms,
      aggLengths,
      segLengths,
      segments,
    ]
  )
  combinedTransforms;

/*
  compound_extrude

  This function generates the extrusion from a list of segments that define the extruded segments, which is applied to a 2D surface. This surface can either be supplied directly with a list of "points" which are used directly to create a polygon (e.g. "compound_extrude(points, segments);", or, if no points are supplied, it will be applied as a transform to a 2D shape (e.g. "compound_extrude(segments)circle();")



  (note that "paths" and "convexity" are other polygon parameters that can optionally be supplied) 

  This function creates a list that summarizes/characterizes a segment list (note that the input segment list IS in fact included in the output as summary[4])

  parameters:
    segments - a list of straight and curved segments
      For a straight segment [len, color] where color is optional (i.e. len(straightSeg == 1 || len(straightSeg) == 2)
        len - number >= 0
        color - (optional) color string
      For a curved segment [curveR, curveAng, dirAng, color] where color is optional (i.e. len(curvedSeg) == 3 || len(curvedSeg) == 4)
        curveR - number > 0, the radius of curvature of the segment
        curveAng - number, the angle in degrees swept out by the segment
        dirAng - number, the angle in toward which the segments curves (default for dirAng = 0 is along the x-axis)
    
    points - (optional) a list of [x, y] points that are used to define a 2D polygon
    paths - (optional even with points) option used by polygon (see official docs)
    convexity - (optional even with points) option used by polygon (see official docs)

    summary - The first thing that compound_extrude does is to generate a summary with "summarize_segments" which defines all the transformations used. This summary can be generated separately by and inserted directly as a paramter here, in which case "compound_extrude" will use the supplied summary aggTransforms blindly, and not recalculate any of it. Note that any modifications applied to the summary[0] = aggTransforms will manifest in the resultant extrusion.

*/

module compound_extrude (segments, points = undef, paths = undef, summary = undef, convexity=10) {
  module polly () {
    polygon(points = points, paths = paths, convexity = convexity);
  }
  module straightTransform (aggTransform, segLength, segColor) {
    C(segColor)
    multmatrix(aggTransform)
    linear_extrude(height = segLength, convexity = convexity)
    children();
  };
  module curveTransform (aggTransform, curveR, curveAng, dirAng, segColor) {
    C(segColor)
    multmatrix(aggTransform)
    Rz(180 + dirAng)
    Tx(-curveR)
    Rx(90)
    rotate_extrude(angle = curveAng, convexity = convexity)
    Tx(curveR)
    Rz(180 + dirAng)
    children();
  };

  numSegs = len(segments);
  actualSummary = summary != undef ? summary :
    summarize_segments(segments);
  aggTransforms = actualSummary[0];

  for (segInd = [0 : numSegs - 1]) {
    seg = segments[segInd];
    isStraight = isSegStraight(seg);
    if (isStraight) {
      segLength = seg[0];
      segColor = seg[1];
      // the straight stuff
      if (points == undef) {
        straightTransform(
          aggTransform = aggTransforms[segInd],
          segLength = segLength,
          segColor = segColor
        )
        children();
      } else {
        straightTransform(
          aggTransform = aggTransforms[segInd],
          segLength = segLength,
          segColor = segColor
        )
        polly();
      }
    } else {
      curveR = seg[0];
      curveAng = seg[1];
      dirAng = seg[2];
      segColor = seg[3];
      // the curved stuff
      if (points == undef) {
        curveTransform(
          aggTransform = aggTransforms[segInd],
          curveR = curveR,
          curveAng = curveAng,
          dirAng = dirAng,
          segColor = segColor
        )
        children();
      } else {
        curveTransform(
          aggTransform = aggTransforms[segInd],
          curveR = curveR,
          curveAng = curveAng,
          dirAng = dirAng,
          segColor = segColor
        )
        polly();
      }
    }
  }
}
