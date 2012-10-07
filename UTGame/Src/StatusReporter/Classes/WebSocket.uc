class WebSocket extends TcpLink;

/*
Current quirks:
 * Long fragments are not supported
 * UTF-8 decoding is not implemented
*/

var protected IpAddr IpAddr_;
var protected string Path;
var protected string Host;
var protected string AuthHeader;

var protected string WebSocket_Key;
var protected int FragmentedOpcode;

var protected Base64 Base64;

const CONTINUATION_FRAME = 0x0;
const TEXT_FRAME = 0x1;
const BINARY_FRAME = 0x2;
const CONN_CLOSE_FRAME = 0x8;
const PING_FRAME = 0x9;
const PONG_FRAME = 0xA;

/* client requirements per standard */
var protected bool bReceivedUpgradeH;
var protected bool bReceivedConnectionH;
var protected bool bReceivedAcceptH;
var protected bool bReceivedStatus;
var protected bool bProtocolNegotiated;

var int StatusCode;
var protected string StatusReason;
 
var protected string StringBuffer;
var protected array<byte> ReceiveFrameBuffer;
var protected array<byte> ReceiveDataBuffer;
var protected array<byte> SendDataBuffer;

var float Timeout;
var bool bSendUserAgent;
var bool bDontAcceptLongMessages;

/* (almost) interface defined in HTML5 */

var enum WSState{
    CONNECTING,
    OPEN,
    CLOSING,
    CLOSED
} readyState;

var int bufferedAmount;

var string extensions;
var string protocol;

delegate onopen();
delegate onerror();
delegate onclose(bool wasClean, int code, string reason);
delegate onmessage(string data);

simulated function WS_close(optional int code, optional string reason)
{
    local array<byte> arr;

    if (readyState == CLOSING || readyState == CLOSED) {
        return;
    } else if (readyState == OPEN) {
        SendFrame(CONN_CLOSE_FRAME, arr);
        readyState = CLOSING;
        onclose(true, 0, "Closed gracefully");
    }   
}


simulated function WS_send(out const string message)
{
    local array<byte> arr;

    AppendByteStringUTF8(arr, message);
    SendFrame(TEXT_FRAME, arr);
}

simulated function PreBeginPlay()
{
    super.PreBeginPlay();

    readyState = CLOSED;
}

simulated function Init(string url, optional string protocol_)
{
    local int i;
    local string username, password;

    if (readyState != CLOSED) {
        `warn("Tried to Init nonclosed WebSocket");
        return;
    }

    if (Left(url, 5) != "ws://") {
        `warn(url @ "is not valid WebSocket URL");
        Destroy();
        return;
    }
    url = Mid(url, 5); // strlen("ws://")

    i = InStr(url, "@");

    if (i != INDEX_NONE) {
        username = Left(url, i);
        url = Mid(url, i + 1);
        
        i = InStr(username, ":");
        if (i != INDEX_NONE) {
            password = Mid(username, i + 1);
            username = Left(username, i);
        }

    }
    Base64 = new(None) class'StatusReporter.Base64';
    PrepareAuthHeader(username, password);

    i = InStr(url, "/");
    host = Left(url, i); 
    Path = Mid(url, i);

    i = InStr(host, ":");
    if (i != INDEX_NONE) {
        IpAddr_.port = Int(Mid(host, i+1));
        host = Left(host, i);
    } else {
        IpAddr_.port = 80;
    }

    Protocol = protocol_;
    bProtocolNegotiated = (Protocol == "");

    readyState = CONNECTING;
    WebSocket_Key = GetWebSocket_Key();
    bReceivedConnectionH = false;
    bReceivedUpgradeH = false;
    bReceivedAcceptH = false;
    bReceivedStatus = false;

    StringBuffer = "";
    ReceiveFrameBuffer.Length = 0;
    ReceiveDataBuffer.Length = 0;
    SendDataBuffer.Length = 0;
    
    SetTimer(Timeout, false, 'ResolveFailed');
    Resolve(host);
}

simulated function ResolveFailed()
{
    readyState = CLOSED;
    onerror();
    onclose(false, 0, "Couldn't resolve hostname");
}

simulated event Resolved(IpAddr Addr)
{
    ClearTimer('ResolveFailed');
    BindPort();
    Addr.Port = IpAddr_.Port;
    SetTimer(timeout, false, 'OpenFailed');
    LinkMode = MODE_Binary;
    ReceiveMode = RMODE_Manual;
    Open(Addr);
}

simulated event Tick(float DeltaTime)
{
    super.Tick(DeltaTime);
    if (IsConnected() && IsDataPending()) {
        while (ReadBinaryWrapper() != 0);
    }
}

simulated function int ReadBinaryWrapper()
{
    local byte b[255];
    local int count;
    count = ReadBinary(ArrayCount(b), b);
    ReceivedBinaryEx(count, b);
    return count;
}

simulated function OpenFailed()
{
    readyState = CLOSING;
    Close();
    onerror();
    onclose(false, 0, "Couldn't connect to remote host");
}

simulated event Opened()
{ 
    ClearTimer('OpenFailed');

    SendHeader("GET" @ Path @ "HTTP/1.1");
    SendHeader("Host:" @ Host $ ":" $ IpAddr_.Port);
    SendHeader("Connection: Upgrade");
    SendHeader("Upgrade: websocket");
    SendHeader("Sec-WebSocket-Key:" @ WebSocket_Key);
    SendHeader("Sec-WebSocket-Version: 13");
    if (Len(Protocol) > 0) {
        SendHeader("Sec-WebSocket-Protocol:" @ Protocol);
    }
    if (bSendUserAgent) {
        SendHeader("User-Agent: UnrealEngine3/" $ WorldInfo.EngineVersion);
    }
    if (AuthHeader != "") {
        SendHeader(AuthHeader);
    }
    SendHeader("");
    
    SetTimer(timeout, false, 'ResponseTimeout');
}

simulated event Closed()
{
    // underlying socket closed
    if (readyState != CLOSED && readyState != CLOSING) {
        readyState = CLOSED;
        onclose(false, 0, "Connection has been closed. Errno:" @ GetLastError());
    }
    readyState = CLOSED;
    Destroy();
}

simulated function string GetWebSocket_Key()
{
    local WebRequest WR;
    local int i;
    local string key;
    
    for (i = 0; i < 16; i++) {
        key $= Chr(Rand(256));
    }

    WR = new(None) class'WebRequest';
    return WR.EncodeBase64(key);
}

simulated function GenerateMask(out byte mask[4])
{
    mask[0] = Rand(256);
    mask[1] = Rand(256);
    mask[2] = Rand(256);
    mask[3] = Rand(256);
}

simulated function bool CheckWebSocketAccept(string key)
{
    local SHA1Hash SHA1;
    local SHA1Result hash;
    local array<byte> b;
    //local WebRequest WR;
    const SPECIAL_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

    SHA1 = new(none) class'SHA1Hash';
    hash = SHA1.GetStringHash(WebSocket_Key $ SPECIAL_GUID);

    SHA1.GetHashBytes(b, hash);
    
    return key ~= Base64.Encode(b);
}

simulated function PrepareAuthHeader(string username, string password)
{
    local array<byte> tmp;

    if (username != "") {
        AppendByteStringUTF8(tmp, username);
        tmp.AddItem(Asc(":")); 
        AppendByteStringUTF8(tmp, password);
        
        AuthHeader = "Authorization: Basic" @ Base64.Encode(tmp);
    } else {
        AuthHeader = "";
    }
}

simulated function SendHeader(string s)
{
    SendText(s $ Chr(13) $ Chr(10));
}

simulated function ResponseTimeout()
{
    readyState = CLOSED;
    onerror();
    onclose(false, 0, "Remote host didn't respond");
}

simulated function ReceivedBinaryEx(int count, out byte B[255])
{
    local int i, j;
    i = 0; // right header boundary
    j = 0; // left header boundary
    if (count == 0) return;

    if (readyState == CONNECTING) {
        // HTTP Handshake is still on-going
        if (b[0] == 0x0A && Asc(Right(StringBuffer, 1)) == 0x0D) {
            StringBuffer = Left(StringBuffer, Len(StringBuffer) - 1);
            ReceivedLine(StringBuffer);
            StringBuffer = "";
            i = 1;
            j = 1;
            if (readyState != CONNECTING) goto websocket;
        }
        while (i + 1 < count) {
            if (b[i] == 0x0D && b[i+1] == 0x0A) {
                StringBuffer $= SliceBytes255(b, j, i);
                ReceivedLine(StringBuffer);
                StringBuffer = "";
                j = i + 2;
                if (readyState != CONNECTING) goto websocket;
            }
            i++;
        }
        StringBuffer $= SliceBytes255(b, j, count - 1);
        return;
    }
    // it's no longer HTTP
    websocket:
    
    while (j < count) {
        ReceiveFrameBuffer.AddItem(b[j++]);
    }

    WebSocketStream();
}


// HTTP line, that is
simulated function ReceivedLine(string s) 
{
    local int idx;
    local string error;

    if (s == "") {
        ClearTimer('ResponseTimeout');
        if (readyState == CONNECTING) {
            error = ValidateResponse();
            if (error == "") {
                readyState = OPEN;
                onopen();
            } else {
                onerror();
                Close();
                onclose(false, 0, error);
            }
        }
    } else if (Left(s, 4) ~= "HTTP") {
        ProcessStatusLine(s);
    } else {
        idx = InStr(s, ":");
        ProcessHeader(Left(s, idx), Mid(s, idx+1));
    }
}

simulated function ProcessHeader(string key, string value)
{
    // XXX should I really introduce dependency on UTUIScene?
    value = class'UTGame.UTUIScene'.static.TrimWhitespace(value);

    if (key ~= "Upgrade") {
        bReceivedUpgradeH = value ~= "websocket";
    } else if (key ~= "Connection") {
        bReceivedConnectionH = value ~= "upgrade";
    } else if (key ~= "Sec-WebSocket-Accept") {
        bReceivedAcceptH = CheckWebSocketAccept(value);
    } else if (key ~= "Sec-WebSocket-Extensions") {
        `warn("received extensions header");
    } else if (key ~= "Sec-WebSocket-Protocol" && protocol != "") {
        bProtocolNegotiated = (value == protocol);
    }
}

simulated final function ProcessStatusLine(string s) {
    local int idx;

    idx = InStr(s, " ");

    if (idx == INDEX_NONE) {
        `warn("Invalid status line");
        Close();
    }

    s = Mid(s, idx + 1);

    StatusCode = int(Left(s, 3)); 
    StatusReason = Mid(s, 4); 
}

simulated function string ValidateResponse()
{
    Base64 = None;
    if (StatusCode != 101) {
        return "Status code is" @ StatusCode;
    }
    if (!bReceivedUpgradeH) {
        return "There is no Upgrade header or it doesn't equal to websocket";
    }
    if (!bReceivedConnectionH) {
        return "There is no Connection header or it doesn't equals to Upgrade";
    }
    if (!bReceivedAcceptH) {
        return "Sec-WebSocket-Accept value is incorrect";
    }
    if (!bProtocolNegotiated) {
        return "Couldn't negotiate WebSocket subprotocol";
    }   
    return ""; 
}

simulated function WebSocketStream()
{
    local int opcode;
    local bool bFin;
    local bool bMask;
    local byte MaskingKey[4];
    local int payload_len;

    local int frame_len; 
    local int data_offset;

    local array<byte> Data;
    
    if (ReceiveFrameBuffer.Length < 2) return;

    bFin = (ReceiveFrameBuffer[0] & 0x80) != 0;
    opcode = ReceiveFrameBuffer[0] & 0x0F;
    bMask = (ReceiveFrameBuffer[1] & 0x80) != 0;
    payload_len = ReceiveFrameBuffer[1] & 0x7F;

    frame_len = 2;

    if (payload_len == 126) {
        // extended payload
        frame_len += 2;
        if (ReceiveFrameBuffer.Length < frame_len) {
            return;
        }
        data_offset = frame_len;
        payload_len = Unpack_UInt16(ReceiveFrameBuffer, 2);
        frame_len += payload_len;
        if (ReceiveFrameBuffer.Length < frame_len) {
            return;
        }
    } else if (payload_len == 127) {
        // very extended payload
        if (bDontAcceptLongMessages) {
            `warn("Received a large frame. Aborting.");
            Close();
            return;
        }
        frame_len += 4;
        if (ReceiveFrameBuffer.Length < frame_len) {
            return;
        }
        data_offset = frame_len;
        payload_len = Unpack_Uint64(ReceiveFrameBuffer, 2);
        if (payload_len < 0) {
            `warn("Can't unpack such a long frame");
            Close();
            return;
        }
        frame_len += payload_len;
        if (ReceiveFrameBuffer.Length < frame_len) {
            return;
        }
    } else { // < 126
        data_offset = frame_len;
        frame_len += payload_len; 
    }

    if (bMask) {
        if (ReceiveFrameBuffer.Length < frame_len + 4) {
            return;
        }
        MaskingKey[0] = ReceiveFrameBuffer[data_offset];
        MaskingKey[1] = ReceiveFrameBuffer[data_offset + 1];
        MaskingKey[2] = ReceiveFrameBuffer[data_offset + 2];
        MaskingKey[3] = ReceiveFrameBuffer[data_offset + 3];
        frame_len += 4;
        data_offset += 4;
    }

    if (ReceiveFrameBuffer.Length < frame_len) {
        return;
    }

    if (bMask) {
        WebSocket_Mask(ReceiveFrameBuffer, MaskingKey, data_offset, frame_len);
    }
    
    AppendByteByte(ReceiveDataBuffer, ReceiveFrameBuffer, data_offset, frame_len);
    ReceiveFrameBuffer.Remove(0, frame_len);    

    if (bFin) {
        data_offset = 0; // this variable has new meaning here

        if (opcode == CONTINUATION_FRAME) {
            // fragmented stream ended
            opcode = FragmentedOpcode;
            FragmentedOpcode = -1;
        } else if (FragmentedOpcode != -1) {
            // final packet inside a fragmented stream
            // that can be only unfragmented control packet
            data_offset = ReceiveDataBuffer.Length - payload_len;
        }
        
        AppendByteByte(Data, ReceiveDataBuffer, data_offset, ReceiveDataBuffer.Length);
        // only a matter of optimization
        if (data_offset == 0) {
            ReceiveDataBuffer.Length = 0;
        } else {
            ReceiveDataBuffer.Remove(data_offset, ReceiveDataBuffer.Length - data_offset);
        }

        switch(opcode) {
        case TEXT_FRAME:
            OnTextFrame(SliceBytesUTF8(Data, 0, Data.Length));
            break;
        case BINARY_FRAME:
            OnBinaryFrame(Data);
            break;
        case CONN_CLOSE_FRAME:
            OnCloseFrame(Data);
            break;
        case PING_FRAME:
            OnPingFrame(Data);
            break;
        case PONG_FRAME:
            OnPongFrame(Data);
            break;
        default:
            `warn("Unknown opcode" @ opcode);
            break;
        }
    } else {
        // a part of fragmented stream
        if (FragmentedOpcode == -1){
            // moreover, its first frame
            FragmentedOpcode = opcode;
        } else if (opcode != CONTINUATION_FRAME) {
            `warn("Non-final non-continuation packet inside fragmented stream. Aborting.");
            Close();
        }
        // else: data already appended to the buffer, do nothing
    }
}

simulated function OnTextFrame(string s)
{
    onmessage(s);
}

simulated function OnBinaryFrame(const out array<byte> b)
{
    
}

simulated function OnCloseFrame(const out array<byte> b)
{
    local array<byte> a;
    if (readyState == OPEN) {
        SendFrame(CONN_CLOSE_FRAME, a);
    } 
    Close();
}

simulated function OnPingFrame(const out array<byte> b)
{
    SendFrame(PONG_FRAME, b);
}

simulated function OnPongFrame(const out array<byte> b)
{
    
}


simulated function SendFrame(byte opcode, const out array<byte> b)
{
    local byte mask[4];
    local byte tmp[255];
    local byte tmp_len;
    local int i, offset;

    SendDataBuffer.Length = 0;
    
    SendDataBuffer.AddItem(0x80 | (opcode & 0x0F));
    SendDataBuffer.AddItem(0x80); // mask + payload

    if (b.Length < 126) {
        SendDataBuffer[1] = SendDataBuffer[1] | b.Length;
    } else if (b.Length <= 0xFFFF) {
        SendDataBuffer[1] = SendDataBuffer[1] | 126;
        Pack_UInt16(SendDataBuffer, SendDataBuffer.Length, b.Length);
    } else {
        SendDataBuffer[1] = SendDataBuffer[1] | 127;
        Pack_UInt64(SendDataBuffer, SendDataBuffer.Length, b.Length);
    }

    GenerateMask(mask);

    SendDataBuffer.AddItem(mask[0]);
    SendDataBuffer.AddItem(mask[1]);
    SendDataBuffer.AddItem(mask[2]);
    SendDataBuffer.AddItem(mask[3]);

    AppendByteByte(SendDataBuffer, b, 0, b.Length);

    WebSocket_Mask(SendDataBuffer, mask, SendDataBuffer.Length - b.Length, SendDataBuffer.Length);
    
    offset = 0;
    while (offset < SendDataBuffer.Length) {
        tmp_len = Min(255, SendDataBuffer.Length - offset);
        for (i = 0; i < tmp_len; i++) {
            tmp[i] = SendDataBuffer[i + offset];
        }
        SendBinary(tmp_len, tmp);
        offset += tmp_len;
    }
}

static  final function string SliceBytes255(const out byte b[255], int from, int to)
{
    local string s;
    while (from < to) {
        s $= Chr(b[from++]);
    }
    return s;
}

static final function string SliceBytes(const out array<byte> b, int from, int to)
{
    local string s;
    while (from < to) {
        s $= Chr(b[from++]);
    }
    return s;
}

static final function string SliceBytesUTF8(const out array<byte> b, int from, int to)
{
    local string s;


    while (from < to) {
        s $= Chr(b[from++]);
    }

    return s;
}

static final function AppendByteString(out array<byte>b, out const string s)
{
    local int i, l;
    l = Len(s);
    for (i = 0; i < l; i++) {
        b.AddItem(Asc(Mid(s, i, 1)));
    }
}

/*
Borrowed from libiconv, lib/utf8.h, utf8_wctomb
*/
static simulated final function AppendByteStringUTF8(out array<byte> b, out const string s)
{
    local int length, i, wc, count;
    local int j;
    
    length = Len(s);
    
    for (i = 0; i < length; i++) {
        wc = Asc(Mid(s, i, 1));
        if (wc < 0x80) {
            count = 1;
        } else if (wc < 0x800)
            count = 2;
        else if (wc < 0x10000)
            count = 3;
        else if (wc < 0x200000)
            count = 4;
        else if (wc < 0x4000000)
            count = 5;
        else if (wc <= 0x7fffffff)
            count = 6;

        j = b.Length;
        
        switch (count) { /* note: code falls through cases! */
            case 6: b[j+4] = 0x80 | (wc & 0x3f); wc = wc >> 6; wc = wc | 0x4000000;
            case 5: b[j+3] = 0x80 | (wc & 0x3f); wc = wc >> 6; wc = wc | 0x200000;
            case 4: b[j+3] = 0x80 | (wc & 0x3f); wc = wc >> 6; wc = wc | 0x10000;
            case 3: b[j+2] = 0x80 | (wc & 0x3f); wc = wc >> 6; wc = wc | 0x800;
            case 2: b[j+1] = 0x80 | (wc & 0x3f); wc = wc >> 6; wc = wc | 0xc0;
            case 1: b[j  ] = wc;
        }
    }
}

static final function AppendByteByte(out array<byte> to, const out array <byte> from, int i, int j)
{
    while (i < j) {
        to.AddItem(from[i++]);
    }
}

static final function int Unpack_Int32(const out array<byte> b, int i) 
{
    return 
        b[i]     << 24 |
        b[i + 1] << 16 |
        b[i + 2] << 8  |
        b[i + 3];
}

static final function Pack_Int32(out array<byte> b, int i, int number)
{
    b[i]   = number >> 24;
    b[i+1] = number >> 16;
    b[i+2] = number >> 8;
    b[i+3] = number;
}

static final function Pack_UInt64(out array<byte> b, int i, int number)
{
    b[i] = 0;
    b[i+1] = 0;
    b[i+2] = 0;
    b[i+3] = 0;
    Pack_Int32(b, i + 4, number);
}

static final function int Unpack_UInt64(const out array<byte> b, int i)
{   
    if (b[i+3] != 0 || b[i+2] != 0 || b[i+1] != 0 || b[i] != 0) {
        return -1; // can't handle it
    }
    if ((b[i+4] & 0x80) != 0) {
        return -1; // we're unpacking into int32 (requires uint32)
    }
    return Unpack_Int32(b, i+4);
}

static final function int Unpack_UInt16(const out array<byte> b, int i)
{
    return
        b[i] << 8 |
        b[i + 1];
}

static final function Pack_UInt16(out array<byte> b, int i, int number)
{
    b[i]   = number >> 8;
    b[i+1] = number;
}

static final function WebSocket_Mask(out array<byte> b, byte mask[4], int from, int to)
{
    local int i;
    for (i = from; i < to; i++) {
        // '& 0x3' is equivalent to '% 4'
        b[i] = b[i] ^ mask[(i - from) & 0x3];
    }
}

defaultproperties
{
    Timeout=10.0
    bSendUserAgent=true
    TickGroup=TG_DuringAsyncWork
    FragmentedOpcode=-1
    bDontAcceptLongMessages=true
}
