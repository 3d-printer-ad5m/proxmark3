// =====================================================================
//  CEVA promo forklift - desk model, 200 pcs, Bambu Lab H2C
//  Client: CEVA Logistics (IMEA) / Producer: live3d.ae
//
//  Units: mm. Assembly frame: X = forward (towards forks), Y = left,
//  Z = up, ground at z = 0.
//
//  Render one print part (already in its print orientation):
//    openscad -D 'part="body_white"' -o body_white.stl ceva_forklift.scad
//  Parts: body_white body_black body_red
//         mast_black
//         wheelF_black wheelF_white wheelR_black wheelR_white
//         load_kraft load_navy load_red
//         assembly (coloured preview of the whole model)
//
//  Kit per forklift: 1x body, 1x mast, 2x wheelF, 2x wheelR, 1x load.
//  Wheel parts are exported once; print 2 of each (they are symmetric).
//
//  !! The CEVA logo below is a PLACEHOLDER built from a system font.
//  !! Replace logo_navy_2d()/logo_red_2d() with the official vector
//  !! artwork (import("ceva_logo_navy.svg") etc.) before production.
// =====================================================================

part = "assembly";

$fn = 64;
eps = 0.01;
inlay = 1.0;          // depth of colour inlays on the body
logo_depth = 0.8;     // depth of logo inlays on the box

// ---------------- body ----------------
clear    = 4;         // ground clearance of the body underside
deck_z   = 27;        // top of the lower body / hood
body_x1  = 60;        // body spans x = 0 .. body_x1
body_hw  = 24;        // half width of the body
rear_r   = 6;         // plan-view radius of the rear corners

cw_x1    = 17;        // counterweight x = 0 .. cw_x1
cw_top   = 36;
cw_r     = 8;         // rounded top-rear edge

cab_x0 = 20; cab_x1 = 50; cab_hw = 21; cab_top = 54; cab_r = 3;
roof_lip = 2; roof_top = 58;

// ---------------- wheels ----------------
fw_x = 45; fw_r = 11; fw_w = 9;   // front (drive) wheels
rw_x = 14; rw_r = 9;  rw_w = 8;   // rear (steer) wheels
wheel_out = 24.5;                 // |y| of the wheel outer face
arch_in   = 15;                   // |y| of the wheel pocket inner wall
arch_gap  = 1.5;                  // radial clearance tyre <-> fender
peg_d = 3.0; hole_d = 3.2; hole_depth = 6;   // CA glue on assembly

// ---------------- mast / forks ----------------
mast_x0 = 62; mast_x1 = 66;       // outer rails
mast_hw = 17; rail_w = 4; mast_top = 70;
tongue_x0 = 54; tongue_hw = 6; tongue_h = 18;   // mounts into the body
fit = 0.2;                        // clearance for slip fits
carr_x1 = 69; carr_h = 16;        // fork carriage plate
fork_y = 9; fork_w = 5; fork_t = 2; fork_len = 31.5;
fork_x0 = carr_x1; fork_x1 = fork_x0 + fork_len;

// ---------------- load: pallet + box ----------------
pal_x0 = 71.5; pal_len = 36; pal_hw = 19;
pal_stringer_h = 4; pal_deck_t = 2;
pal_top = pal_stringer_h + pal_deck_t;
box_x0 = 73.5; box_len = 32; box_hw = 16; box_h = 30;
box_top = pal_top + box_h;

// ---------------- colours (preview only) ----------------
C_WHITE = "#f4f4f2"; C_BLACK = "#222222"; C_RED = "#d7282f";
C_NAVY  = "#1d2a5c"; C_KRAFT = "#c9a36b";

// =====================================================================
//  helpers
// =====================================================================
module rrect(x0, x1, hw, r) {            // 2D rounded rectangle
    hull() for (x = [x0 + r, x1 - r], y = [-hw + r, hw - r])
        translate([x, y]) circle(r);
}
module rrect_rc(x0, x1, hw, r_rear, r_front) {  // different rear/front radii
    hull() {
        for (y = [-hw + r_rear, hw - r_rear]) translate([x0 + r_rear, y]) circle(r_rear);
        for (y = [-hw + r_front, hw - r_front]) translate([x1 - r_front, y]) circle(r_front);
    }
}
module rrect_yz(y0, y1, z0, z1, r) {     // rounded rect drawn in the YZ plane (2D: u=y, v=z)
    hull() for (u = [y0 + r, y1 - r], v = [z0 + r, z1 - r])
        translate([u, v]) circle(r, $fn = 24);
}
// place a 2D shape drawn in (u,v) on a vertical plane x = const, u -> +y, v -> +z
module on_x_plane(x) { multmatrix([[0,0,1,x],[1,0,0,0],[0,1,0,0],[0,0,0,1]]) children(); }
// place a 2D shape on a plane y = const, u -> +x, v -> +z
module on_y_plane(y) { multmatrix([[1,0,0,0],[0,0,1,y],[0,1,0,0],[0,0,0,1]]) children(); }
// horizontal teardrop hole along Y (prints without support)
module teardrop_y(d, y0, y1) {
    translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0)
        hull() { circle(d / 2, $fn = 32); rotate(45) square(d / 2 * 0.99); }
}

// =====================================================================
//  BODY  (white, printed upright on its flat underside)
// =====================================================================
module body_plan() { rrect_rc(0, body_x1, body_hw, rear_r, 1.5); }

module body_raw() {
    // lower body with 1 mm chamfer round the hood top edge
    hull() {
        translate([0, 0, clear]) linear_extrude(deck_z - clear - 1) body_plan();
        translate([0, 0, deck_z - 1]) linear_extrude(1) offset(delta = -1) body_plan();
    }
    // counterweight: rounded top-rear edge, clipped to the rounded plan
    intersection() {
        rotate([90, 0, 0]) linear_extrude(2 * body_hw + 2, center = true)
            hull() {
                translate([0, clear]) square([cw_x1, cw_top - cw_r - clear]);
                translate([cw_r, cw_top - cw_r]) circle(cw_r);
                translate([cw_x1 - 1, cw_top - 1]) square([1, 1]);
            }
        linear_extrude(cw_top + 1) body_plan();
    }
    // closed cabin
    translate([0, 0, deck_z - eps]) linear_extrude(cab_top - deck_z + eps)
        rrect(cab_x0, cab_x1, cab_hw, cab_r);
    // roof: 45 deg lip underneath (no supports), 1 mm top chamfer
    hull() {
        translate([0, 0, cab_top]) linear_extrude(eps) rrect(cab_x0, cab_x1, cab_hw, cab_r);
        translate([0, 0, cab_top + roof_lip]) linear_extrude(roof_top - cab_top - roof_lip - 1)
            rrect(cab_x0 - roof_lip, cab_x1 + roof_lip, cab_hw + roof_lip, cab_r + roof_lip);
        translate([0, 0, roof_top - 1]) linear_extrude(1)
            rrect(cab_x0 - roof_lip + 1, cab_x1 + roof_lip - 1, cab_hw + roof_lip - 1, cab_r + roof_lip - 1);
    }
    // beacon (base + dome), coloured by body_red / body_black
    translate([24, 0, roof_top - eps]) {
        cylinder(d = 8, h = 1.5 + eps);
        translate([0, 0, 1.5]) cylinder(d = 5, h = 2);
        translate([0, 0, 3.5]) sphere(d = 5);
    }
}

// wheel pocket (arch) cut into each side; 45 deg chamfers + short bridge
module arch_2d(wx, wz, r) {
    a = r + arch_gap;  b = 0.45 * a;
    polygon([[wx - a, -1], [wx + a, -1], [wx + a, wz + b], [wx + b, wz + a],
             [wx - b, wz + a], [wx - a, wz + b]]);
}
module wheel_pockets() {
    for (s = [-1, 1]) {
        y0 = s > 0 ? arch_in : -body_hw - 1;
        translate([0, y0 + (body_hw + 1 - arch_in), 0]) rotate([90, 0, 0])
            linear_extrude(body_hw + 1 - arch_in) {
                arch_2d(fw_x, fw_r, fw_r);
                arch_2d(rw_x, rw_r, rw_r);
            }
    }
}
module axle_holes() {
    for (w = [[fw_x, fw_r], [rw_x, rw_r]]) {
        translate([w[0], 0, w[1]]) {
            teardrop_y(hole_d, arch_in - hole_depth, arch_in + 1);
            teardrop_y(hole_d, -arch_in - 1, -arch_in + hole_depth);
        }
    }
}
module mast_socket() {   // open at the bottom and the front, roof is a short bridge
    translate([tongue_x0 - fit, -tongue_hw - fit, -1])
        cube([body_x1 - tongue_x0 + fit + 1, 2 * (tongue_hw + fit), tongue_h + fit + 1]);
}

module body_shape() {
    difference() { body_raw(); wheel_pockets(); axle_holes(); mast_socket(); }
}

// colour regions (intersected with the body so they are exact inlays)
module body_black_regions() {
    // front window
    translate([cab_x1 - inlay, 0, 0]) on_x_plane(0) linear_extrude(2 * inlay)
        rrect_yz(-17.5, 17.5, 31, 51, 2);
    // rear window
    translate([cab_x0 - inlay, 0, 0]) on_x_plane(0) linear_extrude(2 * inlay)
        rrect_yz(-17.5, 17.5, 37, 51, 2);
    // side windows (two panes each side)
    for (s = [-1, 1]) translate([0, s * cab_hw - inlay, 0]) on_y_plane(0)
        linear_extrude(2 * inlay) { rrect_yz(23, 34, 33, 51, 2); rrect_yz(36, 47, 33, 51, 2); }
    // boarding steps
    for (s = [-1, 1]) translate([0, s * body_hw - inlay, 0]) on_y_plane(0)
        linear_extrude(2 * inlay) rrect_yz(26, 31, 12, 16, 0.6);
    // rear grille slats on the counterweight
    for (z = [13, 16, 19]) translate([-inlay, -8, z]) cube([2 * inlay, 16, 1.4]);
    // beacon base
    translate([24, 0, roof_top - eps]) cylinder(d = 8.2, h = 1.5 + eps);
}
module body_red_regions() {
    // tail lights
    for (s = [-1, 1]) translate([-inlay, s * 14 - 3, 22]) cube([2 * inlay, 6, 4]);
    // beacon dome
    translate([24, 0, roof_top + 1.5]) cylinder(d = 6, h = 10);
}

module body_white() { difference() { body_shape(); body_black_regions(); body_red_regions(); } }
module body_black() { intersection() { body_shape(); body_black_regions(); } }
module body_red()   { intersection() { body_shape(); difference() { body_red_regions(); body_black_regions(); } } }

// =====================================================================
//  MAST + CARRIAGE + FORKS  (black, printed upright, no supports)
// =====================================================================
module mast() {
    // mounting tongue (goes into the body socket) + lower cross member
    translate([tongue_x0, -tongue_hw, 0]) cube([mast_x0 - tongue_x0 + eps, 2 * tongue_hw, tongue_h]);
    translate([mast_x0, -mast_hw, 0]) cube([mast_x1 - mast_x0, 2 * mast_hw, tongue_h]);
    // outer rails
    for (s = [-1, 1]) translate([mast_x0, s > 0 ? mast_hw - rail_w : -mast_hw, 0])
        cube([mast_x1 - mast_x0, rail_w, mast_top]);
    // inner (telescopic) rails
    for (s = [-1, 1]) translate([mast_x0 + 0.5, s > 0 ? mast_hw - rail_w - 2.5 : -mast_hw + rail_w, 0])
        cube([mast_x1 - mast_x0 - 1, 2.5, mast_top - 4]);
    // cross members
    translate([mast_x0, -mast_hw, 44]) cube([mast_x1 - mast_x0, 2 * mast_hw, 3]);
    translate([mast_x0, -mast_hw, mast_top - 4]) cube([mast_x1 - mast_x0, 2 * mast_hw, 4]);
    // lift cylinder
    translate([mast_x0 + 1.7, 0, 0]) cylinder(d = 3.6, h = 44 + eps, $fn = 32);
    // carriage plate with two ribs
    translate([mast_x1 - eps, -mast_hw, 0]) cube([carr_x1 - mast_x1 + eps, 2 * mast_hw, carr_h]);
    // load backrest (bars + top rail)
    for (y = [-mast_hw, -7, 5, mast_hw - 2]) translate([mast_x1, y, 0]) cube([2, 2, 34]);
    translate([mast_x1, -mast_hw, 32]) cube([2, 2 * mast_hw, 2]);
    translate([mast_x1, -mast_hw, 24]) cube([2, 2 * mast_hw, 1.6]);
    // forks: shank with hook + tapered tine
    for (s = [-1, 1]) translate([0, s * fork_y, 0]) {
        translate([fork_x0 - eps, -fork_w / 2, 0]) cube([2.5, fork_w, carr_h + 2]);
        translate([mast_x1, -fork_w / 2, carr_h]) cube([fork_x0 - mast_x1 + 2.5, fork_w, 2]);
        hull() {
            translate([fork_x0, -fork_w / 2, 0]) cube([fork_len - 7, fork_w, fork_t]);
            translate([fork_x1 - 1, -fork_w / 2 + 0.6, 0]) cube([1, fork_w - 1.2, 0.8]);
        }
    }
}

// =====================================================================
//  WHEELS  (black tyre + white hub, printed outer face down, peg up)
// =====================================================================
module wheel_shape(r, w, peg_len) {
    difference() {
        hull() {
            cylinder(r = r - 0.6, h = eps);
            translate([0, 0, 0.6]) cylinder(r = r, h = w - 1.2);
            translate([0, 0, w - eps]) cylinder(r = r - 0.6, h = eps);
        }
        // tread
        n = round(2 * PI * r / 3.2);
        for (i = [0 : n - 1]) rotate(i * 360 / n)
            translate([r - 0.7, -0.6, -1]) cube([2, 1.2, w + 2]);
    }
    // axle peg with tip chamfer
    translate([0, 0, w - eps]) cylinder(d = peg_d, h = peg_len - 0.4 + eps, $fn = 32);
    translate([0, 0, w + peg_len - 0.4]) cylinder(d1 = peg_d, d2 = peg_d - 0.8, h = 0.4, $fn = 32);
}
module hub_region(r) {           // first 3 layers @0.2
    difference() {
        translate([0, 0, -1]) cylinder(r = 0.58 * r, h = 1.6);
        translate([0, 0, -2]) cylinder(r = 0.2 * r, h = 4);
    }
}
function peg_len(r, w) = (wheel_out - w) - (arch_in - hole_depth) - 0.5;
module wheel_black(r, w) { difference() { wheel_shape(r, w, peg_len(r, w)); hub_region(r); } }
module wheel_white(r, w) { intersection() { wheel_shape(r, w, peg_len(r, w)); hub_region(r); } }

// =====================================================================
//  LOAD: navy plastic pallet + kraft box with CEVA logo
//  (printed upright; slides onto the forks)
// =====================================================================
module pallet() {
    for (y = [-pal_hw, -2, pal_hw - 4]) translate([pal_x0, y, 0]) cube([pal_len, 4, pal_stringer_h + eps]);
    for (i = [0 : 4]) translate([pal_x0 + i * 7.5, -pal_hw, pal_stringer_h]) cube([6, 2 * pal_hw, pal_deck_t]);
    // front bottom deck board: stiffens the base and gives bed adhesion
    translate([pal_x0 + pal_len - 6, -pal_hw, 0]) cube([6, 2 * pal_hw, 1.2]);
    // hidden guide ribs: centre the pallet on the tines (0.25 mm side play)
    for (s = [-1, 1], yr = [fork_y - fork_w / 2 - 0.25 - 1.2, fork_y + fork_w / 2 + 0.25])
        translate([pal_x0 + 3, s > 0 ? yr : -yr - 1.2, 0]) cube([pal_len - 6, 1.2, pal_stringer_h + eps]);
}
module box_raw() {
    translate([0, 0, pal_top - eps]) hull() {
        linear_extrude(box_h - 0.6 + eps) rrect(box_x0, box_x0 + box_len, box_hw, 0.8);
        translate([0, 0, box_h - 0.6]) linear_extrude(0.6) offset(delta = -0.6) rrect(box_x0, box_x0 + box_len, box_hw, 0.8);
    }
}

// ---- logo placeholder, 2D, centred on origin, ~27 x 6.6 mm ----
logo_h   = 6.6;                 // x-height of the lettering
cev_w    = logo_h * 2.92;       // "cev" in Liberation Sans Bold keeps its aspect
chev_w   = logo_h * 0.95;       // red chevron
chev_t   = 1.8;                 // chevron stroke (>= 4 lines of a 0.4 nozzle)
logo_gap = 1.0;
logo_w   = cev_w + logo_gap + chev_w;
module logo_navy_2d() {    // "cev"
    translate([-logo_w / 2, -logo_h / 2])
        resize([cev_w, logo_h]) text("cev", size = 10, font = "Liberation Sans:style=Bold", valign = "baseline");
}
module logo_red_2d() {     // red chevron standing in for the "A"
    w = chev_w; h = logo_h;
    alpha = atan((w / 2) / h);              // half angle at the apex
    dx = chev_t / cos(alpha);               // horizontal leg width
    dz = chev_t / sin(alpha);               // apex drop of the inner edge
    translate([logo_w / 2 - w, -logo_h / 2]) difference() {
        polygon([[0, 0], [w / 2, h], [w, 0]]);
        polygon([[dx - tan(alpha), -1], [w / 2, h - dz], [w - dx + tan(alpha), -1]]);
    }
}
// logo on the 4 visible faces (front, both sides, top)
module logo_faces(depth) {
    xc = box_x0 + box_len / 2; zc = pal_top + box_h / 2;
    // front face (x = box_x0 + box_len), reads along +y
    multmatrix([[0,0,1,box_x0 + box_len],[1,0,0,0],[0,1,0,zc],[0,0,0,1]])
        translate([0, 0, -depth]) linear_extrude(depth + 1) children();
    // left face (y = +box_hw), viewer at +y reads along -x
    multmatrix([[-1,0,0,xc],[0,0,1,box_hw],[0,1,0,zc],[0,0,0,1]])
        translate([0, 0, -depth]) linear_extrude(depth + 1) children();
    // right face (y = -box_hw), reads along +x
    multmatrix([[1,0,0,xc],[0,0,-1,-box_hw],[0,1,0,zc],[0,0,0,1]])
        translate([0, 0, -depth]) linear_extrude(depth + 1) children();
    // top face, reads from the front (same direction as the front logo)
    multmatrix([[0,-1,0,xc],[1,0,0,0],[0,0,1,box_top],[0,0,0,1]])
        translate([0, 0, -depth]) linear_extrude(depth + 1) children();
}
module load_kraft() { difference() { box_raw(); logo_faces(logo_depth) { logo_navy_2d(); logo_red_2d(); } } }
module load_navy()  { pallet(); intersection() { box_raw(); logo_faces(logo_depth) logo_navy_2d(); } }
module load_red()   { intersection() { box_raw(); logo_faces(logo_depth) logo_red_2d(); } }

// =====================================================================
//  assembly / wheel placement
// =====================================================================
module place_wheels(r, w, x) {
    translate([x, wheel_out, r]) rotate([90, 0, 0]) children();
    translate([x, -wheel_out, r]) rotate([-90, 0, 0]) children();
}
module assembly() {
    color(C_WHITE) body_white();
    color(C_BLACK) body_black();
    color(C_RED)   body_red();
    color(C_BLACK) mast();
    place_wheels(fw_r, fw_w, fw_x) { color(C_BLACK) wheel_black(fw_r, fw_w); color(C_WHITE) wheel_white(fw_r, fw_w); }
    place_wheels(rw_r, rw_w, rw_x) { color(C_BLACK) wheel_black(rw_r, rw_w); color(C_WHITE) wheel_white(rw_r, rw_w); }
    color(C_KRAFT) load_kraft();
    color(C_NAVY)  load_navy();
    color(C_RED)   load_red();
}

// =====================================================================
//  part selector (print orientation, sitting on z = 0)
// =====================================================================
if (part == "assembly") assembly();
else if (part == "body_white")   translate([0, 0, -clear]) body_white();
else if (part == "body_black")   translate([0, 0, -clear]) body_black();
else if (part == "body_red")     translate([0, 0, -clear]) body_red();
else if (part == "mast_black")   mast();
else if (part == "wheelF_black") wheel_black(fw_r, fw_w);
else if (part == "wheelF_white") wheel_white(fw_r, fw_w);
else if (part == "wheelR_black") wheel_black(rw_r, rw_w);
else if (part == "wheelR_white") wheel_white(rw_r, rw_w);
else if (part == "load_kraft")   load_kraft();
else if (part == "load_navy")    load_navy();
else if (part == "load_red")     load_red();
