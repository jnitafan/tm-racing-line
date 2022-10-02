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

[Setting category="Trails" name="Dynamic Thickness" description="Draw trails with a dynamic thickness? Constant: disabled. DistanceToCamera: thicker when closer to the camera (perspective). DistanceToCar: thicker when closer to the car. CombinedDistances: scale both by distance to camera then distance to car. Performance impact: ~5-15% more load."]
DynThickness Setting_DynamicThickness = DynThickness::Constant;

[Setting category="Trails" name="Dynamic Thickness Modifier" min="0.25" max="4" description="Adjusts the dynamicness of the thickness. Only effective if Dynamic Thickness non-constant."]
float DynamicThicknessMod = 1.0;

// todo

// ! Note: ensure that: ((1 + max of SkipNPoints) * max of TrailPointsToDraw) <= TrailPointsLength
[Setting category="Trails" name="Skip N Points" min="0" max="9" description="Number of points to skip when drawing a trail. This increases performance relative to trail length but may cause artifacting.           Skip 0: draw all points (default).                                                                                     Skip 1: draw every 2nd point; 2x as long.                                    Skip 2: draw every 3rd point; 3x as long."]
uint SkipNPoints = 0;

[Setting category="Trails" name="Path Skip Stabilization" description="When skipping points, always draw the same points in each path, rather than letting the path move 'through' the points. Works best with dynamic thickness."]
bool Setting_PathSkipStable = true;

enum DynThickness {
    Constant = 0,
    DistanceToCamera = 1,
    DistanceToCar = 2,
    CombinedDistances = 3
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
        nvg::Reset();
        nvg::LineCap(nvg::LineCapType::Round);
        nvg::StrokeColor(col);
        float initLR = Setting_Draw4Wheels ? -1 : 0;
        float initDSign = Setting_Draw4Wheels ? -.7 : 0;
        float maxDistSquaredBetweenPoints = Math::Min(8 * (1 + SkipNPoints), 30);
        maxDistSquaredBetweenPoints *= maxDistSquaredBetweenPoints;
        uint trailPointsIncr = 1 + SkipNPoints;
        uint skipOffset = Setting_PathSkipStable ? (pathIx % (1 + SkipNPoints)) : 0;
        // uint pointIndexLimit = TrailPointsToDraw * (1 + SkipNPoints);
        iso4 cameraLoc = Camera::GetCurrent().Location;
        vec3 cameraPos = vec3(cameraLoc.tx, cameraLoc.ty, cameraLoc.tz);
        uint thicknessChangeF = Math::Max(1, TrailPointsToDraw / 10);
        float sw = float(TrailThickness); // Stroke Width
        for (float lr = initLR; lr <= 1; lr += 2) {
            for (float dSign = initDSign; dSign <= 1.01; dSign += 1.7) {
                nvg::BeginPath();
                vec3 firstP;
                vec3 p;
                vec3 lp;
                vec2 pUv;
                for (uint i = 0; i < TrailPointsToDraw; i++) {
                    uint _ix = (pathIx - (i * trailPointsIncr) - skipOffset + TrailPointsLength) % TrailPointsLength;
                    p = path[_ix] + (dirs[_ix] * dSign * 1.9) + (lefts[_ix] * lr * 0.9);
                    if (i == 0) firstP = p;
                    if (p.LengthSquared() == 0) continue;
                    bool skipDraw = lp.LengthSquared() > 0 && (lp - p).LengthSquared() > maxDistSquaredBetweenPoints;
                    try { // sometimes we get a div by 0 error in Camera.Impl:25
                        if (Camera::IsBehind(p)) break;
                        pUv = Camera::ToScreenSpace(p);
                        if (i == 0 || skipDraw)
                            nvg::MoveTo(pUv);
                        else
                            nvg::LineTo(pUv);
                    } catch {
                        continue;
                    }
                    lp = p;
                    // todo, probs don't want to do every frame, but we'll see
                    if (Setting_DynamicThickness != DynThickness::Constant && i % thicknessChangeF == 0) {
                        sw = TrailThickness;
                        if (0 < (Setting_DynamicThickness & DynThickness::DistanceToCamera)) {
                            sw = 2 * sw * Math::Pow(((p - cameraPos) / 20).Length(), -DynamicThicknessMod);
                        }
                        if (0 < (Setting_DynamicThickness & DynThickness::DistanceToCar)) {
                            sw = 2 * sw * Math::Pow(Math::Max(.75, ((p - firstP) / 20).Length()), -DynamicThicknessMod);
                        }
                        nvg::StrokeWidth(Math::Max(1, sw));
                        nvg::Stroke();
                        nvg::ClosePath();
                        nvg::BeginPath();
                        nvg::MoveTo(pUv);
                    }
                }
                nvg::StrokeWidth(sw);
                nvg::Stroke();
                nvg::ClosePath();
            }
        }
    }
}
