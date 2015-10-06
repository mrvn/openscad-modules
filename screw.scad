/*   screw.scad - generate a rod with thread, i.e. a screw
 *   Copyright (C) 2015  Goswin von Brederlow <goswin-v-b@web.de>
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module Screw(
    length=50,                      // axial length of the threaded rod
    pitch=10,                       // axial distance from crest to crest
    minor_radius=5,                 // radial distance from center to groove
    major_radius=10,                // radial distance from center to crest
    profile=[[0/4, minor_radius],   // profile of the thread
             [1/4, minor_radius],
	     [2/4, major_radius],
	     [3/4, major_radius]],
    lead_in_start=270, 	  	    // degrees for the thread grow to start at bottom
    lead_in_end=630,   	  	    // degrees for the thread grow to end at bottom
    lead_out_start=720,	  	    // degrees (from end) for the thread grow to start at top
    lead_out_end=360,  	  	    // degrees (from end) for the thread grow to end at top
) {
    echo("Screw(", length=length, pitch=pitch, minor_radius=minor_radius,
    	 major_radius=major_radius, profile=profile,")");

    /* profile of thread
     *      |           |
     *      |           |
     * 1.00 |      1.00 |_____
     *       \               |
     *        \              |
     * 0.75    \             |
     *          |  0.66      |
     *          |           /
     * 0.50     |          /
     *         /          /
     *        /    0.33  /
     * 0.25  /          |
     *      |           |
     *      |           |
     * 0.00 |      0.00 |
     */

    // number of facets going around the screw
    facets = max(3,				// Use at least 3 faces
                 ($fn > 0) ? $fn		// If $fn is set then use it
                 : min(2 * PI * major_radius / $fs, 360 / $fa)); // use $fs or $fa
    echo(facets=facets);

    // helper functions
    function scale(r, a, b, z) = (z - a) / (b - a) * r + (1 - (z - a) / (b - a)) * minor_radius;
    function radius(i, r, z) =
        ((z < -pitch + pitch * lead_in_start / 360) || (z > length - pitch * lead_out_end / 360)) ?
	    minor_radius
	  : (z < -pitch + pitch * lead_in_end / 360) ?
	      scale(r, pitch * (lead_in_start / 360 - 1), pitch * (lead_in_end / 360 - 1), z)
	    : (z > length - pitch * lead_out_start / 360) ?
	        scale(r, length - pitch * lead_out_end / 360, length - pitch * lead_out_start / 360, z)
              : r;
    function point(i, r, z, base) = [radius(i, r, base) * cos(i * 360 / facets),
    	     	      	       radius(i, r, base) * sin(i * 360 / facets),
			       z];
    function range(n, i=0, step=1, vec=[]) =
        (n <= 0) ? vec : range(n - 1, i + step, step, concat(vec, [i]));
    function map(indexes, val, i=0, res=[]) =
        (i >= len(indexes)) ? res : map(indexes, val, i + 1, concat(res, [val[indexes[i]]]));

    // polygon for thread
    num_loops = floor(length / pitch + 2);
    num_thread_points = len(profile);
    slices = num_loops * num_thread_points;
    num_points = facets * slices + 1;

    echo(num_loops=num_loops, num_thread_points=num_thread_points, slices=slices);

    function thread_point(i, z) = point(i, profile[z % num_thread_points][1],
    	     		     	        pitch * (floor(z / num_thread_points) + profile[z % num_thread_points][0] + i / facets - 1),
					pitch * (floor(z / num_thread_points) + i / facets - 1));

    function line_points(i, z=0, points=[]) =
        (z >= slices) ? points : line_points(i, z + 1, concat(points, [thread_point(i, z)]));

    function thread_points(i=0, points=[]) =
        (i >= facets) ?
	  concat(points, [thread_point(0, slices)])
	: thread_points(i + 1, concat(points, line_points(i)));

    function point_index(i, z) =
        (i % facets) * slices + z + floor(i / facets) * num_thread_points;
	
    function line_face(i, z) =
        ((i >= facets - 1) && (z >= slices - num_thread_points - 1)) ?
	    [[point_index(i, z),	// last face needs the extra point
    	      point_index(i, z + 1),
	      point_index(i + 1, z)],
             [point_index(i, z + 1),
              num_points - 1,
              point_index(i + 1, z)]]
	    :[[point_index(i, z),	// other faces are fine with overflows
    	       point_index(i, z + 1),
	       point_index(i + 1, z)],
	      [point_index(i, z + 1),
	       point_index(i + 1, z + 1),
	       point_index(i + 1, z)]];

    function line_faces(i=0, z=0, faces=[]) =
        (z >= slices - num_thread_points) ? faces : line_faces(i, z + 1, concat(faces, line_face(i, z)));

    function thread_faces(i=0, faces=[]) =
        (i >= facets) ? faces : thread_faces(i + 1, concat(faces, line_faces(i)));
    
    thread_points = concat(thread_points(), [[0, 0, -pitch], [0, 0, length + pitch]]);
    thread_faces = thread_faces();

    // close the bottom
    function start_face(i) = [num_points,
    	     		      i * slices,
    	     		      (i + 1 >= facets) ? num_thread_points : (i + 1) * slices];
    function start_faces(i=0, faces=thread_faces) =
        (i >= facets) ? faces : start_faces(i + 1, concat(faces, [start_face(i)]));

    plane_start_face = concat([num_points],
    		              range(num_thread_points + 1, i=num_thread_points, step=-1));
    //plane_start_face = [0, 29, 60];

    echo(plane_start_face=plane_start_face);
    echo(map(plane_start_face, thread_points));
        start_faces = concat(start_faces(), [plane_start_face]);

    // close the top
    function end_face(i) = [num_points + 1,
                            (i + 2) * slices - num_thread_points,
			    (i + 1) * slices - num_thread_points];

    function end_faces(i=0, faces=start_faces) =
        (i >= facets - 1) ? faces : end_faces(i + 1, concat(faces, [end_face(i)]));

    last_end_face = [num_points + 1, num_points - 1, facets * slices - num_thread_points];
    plane_end_face = concat([num_points - 1, num_points + 1],
    		            range(num_thread_points, i=slices - num_thread_points));
    end_faces = concat(end_faces(), [last_end_face, plane_end_face]);
    
    // build polyhedron
    rotate([0, 0, -360 * $t])
    polyhedron(points=thread_points, faces=end_faces, convexity = floor(length / pitch) + 3);
}

overlap = 0.123456789;
length=50;
pitch=10;
minor_radius=5;
major_radius = 10;
mid_radius=8;
profile = [[0/3, minor_radius],
           [1/3, minor_radius],
	   [2/3, major_radius],
	   [3/3, major_radius]];
profile2 = [[0/6, minor_radius],
            [1/6, minor_radius],
	    [2/6, major_radius],
	    [3/6, major_radius],
	    [4/6, mid_radius],
	    [5/6, major_radius],
	    [6/6, major_radius]];

Screw(length=50, pitch=10, minor_radius=5, major_radius=10, profile=profile);

translate([20, 0, 0]) {
    difference() {
        Screw(length=length, pitch=pitch, minor_radius=minor_radius, major_radius=major_radius, profile=profile);
	translate([-major_radius - overlap, -major_radius - overlap, -pitch - overlap])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
	translate([-major_radius - overlap, -major_radius - overlap, length])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
    }
}

translate([40, 0, 0]) {
    difference() {
        Screw(length=length, pitch=pitch, minor_radius=minor_radius, major_radius=major_radius, profile=profile, lead_in_start=0, lead_in_end=0, lead_out_start=0, lead_out_end=0);
	translate([-major_radius - overlap, -major_radius - overlap, -pitch - overlap])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
	translate([-major_radius - overlap, -major_radius - overlap, length])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
    }
}

translate([65, 0, 0]) {
    difference() {
        Screw(length=length, pitch=pitch, minor_radius=minor_radius, major_radius=major_radius, profile=profile2, lead_in_start=0, lead_in_end=0, lead_out_start=0, lead_out_end=0);
	*translate([-major_radius - overlap, -major_radius - overlap, -pitch - overlap])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
	*translate([-major_radius - overlap, -major_radius - overlap, length])
	    cube([2 * major_radius + 2 * overlap, 2 * major_radius + 2 * overlap, pitch + overlap]);
    }
}
