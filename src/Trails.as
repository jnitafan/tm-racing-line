[Setting category="Trails" name="Enable trails" description="This plugin does nothing when disabled."]
bool Setting_DrawTrails = false;

[Setting category="Trails" name="Draw a trail per wheel?" description="Good for ice maps. Draws 4 lines per car instead of 1. 4x the load."]
bool Setting_Draw4Wheels = false;

[Setting category="Trails" name="Draw for players and ghosts?" description="This includes ghosts, but will mean trails are on for _all_ cars."]
bool Setting_IncludeGhosts = false;

[Setting category="Trails" name="Exclude player's car?" description="When enabled, a trail won't be drawn for your own car. Incompatible with 'Draw for players and ghosts'."]
bool Setting_ExcludePlayer = true;

[Setting hidden]
uint TrailPointsLength = 3000;

[Setting category="Trails" name="Points to draw per-trail" min="1" max="300" description="1 point per frame. Lower = shorter trails but less processing."];
uint TrailPointsToDraw = 10;

[Setting category="Trails" name="Trail thickness (px)" min="1" max="20" description="Thickness of trails in px"]
uint TrailThickness = 3;

// todo: impl settings

[Setting category="Trails" name="Dynamic Thickness" description="Draw trails with a dynamic thickness? Constant: no dynamic thickness. DistanceToCamera: thicker when closer to the camera (perspective). DistanceToCar: thicker when closer to the car. CombinedDistances: scale both by distance to camera then distance to car."]
DynThickness Setting_DynamicThickness = DynThickness::Constant;

[Setting category="Trails" name="Dynamic Thickness Modifier" min="0.25" max="4" description="Adjusts the dynamicness of the thickness. Only effective if Dynamic Thickness non-constant."]
float DynamicThicknessMod = 1.0;

// todo

// ! Note: ensure that: ((1 + max of SkipNPoints) * max of TrailPointsToDraw) <= TrailPointsLength
[Setting category="Trails" name="Skip N Points" min="0" max="9" description="Number of points to skip when drawing a trail. This increases performance relative to trail length but may cause artifacting.           Skip 0: draw all points (default).                                                                                     Skip 1: draw every 2nd point; 2x as long.                                    Skip 2: draw every 3rd point; 3x as long."]
uint SkipNPoints = 0;

[Setting category="Trails" name="Path Skip Stabilization" description="When skipping points, always draw the same points in each path, rather than letting the path move 'through' the points."]
bool Setting_PathSkipStable = true;

enum DynThickness {
    Constant,
    DistanceToCamera,
    DistanceToCar,
    CombinedDistances
}



vec4 RandVec4Color() {
    return vec4(
        Math::Rand(.3, 1.0),
        Math::Rand(.3, 1.0),
        Math::Rand(.3, 1.0),
        Math::Rand(.35, .45)
    );
}

class PlayerTrail {
    array<vec3> path;
    array<vec3> dirs;
    array<vec3> lefts;
    uint pathIx = 0;  // pointer to most recent entry in path
    vec4 col;
    PlayerTrail(vec4 &in _col = vec4()) {
        path.Reserve(TrailPointsLength);
        path.Resize(TrailPointsLength);
        dirs.Resize(TrailPointsLength);
        lefts.Resize(TrailPointsLength);
        if (_col.LengthSquared() > 0) col = _col;
        else col = RandVec4Color();
    }
    void AddPoint(vec3 &in p, vec3 &in dir, vec3 &in left) {
        pathIx = (pathIx + 1) % TrailPointsLength;
        path[pathIx] = p;
        dirs[pathIx] = dir;
        lefts[pathIx] = left;
    }
    void DrawPath() {
        float initLR = Setting_Draw4Wheels ? -1 : 0;
        float initDSign = Setting_Draw4Wheels ? -.7 : 0;
        float maxDistSquaredBetweenPoints = Math::Min(8 * (1 + SkipNPoints), 30);
        maxDistSquaredBetweenPoints *= maxDistSquaredBetweenPoints;
        uint trailPointsIncr = 1 + SkipNPoints;
        uint skipOffset = Setting_PathSkipStable ? (pathIx % (1 + SkipNPoints)) : 0;
        uint pointIndexLimit = TrailPointsToDraw * (1 + SkipNPoints);
        for (float lr = initLR; lr <= 1; lr += 2) {
            for (float dSign = initDSign; dSign <= 1.01; dSign += 1.7) {
                nvg::BeginPath();
                vec3 p;
                vec3 lp;

                for (uint i = 0; i < pointIndexLimit; i += trailPointsIncr) {
                    uint _ix = (pathIx - i - skipOffset + TrailPointsLength) % TrailPointsLength;
                    p = path[_ix] + (dirs[_ix] * dSign * 1.9) + (lefts[_ix] * lr * 0.9);
                    if (p.LengthSquared() == 0) continue;
                    bool skipDraw = lp.LengthSquared() > 0 && (lp - p).LengthSquared() > maxDistSquaredBetweenPoints;
                    try { // sometimes we get a div by 0 error in Camera.Impl:25
                        if (Camera::IsBehind(p)) break;
                        if (i == 0 || skipDraw)
                            nvg::MoveTo(Camera::ToScreenSpace(p));
                        else
                            nvg::LineTo(Camera::ToScreenSpace(p));
                    } catch {
                        continue;
                    }
                    lp = p;
                }
                nvg::LineCap(nvg::LineCapType::Round);
                nvg::StrokeWidth(float(TrailThickness));
                nvg::StrokeColor(col);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }
    }
}
