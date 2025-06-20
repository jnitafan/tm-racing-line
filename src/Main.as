//Main.as
enum Cmp {Lt = -1, Eq = 0, Gt = 1}

[Setting category="General" name="Draw Ghost End Trails" description="Show trails for ghosts"]
bool Setting_DrawGhostEndTrails = true;

[Setting category="General" name="Auto Render Lines" description="Automatically render ghost lines when map changes"]
bool Setting_AutoRenderLines = true;

[Setting category="General" name="Trail Length" description="Number of trail points to keep" min=10 max=1000]
uint Setting_TrailLength = 200;

[Setting category="General" name="Permanent Trails" description="Keep trails permanently on screen"]
bool Setting_PermanentTrails = true;

void Main() {
    startnew(MainCoro);
}

void Update(float dt) {
    if (Setting_DrawGhostEndTrails) {
        DrawGhostEndTrails();
    }
}

void RenderMenu() {
    if (UI::MenuItem("\\$d8f" + Icons::LongArrowRight + Icons::LongArrowRight + Icons::Kenney::Car + "\\$z Ghost End Trails", "", Setting_DrawGhostEndTrails)) {
        Setting_DrawGhostEndTrails = !Setting_DrawGhostEndTrails;
    }
    
    if (UI::MenuItem("\\$fa4" + Icons::FastForward + "\\$z Render Ghost Lines")) {
        RenderGhostLines();
    }
    
    if (UI::MenuItem("\\$4af" + Icons::Play + "\\$z Resume Ghost Playback")) {
        ResumeGhostPlayback();
    }
    
    if (UI::MenuItem("\\$f44" + Icons::Trash + "\\$z Clear All Trails")) {
        ClearAllTrails();
    }
}

const string MsToSeconds(int t) {
    return Text::Format("%.3f", float(t) / 1000.0);
}

CTrackMania@ get_app() {
    return cast<CTrackMania>(GetApp());
}

CGameManiaAppPlayground@ get_cmap() {
    return app.Network.ClientManiaAppPlayground;
}

string lastMap = "";
bool ghostsRendering = false;
bool ghostsRendered = false;

void MainCoro() {
    while (true) {
        sleep(100);
        if (lastMap != CurrentMap) {
            lastMap = CurrentMap;
            OnMapChange();
        }
    }
}

void OnMapChange() {
    if (!Setting_PermanentTrails) {
        ghostTrails.DeleteAll();
        visLookup.DeleteAll();
    }
    ghostsRendering = false;
    ghostsRendered = false;
    
    if (Setting_AutoRenderLines) {
        // Wait a bit for ghosts to load
        startnew(DelayedGhostRender);
    }
}

void DelayedGhostRender() {
    sleep(2000); // Wait 2 seconds for ghosts to load
    RenderGhostLines();
}

string get_CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

string _localUserLogin;
string get_LocalUserLogin() {
    if (_localUserLogin.Length == 0) {
        auto pcsa = GetApp().Network.PlaygroundClientScriptAPI;
        if (pcsa !is null && pcsa.LocalUser !is null) {
            _localUserLogin = pcsa.LocalUser.Login;
        }
    }
    return _localUserLogin;
}

string _localUserName;
string get_LocalUserName() {
    if (_localUserName.Length == 0) {
        auto pcsa = GetApp().Network.PlaygroundClientScriptAPI;
        if (pcsa !is null && pcsa.LocalUser !is null) {
            _localUserName = pcsa.LocalUser.Name;
        }
    }
    return _localUserName;
}

dictionary@ ghostTrails = dictionary();
dictionary@ visLookup = dictionary();

void RenderGhostLines() {
    auto mgr = GhostClipsMgr::Get(cast<CGameCtnApp>(GetApp()));
    if (mgr is null) {
        print("No ghost clips manager found");
        return;
    }
    
    if (mgr.Ghosts.Length == 0) {
        print("No ghosts loaded");
        return;
    }
    
    // Get the maximum ghost duration
    uint maxDuration = GhostClipsMgr::GetMaxGhostDuration(mgr);
    if (maxDuration == 0) {
        print("No valid ghost duration found");
        return;
    }
    
    print("Rendering lines for " + mgr.Ghosts.Length + " ghosts (duration: " + MsToSeconds(maxDuration) + ")");
    
    // Start the rendering process
    ghostsRendering = true;
    ghostsRendered = false;
    
    // Only clear trails if not permanent
    if (!Setting_PermanentTrails) {
        ghostTrails.DeleteAll();
        visLookup.DeleteAll();
    }
    
    // Start the rendering coroutine
    startnew(RenderGhostLinesCoroutine);
}

void RenderGhostLinesCoroutine() {
    auto mgr = GhostClipsMgr::Get(cast<CGameCtnApp>(GetApp()));
    if (mgr is null) {
        ghostsRendering = false;
        return;
    }
    
    uint maxDuration = GhostClipsMgr::GetMaxGhostDuration(mgr);
    if (maxDuration == 0) {
        ghostsRendering = false;
        return;
    }
    
    // Reset ghosts to start
    GhostClipsMgr::UnpauseClipPlayers(mgr, 0.0, float(maxDuration) / 1000.0);
    
    uint startTime = Time::Now;
    uint lastUpdate = startTime;
    
    // Play ghosts at double speed until completion
    while (ghostsRendering) {
        uint currentTime = Time::Now;
        float deltaTime = float(currentTime - lastUpdate) / 1000.0;
        lastUpdate = currentTime;
        
        // Advance clip players by delta at double speed
        auto result = GhostClipsMgr::AdvanceClipPlayersByDelta(mgr, 2.0);
        
        // Check if we've reached the end
        float currentGhostTime = result.x;
        float totalTime = float(maxDuration) / 1000.0;
        
        if (currentGhostTime >= totalTime) {
            break;
        }
        
        sleep(16); // ~60 FPS rendering
    }
    
    // Pause ghosts at the end
    GhostClipsMgr::PauseClipPlayers(mgr, float(maxDuration) / 1000.0);
    
    ghostsRendering = false;
    ghostsRendered = true;
    
    print("Ghost lines rendered successfully!");
}

void ResumeGhostPlayback() {
    auto mgr = GhostClipsMgr::Get(cast<CGameCtnApp>(GetApp()));
    if (mgr is null) return;
    
    uint maxDuration = GhostClipsMgr::GetMaxGhostDuration(mgr);
    if (maxDuration == 0) return;
    
    float totalTime = float(maxDuration) / 1000.0;
    GhostClipsMgr::UnpauseClipPlayers(mgr, 0.0, totalTime);
    
    ghostsRendering = false;
    ghostsRendered = false;
    print("Resumed ghost playback");
}

void ClearAllTrails() {
    ghostTrails.DeleteAll();
    visLookup.DeleteAll();
    print("Cleared all trails");
}

void DrawGhostEndTrails() {
    auto cpg = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (cpg is null) return;
    auto scene = cpg.GameScene;
    if (scene is null) return;
    
    // Get all vehicle visualizations (includes ghosts)
    auto allVis = VehicleState::GetAllVis(scene);
    for (uint i = 0; i < allVis.Length; i++) {
        auto vis = allVis[i];
        if (vis is null) continue;
        
        // Skip player's own vehicle by checking if this is a live player
        bool isPlayerVehicle = false;
        if (cpg.Players.Length > 0) {
            for (uint j = 0; j < cpg.Players.Length; j++) {
                auto player = cast<CSmPlayer>(cpg.Players[j]);
                if (player !is null && player.User.Login == LocalUserLogin) {
                    auto playerVis = VehicleState::GetVis(scene, player);
                    if (playerVis is vis) {
                        isPlayerVehicle = true;
                        break;
                    }
                }
            }
        }
        
        // Skip drawing trail for player's vehicle
        if (isPlayerVehicle) continue;
        
        string key = 'ghost-' + i;
        auto trail = cast<PlayerTrail>(ghostTrails[key]);
        if (trail is null) {
            @trail = PlayerTrail();
            @ghostTrails[key] = trail;
        }
        
        // Add current position to trail only when rendering or if permanent trails and not rendered yet
        if (ghostsRendering || (Setting_PermanentTrails && !ghostsRendered)) {
            trail.AddPoint(vis.AsyncState.Position, vis.AsyncState.Dir, vis.AsyncState.Left);
        }
        
        // Limit trail length only if not permanent trails
        if (!Setting_PermanentTrails) {
            trail.LimitLength(Setting_TrailLength);
        }
        
        // Always draw existing trails
        trail.DrawPath();
        
        // Draw indicator for ghost position only when rendered and paused
        if (ghostsRendered && !ghostsRendering) {
            DrawGhostIndicator(vis.AsyncState);
        }
    }
}

void DrawGhostIndicator(CSceneVehicleVisState@ vis) {
    if (Camera::IsBehind(vis.Position)) return;
    auto uv = Camera::ToScreenSpace(vis.Position);
    
    // Use a distinct color for ghost end positions
    vec4 col = vec4(1.0, 0.8, 0.2, 0.8); // Golden color for ghost end positions
    DrawGhostIndicatorAt(uv, col);
}

void DrawGhostIndicatorAt(vec2 uv, vec4 col) {
    nvg::BeginPath();
    nvg::RoundedRect(uv - vec2(25, 25)/2, vec2(25, 25), 6);
    nvg::FillColor(col);
    nvg::Fill();
    
    // Add a border to make it more visible
    nvg::StrokeWidth(2);
    nvg::StrokeColor(vec4(0.2, 0.2, 0.2, 0.8));
    nvg::Stroke();
    nvg::ClosePath();
}

//PlayerTrail.as - Enhanced version for ghost trails
class PlayerTrail {
    array<vec3> positions;
    array<vec3> directions;
    array<vec3> lefts;
    uint maxPoints = 200;
    
    void AddPoint(vec3 pos, vec3 dir, vec3 left) {
        positions.InsertLast(pos);
        directions.InsertLast(dir);
        lefts.InsertLast(left);
        
        // Only remove old points if permanent trails is disabled
        if (!Setting_PermanentTrails) {
            while (positions.Length > maxPoints) {
                positions.RemoveAt(0);
                directions.RemoveAt(0);
                lefts.RemoveAt(0);
            }
        }
    }
    
    void LimitLength(uint newMaxPoints) {
        maxPoints = newMaxPoints;
        if (!Setting_PermanentTrails) {
            while (positions.Length > maxPoints) {
                positions.RemoveAt(0);
                directions.RemoveAt(0);
                lefts.RemoveAt(0);
            }
        }
    }
    
    void DrawPath() {
        if (positions.Length < 2) return;
        
        for (uint i = 1; i < positions.Length; i++) {
            float alpha = float(i) / float(positions.Length);
            vec4 color = vec4(1.0, 0.8 * alpha, 0.2 * alpha, 0.6 * alpha);
            
            vec3 start = positions[i-1];
            vec3 end = positions[i];
            
            // Skip if points are too close or too far apart (likely teleport)
            float distance = Math::Distance(start, end);
            if (distance < 0.1 || distance > 50.0) continue;
            
            // Draw line between consecutive points
            nvg::BeginPath();
            auto startUV = Camera::ToScreenSpace(start);
            auto endUV = Camera::ToScreenSpace(end);
            
            if (!Camera::IsBehind(start) && !Camera::IsBehind(end)) {
                nvg::MoveTo(startUV);
                nvg::LineTo(endUV);
                nvg::StrokeWidth(3.0 * alpha + 1.0);
                nvg::StrokeColor(color);
                nvg::Stroke();
            }
            nvg::ClosePath();
        }
    }
    
    void Clear() {
        positions.RemoveRange(0, positions.Length);
        directions.RemoveRange(0, directions.Length);
        lefts.RemoveRange(0, lefts.Length);
    }
}