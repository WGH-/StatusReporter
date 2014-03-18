StatusReporter

A WebSocket server status reporter for UT3.

Author: WGH, wgh@torlan.ru
18.03.2014

== Introduction ==
Basically, it's a WebSocket client implemented in UnrealScript, that connects
to a predefined WebSocket server and then pushes updates regarding server
status: player count and their names, map names, scores, etc. It's kind of 
query protocol, but reversed: it's not something else that polls the game 
server about its status, it's the server itself that pushes status updates. 
It can be considered a push technology.

The main advantage of this approach is that updates are pushed immediately, 
without any delay. For example, as soon as someone joins the server, 
it pushes an update. So you can use it, for example, to display player list
in real time, like here - http://status.torlan.ru/war/ (the source code of 
this site is NOT provided).

Again, note that this's a WebSocket client only. You'll also need a WebSocket
server that your game server and web browsers will connect to. 

An example Python program (requires Python 3 and Tornado) that this mutator 
can connect to is included in Misc directory. Program prints received updates 
to the standard output. It doesn't have to run on the same machine that game
server does.

== Installation ==
Due to a bug, only Windows dedicated servers are supported.
http://forums.epicgames.com/threads/604619-TCPLink-amp-Linux

Contents of Script directory go anywhere in \Documents\My Games\Unreal Tournament 3\UTGame\Published\CookedPC.
Contents of Config directory go in \Documents\My Games\Unreal Tournament 3\UTGame\Config

Once it's done, mutator will be listed in the usual mutator list.
Class path is "StatusReporter.StatusReporter_Mut".

The package is not pushed to clients, so you don't need to put in on the redirect server.
It's also not required for demo playback.

== Configuration ==
The mutator is fully configurable through WebAdmin.

You can also configure it through the config file UTStatusReporter.ini:

[StatusReporter.StatusReporter_Mut]
; On/off switch
bEnable=True
; WebSocket server URL
URL=ws://localhost:8080/websocket 

URL must always begin with ws://. It may contain username and password,
those will be used in HTTP basic access authentication.
For example, ws://user:password@example.org/websocket

== Protocol ==
The mutator sends text WebSocket frames encoded in UTF-8, containing JSON data.
Each JSON object always contains complete server info (i.e. there's no "delta coding").

For the contents of JSON object, please consult the StatusReporter.uc from the source code.

== Source code ==
Source code is provided under terms of the Open Unreal Mod License, and is available on GitHub: https://github.com/WGH-/StatusReporter


