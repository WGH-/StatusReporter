class StatusReporter extends Info;

var WebSocket WS;

var string ServerName;
var string GameClass;
var string MapName;
var string PrevMapName;

var float ReportInterval;
var float MinTimeBetweenReports;

var transient float LastRun;


const PROTOCOL = "v1.server.status.torlan.ru";

event PreBeginPlay()
{
    super.PreBeginPlay();

    Disable('Tick');

    Connect();
}

function Connect()
{
    ClearTimer('Connect');
    if (WS == None) {
        WS = Spawn(class'WebSocket');
        WS.onclose = onclose;
        WS.onmessage = onmessage;
        WS.onopen = onopen;
    }
    WS.Init(class'StatusReporter.StatusReporter_Mut'.default.URL, PROTOCOL);
}

function SendUpdate()
{
    local string buffer;
    local GameReplicationInfo GRI;
    local UTOnslaughtMapInfo UTOnsMI;
    local GameInfo Game;
    
    if (LastRun > 0 && WorldInfo.TimeSeconds - LastRun < MinTimeBetweenReports) {
        SetTimer(MinTimeBetweenReports,, 'SendUpdate');
        return;
    }
    if (WS == None || WS.readyState != OPEN) {
        SetTimer(MinTimeBetweenReports,, 'SendUpdate');
        return;
    }

    if (WorldInfo.IsInSeamlessTravel()) return;

    Game = WorldInfo.Game;
    GRI = Game.GameReplicationInfo;
    UTOnsMI = UTOnslaughtMapInfo(WorldInfo.GetMapInfo());

    buffer $= "{";
    buffer $= KeyVal("\"MapName\"", JSON MapName);
    buffer $= KeyVal("\"PrevMapName\"", JSON PrevMapName);
    buffer $= KeyVal("\"GameClass\"", JSON GameClass);
    buffer $= KeyVal("\"MaxPlayers\"", JSON Game.MaxPlayers);
    buffer $= KeyVal("\"NumPlayers\"", JSON Game.NumPlayers);
    buffer $= KeyVal("\"MaxSpectators\"", JSON Game.MaxSpectators);
    buffer $= KeyVal("\"NumSpectators\"", JSON Game.NumSpectators);
    buffer $= KeyVal("\"NumBots\"", JSON Game.NumBots);
    buffer $= KeyVal("\"TimeDilation\"", JSON WorldInfo.TimeDilation);
    buffer $= KeyVal("\"MatchIsInProgress\"", JSON Game.MatchIsInProgress());
    if (GRI != None) {
        buffer $= KeyVal("\"TimeLimit\"", JSON GRI.TimeLimit);
        buffer $= KeyVal("\"RemainingTime\"", JSON GRI.RemainingTime);
        buffer $= KeyVal("\"ElapsedTime\"", JSON GRI.ElapsedTime);
        buffer $= KeyVal("\"bStopCountDown\"", JSON GRI.bStopCountDown);
//Time = FormatTime(UTGRI.TimeLimit != 0 ? UTGRI.RemainingTime : UTGRI.ElapsedTime);
        buffer $= KeyVal("\"GoalScore\"", JSON GRI.GoalScore);
        buffer $= KeyVal("\"ServerName\"", JSON GRI.ServerName);
    }
    if (UTOnsMI != None) {
        buffer $= KeyVal("\"LinkSetup\"", JSON UTOnsMI.GetActiveSetupName());
    }
    buffer $= KeyVal("\"Mutators\"", GetMutators());
    buffer $= KeyVal("\"Teams\"", GetTeamsInfo());
    buffer $= KeyVal("\"RequiresPassword\"", JSON Game.RequiresPassword()); 
    buffer $= KeyVal("\"Players\"", GetPlayersInfo(), true);
    buffer $= "}";

    WS.WS_send(buffer);    
    
    LastRun = WorldInfo.TimeSeconds;
}

function string GetMutators()
{
    local string s;
    local Mutator M;

    s = "[";

    for (M = WorldInfo.Game.BaseMutator; M != None; M = M.NextMutator) {
        s $= JSON(M.Class.GetPackageName() $ "." $ M.Class.Name);

        if (M.NextMutator != None) s $= ",";
    }
    s $= "]";
    
    return s;
}

function string GetPlayersInfo()
{
    local string s;
    local Controller C;
    s = "[";
    
    foreach WorldInfo.AllControllers(class'Controller', C)
    {
        if (!C.bDeleteMe && 
            C.PlayerReplicationInfo != None &&
            C.bIsPlayer && 
            DemoRecSpectator(C) == None)
        {
            s $= JSON C.PlayerReplicationInfo;
            s $= ",";
        }
    }
    if (Right(s, 1) == ",") {
        s = Left(s, Len(s) - 1);
    }
    s $= "]";
    return s;
}

function string GetTeamsInfo()
{
    local string s;
    local int i;
    s $= "[";
    for (i = 0; i < WorldInfo.Game.GameReplicationInfo.Teams.Length; i++) {
        GetTeamInfo(i, s);
        if (i != WorldInfo.Game.GameReplicationInfo.Teams.Length - 1) {
            s $= ",";
        }
    }
    s $= "]";
    return s;
}

function GetTeamInfo(int Index, out string s)
{
    local UTOnslaughtPowerCore Core;
    local TeamInfo TI;
    TI = WorldInfo.Game.GameReplicationInfo.Teams[Index];
    s $= "{";
    s $= KeyVal("\"TeamIndex\"", JSON TI.TeamIndex);
    s $= KeyVal("\"Score\"", JSON TI.Score);
    if (UTOnslaughtGame(WorldInfo.Game) != None) {
        Core = UTOnslaughtGame(WorldInfo.Game).PowerCore[index];
        s $= KeyVal("\"CoreHealth\"", JSON(Core.Health / Core.DamageCapacity));
    }
    s $= KeyVal("\"Color\"", JSON TI.GetHUDColor(), true); 
    s $= "}";
}
/* Various events that trigger an update */

function InitMutator() {
    PrevMapName = MapName;
    MapName = WorldInfo.GetMapName(true);
    GameClass = WorldInfo.Game.class.GetPackageName() $ "." $ WorldInfo.Game.class;

    LastRun = default.LastRun;

    DelayedUpdate(); 

    SetTimer(ReportInterval, true);
}

function DelayedUpdate()
{
    // Tick() will be called at the next tick
    // this way we avoid situations like
    // NotifyLogin being called before new player's 
    // ReplicationInfo is properly initialized 
    Enable('Tick');
}

event Reset() {
    super.Reset();
    DelayedUpdate(); 
}

function NotifyLogin(Controller C) {
    DelayedUpdate(); 
}

function NotifyLogout(Controller C) {
    DelayedUpdate(); 
}

event Tick(float DeltaTime)
{
    SendUpdate();
    Disable('Tick');
}

event Timer()
{
    if (WorldInfo.Game.NumPlayers > 0) {
        DelayedUpdate();
    }
}

event Destroyed()
{
    super.Destroyed();

    if (WS != None) {
        WS.Close();
        WS = None;
    }
}

/* WS delegates */
function onclose(bool wasClean, int code, string reason)
{
    `warn(reason);
    if (WS != None) {
        WS.Close();
        WS = None;
    } 
    SetTimer(10.0,, 'Connect');
}

function onmessage(string s)
{
    
}

function onopen()
{
    `log("Successfuly connected.",, 'ServerStatus');
    DelayedUpdate();
}

// JSON functions
static final preoperator string JSON(string s)
{
    s = Repl(s, "\\", "\\\\");
    s = Repl(s, "\"", "\\\"");
    s = Repl(s, Chr(8), "\\b");
    s = Repl(s, Chr(12), "\\f");
    s = Repl(s, Chr(10), "\\n");
    s = Repl(s, Chr(13), "\\r");
    s = Repl(s, Chr(9), "\\t");

    return "\"" $ s $ "\"";
}

static final preoperator string JSON(name n)
{
    return JSON string(n);
}

static final preoperator string JSON(int i)
{
    return string(i);
}

static final preoperator string JSON(float f)
{
    return string(f);
}

static final preoperator string JSON(bool b)
{
    return b ? "true" : "false";
}

static final preoperator string JSON(color c)
{   
    // rgba(R, G, B, A)
    // where R,G,B = [0, 255], and A = [0.0, 1.0]
    return "\"rgba(" $ c.R $ "," $ c.G $ "," $ c.B $ "," $ float(c.A) / 255 $ ")\"";
}

static final preoperator string JSON(UniqueNetId id)
{
    return JSON class'Engine.OnlineSubsystem'.static.UniqueNetIdToString(id);
}

static final preoperator string JSON(PlayerReplicationInfo PRI)
{
    local string s;
    s = "{";

    s $= KeyVal("\"NickName\"", JSON PRI.GetPlayerAlias());
    s $= KeyVal("\"Score\"", JSON PRI.Score);
    if (PRI.Team != None) {
        s $= KeyVal("\"TeamIndex\"", JSON PRI.Team.TeamIndex);
    }
    if (UTPlayerReplicationInfo(PRI) != None) {
        s $= KeyVal("\"ClanTag\"", JSON UTPlayerReplicationInfo(PRI).ClanTag);
    }
    s $= KeyVal("\"bBot\"", JSON PRI.bBot);
    s $= KeyVal("\"bIsSpectator\"", JSON PRI.bIsSpectator);
    s $= KeyVal("\"UniqueId\"", JSON PRI.UniqueId);
    s $= KeyVal("\"Ping\"", JSON (int(PRI.Ping) * 4), true);

    s $= "}";
    return s;
}

final static function string KeyVal(string key, string value, optional bool last)
{
    return key $ ":" $ value $ (last ? "" : ",");
}

defaultproperties
{
    ReportInterval=60.0
    MinTimeBetweenReports=1.0
    LastRun=-1.0

    TickGroup=TG_PostAsyncWork
}
