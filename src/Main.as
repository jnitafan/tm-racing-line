//Main.as
#if DEPENDENCY_MLHOOK

NadeoApi@ g_api;
FastestGhost@ g_fastestGhost;
bool g_PluginVisible = true;
string lastMap = "";
bool g_mapSwitched = false;

void Main() {
    if (!canRaceGhostsCheck()) {
        return;
    }
    @g_api = NadeoApi();
    @g_fastestGhost = FastestGhost();
    startnew(MainCoro);
}

void Update(float dt) {
    if (Setting_DrawTrails && g_fastestGhost !is null && g_fastestGhost.ghost.enabled) {
        DrawFastestGhost();
    }
}

void RenderMenu() {
    if (UI::MenuItem("\\$f84" + Icons::Trophy + Icons::LongArrowRight + "\\$z Fastest Ghost Trail", "", g_PluginVisible)) {
        g_PluginVisible = !g_PluginVisible;
    }
}

void RenderInterface() {
    int windowFlags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoDocking;
    if (!UI::IsOverlayShown()) {
        windowFlags |= UI::WindowFlags::NoInputs;
    }

    if (UI::IsOverlayShown() && inMap() && g_PluginVisible) {
        UI::Begin("Fastest Ghost Trail", windowFlags);
        
        if (GetApp().PlaygroundScript is null) {
            UI::Text(Meta::ExecutingPlugin().Name + " only works in Solo modes.");
            UI::End();
            return;
        }

        UI::BeginGroup();
        UI::Text("\\$f84" + Icons::Trophy + " Fastest Ghost Trail");
        UI::Separator();
        
        if (g_fastestGhost !is null) {
            if (g_fastestGhost.loading) {
                UI::Text(Icons::Spinner + " Loading fastest ghost...");
            } else if (g_fastestGhost.error) {
                UI::Text("\\$f00" + Icons::Times + " Failed to load fastest ghost");
                if (UI::Button("Retry")) {
                    g_fastestGhost.LoadFastestGhost();
                }
            } else if (g_fastestGhost.Username.Length > 0) {
                UI::Text("Player: " + (g_fastestGhost.ghost.enabled ? "\\$0f0" : "") + g_fastestGhost.Username);
                UI::Text("Time: " + MsToSeconds(g_fastestGhost.Time));
                
                if (g_fastestGhost.ghost.enabling) {
                    UI::Text(Icons::Spinner + " Adding ghost...");
                } else if (g_fastestGhost.ghost.error) {
                    UI::Text("\\$f00" + Icons::Times + " Ghost not available");
                } else {
                    bool ghostEnabled = g_fastestGhost.ghost.enabled;
                    if (UI::Checkbox("Enable Ghost & Trail", ghostEnabled)) {
                        g_fastestGhost.ghost.checkbox_clicked = ghostEnabled;
                        g_mapSwitched = false;
                    }
                }
                
                if (UI::Button("Spectate")) {
                    g_fastestGhost.ghost.Spectate();
                }
            } else {
                UI::Text("No ghost data available for this map");
            }
        }
        
        UI::Separator();
        UI::TextWrapped("This plugin automatically loads the fastest ghost for the current map and draws a trail behind it.");
        
        UI::EndGroup();
        UI::End();
    }
}

void Render() {
    if (!canRaceGhostsCheck()) {
        return;
    }

    if (!inMap()) {
        g_mapSwitched = true;
        if (g_fastestGhost !is null) {
            g_fastestGhost.ghost.reset();
        }
    } else if (!g_mapSwitched && g_fastestGhost !is null) {
        CGameManiaAppPlayground@ playground = GetApp().Network.ClientManiaAppPlayground;
        
        // Handle ghost enabling/disabling
        if (g_fastestGhost.ghost.checkbox_clicked != g_fastestGhost.ghost.enabled) {
            if (!g_fastestGhost.ghost.enabled) {
                print("Adding fastest ghost: " + g_fastestGhost.Username);
                g_fastestGhost.ghost.enabling = true;
                g_fastestGhost.ghost.Enable();
            } else {
                print("Disabling fastest ghost: " + g_fastestGhost.Username);
                g_fastestGhost.ghost.Disable();
            }
        }
        
        // Check if ghost exists in playground
        bool ghost_exists = false;
        for (uint j = 0; j < playground.DataFileMgr.Ghosts.Length; ++j) {
            if (playground.DataFileMgr.Ghosts[j].Nickname == g_fastestGhost.Username) {
                g_fastestGhost.ghost.MwId = playground.DataFileMgr.Ghosts[j].Id;
                ghost_exists = true;
                break;
            }
        }
        
        if (ghost_exists) {
            g_fastestGhost.ghost.enabling = false;
            g_fastestGhost.ghost.enabled = true;
            g_fastestGhost.ghost.timeout = 0;
        } else {
            if (g_fastestGhost.ghost.enabling) {
                g_fastestGhost.ghost.timeout++;
                if (g_fastestGhost.ghost.timeout >= 1000) {
                    g_fastestGhost.ghost.enabling = false;
                    g_fastestGhost.ghost.error = true;
                    g_fastestGhost.ghost.timeout = 0;
                }
            }
            g_fastestGhost.ghost.enabled = false;
        }
    }
}

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
    if (g_fastestGhost !is null) {
        g_fastestGhost.trail.DeleteAll();
        g_fastestGhost.ghost.reset();
        g_fastestGhost.LoadFastestGhost();
    }
}

string get_CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

void DrawFastestGhost() {
    auto cpg = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (cpg is null) return;
    auto scene = cpg.GameScene;
    
    // Find the fastest ghost among all vehicles
    auto allVis = VehicleState::GetAllVis(scene);
    for (uint i = 0; i < allVis.Length; i++) {
        auto vis = allVis[i];
        // Check if this is our fastest ghost by comparing some identifier
        // Since we can't directly match, we'll draw trail for the first ghost we find
        // This assumes the fastest ghost is the one we loaded
        if (g_fastestGhost.ghost.enabled) {
            g_fastestGhost.trail.AddPoint(vis.AsyncState.Position, vis.AsyncState.Dir, vis.AsyncState.Left);
            g_fastestGhost.trail.DrawPath();
            break; // Only draw for the first ghost (assumed to be ours)
        }
    }
}

CTrackMania@ get_app() {
    return cast<CTrackMania>(GetApp());
}

const string MsToSeconds(int t) {
    return Text::Format("%.3f", float(t) / 1000.0);
}

// Trail Settings
[Setting category="Fastest Ghost Trail" name="Enable trails" description="Draw trail behind the fastest ghost."]
bool Setting_DrawTrails = true;

[Setting category="Fastest Ghost Trail" name="Trail thickness (px)" min="1" max="20" description="Thickness of trails in px"]
uint TrailThickness = 4;

[Setting category="Fastest Ghost Trail" name="Points to draw per-trail" min="10" max="200" description="Number of points to draw for the trail."]
uint TrailPointsToDraw = 50;

[Setting hidden]
uint TrailPointsLength = 2000;

// FastestGhost.as
class FastestGhost {
    string Username = "";
    string WsId = "";
    int Time = 0;
    bool loading = false;
    bool error = false;
    Ghost@ ghost;
    PlayerTrail@ trail;
    
    FastestGhost() {
        @ghost = Ghost();
        @trail = PlayerTrail(vec4(1.0, 0.8, 0.0, 0.6)); // Golden trail for fastest ghost
    }
    
    void LoadFastestGhost() {
        if (CurrentMap.Length == 0) return;
        
        loading = true;
        error = false;
        startnew(CoroutineFunc(this.GetFastestGhostFromAPI));
    }
    
    void GetFastestGhostFromAPI() {
        try {
            string mapUid = CurrentMap;
            if (mapUid.Length == 0) {
                error = true;
                loading = false;
                return;
            }
            
            // Get map leaderboard from Nadeo API
            string url = "https://prod.trackmania.core.nadeo.online/api/token/leaderboard/group/Personal_Best/map/" + mapUid + "/top?length=1&offset=0";
            
            Net::HttpRequest@ req = Net::HttpGet(url);
            while (!req.Finished()) {
                yield();
            }
            
            if (req.ResponseCode() != 200) {
                print("Failed to get leaderboard: " + req.ResponseCode());
                error = true;
                loading = false;
                return;
            }
            
            Json::Value response = Json::Parse(req.String());
            if (response.GetType() != Json::Type::Object || !response.HasKey("tops")) {
                error = true;
                loading = false;
                return;
            }
            
            Json::Value tops = response["tops"];
            if (tops.GetType() != Json::Type::Array || tops.Length == 0) {
                error = true;
                loading = false;
                return;
            }
            
            Json::Value leaderboard = tops[0];
            if (!leaderboard.HasKey("top") || leaderboard["top"].Length == 0) {
                error = true;
                loading = false;
                return;
            }
            
            Json::Value topRecord = leaderboard["top"][0];
            Username = topRecord["accountId"];
            Time = topRecord["score"];
            
            // Get display name
            startnew(CoroutineFunc(this.GetDisplayName));
            
        } catch {
            print("Exception in GetFastestGhostFromAPI");
            error = true;
            loading = false;
        }
    }
    
    void GetDisplayName() {
        try {
            string url = "https://prod.trackmania.core.nadeo.online/api/token/account/" + Username;
            
            Net::HttpRequest@ req = Net::HttpGet(url);
            while (!req.Finished()) {
                yield();
            }
            
            if (req.ResponseCode() == 200) {
                Json::Value response = Json::Parse(req.String());
                if (response.HasKey("displayName")) {
                    Username = response["displayName"];
                }
            }
            
            loading = false;
            
        } catch {
            print("Exception in GetDisplayName");
            loading = false;
        }
    }
}

// Ghost.as (simplified version of the ghost management from your second snippet)
class Ghost {
    string MwId;
    bool enabled = false;
    bool enabling = false;
    bool error = false;
    bool checkbox_clicked = false;
    uint timeout = 0;
    string rank = "-";
    
    void Enable() {
        // Implementation would depend on MLHook specifics
        // This is a placeholder for the actual ghost enabling logic
    }
    
    void Disable() {
        CGameManiaAppPlayground@ playground = GetApp().Network.ClientManiaAppPlayground;
        if (playground !is null) {
            for (uint i = 0; i < playground.DataFileMgr.Ghosts.Length; ++i) {
                if (playground.DataFileMgr.Ghosts[i].Id.Value == MwId) {
                    playground.DataFileMgr.Ghosts[i].IsVisible = false;
                    break;
                }
            }
        }
        enabled = false;
    }
    
    void Spectate() {
        // Implementation for spectating the ghost
    }
    
    void reset() {
        if (enabled) {
            Disable();
        }
        enabled = false;
        enabling = false;
        error = false;
        checkbox_clicked = false;
        timeout = 0;
        rank = "-";
    }
    
    void getRank() {
        // Implementation for getting rank
    }
}

// PlayerTrail.as (adapted from your first snippet)
class PlayerTrail {
    array<vec3> path;
    array<vec3> dirs;
    array<vec3> lefts;
    uint pathIx = 0;
    vec4 col;
    
    PlayerTrail(vec4 &in _col = vec4()) {
        path.Reserve(TrailPointsLength);
        path.Resize(TrailPointsLength);
        dirs.Resize(TrailPointsLength);
        lefts.Resize(TrailPointsLength);
        if (_col.LengthSquared() > 0) col = _col;
        else col = vec4(1.0, 0.8, 0.0, 0.6); // Default golden color
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
        nvg::StrokeWidth(TrailThickness);
        
        nvg::BeginPath();
        vec3 p;
        vec2 pUv;
        bool firstPoint = true;
        
        for (uint i = 0; i < TrailPointsToDraw; i++) {
            uint _ix = (pathIx - i + TrailPointsLength) % TrailPointsLength;
            p = path[_ix];
            
            if (p.LengthSquared() == 0) continue;
            
            try {
                if (Camera::IsBehind(p)) break;
                pUv = Camera::ToScreenSpace(p);
                
                if (firstPoint) {
                    nvg::MoveTo(pUv);
                    firstPoint = false;
                } else {
                    nvg::LineTo(pUv);
                }
            } catch {
                continue;
            }
        }
        
        nvg::Stroke();
        nvg::ClosePath();
    }
    
    void DeleteAll() {
        for (uint i = 0; i < path.Length; i++) {
            path[i] = vec3();
            dirs[i] = vec3();
            lefts[i] = vec3();
        }
        pathIx = 0;
    }
}

// Helper functions (you'll need to implement these based on your existing code)
bool canRaceGhostsCheck() {
    // Implementation to check if user can race against ghosts
    return true; // Placeholder
}

bool inMap() {
    auto map = GetApp().RootMap;
    return map !is null;
}

// NadeoApi class (placeholder - you'll need to implement authentication)
class NadeoApi {
    // Implementation for Nadeo API authentication and requests
}

#else
void Main() {
    UI::ShowNotification(
        "Fastest Ghost Trail Plugin Error",
        "This plugin depends on the plugin MLHook.\nPlease install \\$000 MLHook \\$z from the Plugin Manager",
        vec4(1, 0.5, 0.2, 0),
        10000
    );
}
#endif