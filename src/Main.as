enum Cmp {Lt = -1, Eq = 0, Gt = 1}

void Main() {
    startnew(MainCoro);
}

void Update(float dt) {
    if (Setting_DrawTrails)
        DrawPlayers();
}

void RenderMenu() {
    if (UI::MenuItem("\\$d8f" + Icons::LongArrowRight + Icons::LongArrowRight + Icons::Kenney::Car + "\\$z Player Trails", "", Setting_DrawTrails)) {
        Setting_DrawTrails = !Setting_DrawTrails;
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
    trails.DeleteAll();
    visLookup.DeleteAll();
}

string get_CurrentMap() {
    auto map = GetApp().RootMap;
    if (map is null) return "";
    return map.MapInfo.MapUid;
}

// current playground
CSmArenaClient@ get_cp() {
    return cast<CSmArenaClient>(GetApp().CurrentPlayground);
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

dictionary@ trails = dictionary();
dictionary@ visLookup = dictionary();

void DrawPlayers() {
    auto cpg = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if (cpg is null) return;
    auto scene = cpg.GameScene;
    if (!Setting_IncludeGhosts) {
        auto players = cpg.Players;
        for (uint i = 0; i < players.Length; i++) {
            auto player = cast<CSmPlayer>(players[i]);
            if (player is null || (Setting_ExcludePlayer && player.User.Login == LocalUserLogin)) continue;
            auto vis = cast<CSceneVehicleVis>(visLookup[player.User.Name]);
            if (vis is null) {
                @vis = VehicleState::GetVis(scene, player);
                @visLookup[player.User.Name] = vis;
            }
            if (vis is null) continue; // something went wrong

            auto trail = cast<PlayerTrail>(trails[player.User.Name]);
            if (trail is null) {
                @trail = PlayerTrail();
                @trails[player.User.Name] = trail;
            }
            trail.AddPoint(vis.AsyncState.Position, vis.AsyncState.Dir, vis.AsyncState.Left);
            trail.DrawPath();
        }
    } else {
        // probs a bit faster, but also draws ghosts
        auto allVis = VehicleState::GetAllVis(scene);
        for (uint i = 0; i < allVis.Length; i++) {
            auto vis = allVis[i];
            string key = 'vis-' + i; // I expect this will change when players join/leave, but it shouldn't matter to much to drawing the trails
            auto trail = cast<PlayerTrail>(trails[key]);
            if (trail is null) {
                @trail = PlayerTrail();
                @trails[key] = trail;
            }
            trail.AddPoint(vis.AsyncState.Position, vis.AsyncState.Dir, vis.AsyncState.Left);
            trail.DrawPath();
        }
    }
}

void DrawIndicator(CSceneVehicleVisState@ vis) {
    if (Camera::IsBehind(vis.Position)) return;
    auto uv = Camera::ToScreenSpace(vis.Position); // possible div by 0
    auto gear = vis.CurGear;
    vec4 col;
    switch(gear) {
        case 0: col = vec4(.1, .1, .5, .5); break;
        case 1: col = vec4(.1, .4, .9, .5); break;
        case 2: col = vec4(.1, .9, .4, .5); break;
        case 3: col = vec4(.4, .9, .4, .5); break;
        case 4: col = vec4(.9, .4, .1, .5); break;
        case 5: col = vec4(.9, .1, .1, .5); break;
        default: col = vec4(.9, .1, .6, .5); print('unknown gear: ' + gear);
    }
    DrawPlayerIndicatorAt(uv, col);
}

void DrawPlayerIndicatorAt(vec2 uv, vec4 col) {
    nvg::BeginPath();
    nvg::RoundedRect(uv - vec2(20, 20)/2, vec2(20, 20), 4);
    nvg::FillColor(col);
    nvg::Fill();
    nvg::ClosePath();
}


void DrawPlayerIndicatorAt(vec2 uv) {
    nvg::BeginPath();
    nvg::RoundedRect(uv - vec2(20, 20)/2, vec2(20, 20), 4);
    nvg::FillColor(vec4(.99, .2, .92, .5));
    nvg::Fill();
}
