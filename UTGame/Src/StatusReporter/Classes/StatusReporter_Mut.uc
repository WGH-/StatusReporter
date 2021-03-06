/*
   StatusReporter
   Copyright (C) 2012-2014 Maxim "WGH"
   
   This program is free software; you can redistribute and/or modify 
   it under the terms of the Open Unreal Mod License version 1.1.
*/
class StatusReporter_Mut extends UTMutator
    config(StatusReporter);

var config bool bEnable;
var config string URL;

var transient StatusReporter StatusReporter;

function InitMutator(string Options, out string ErrorMessage) 
{
    super.InitMutator(Options, ErrorMessage);

    foreach DynamicActors(class'StatusReporter.StatusReporter', StatusReporter) {
        break;
    }

    CreateReporterInstance();

    if (StatusReporter != None && !StatusReporter.bDeleteMe) {
        StatusReporter.InitMutator();
    }
}

function CreateReporterInstance()
{
    if (bEnable) {
        if (StatusReporter == None) {
            StatusReporter = Spawn(class'StatusReporter.StatusReporter');
        }   
    } else {
        if (StatusReporter != None && !StatusReporter.bDeleteMe) {
            StatusReporter.Destroy();
            StatusReporter = None;
        }
    }
}

function DefaultsUpdated()
{
    if (default.URL != URL || default.bEnable != bEnable) {
        if (default.URL != URL) {
            if (StatusReporter != None) {
                StatusReporter.Destroy();
                StatusReporter = None;
            }
            URL = default.URL;
        }

        CreateReporterInstance();
    }
}

function GetSeamlessTravelActorList(bool bToEntry, out array<Actor> ActorList)
{
    super.GetSeamlessTravelActorList(bToEntry, Actorlist);

    if (StatusReporter != None) {
        ActorList.AddItem(StatusReporter);
        if (StatusReporter.WS != None) {
            ActorList.AddItem(StatusReporter.WS);
        }
    }
}

function NotifyLogin(Controller NewPlayer)
{
    Super.NotifyLogin(NewPlayer);
    
    if (StatusReporter != None) {
        StatusReporter.NotifyLogin(NewPlayer);
    }
}

function NotifyLogout(Controller Exiting) {
    super.NotifyLogout(Exiting);

    
    if (StatusReporter != None) {
        StatusReporter.NotifyLogout(Exiting);
    }
}

function NotifyBecomeActivePlayer(PlayerController PC) {
    super.NotifyBecomeActivePlayer(PC);

    if (StatusReporter != None) {
        StatusReporter.NotifyBecomeActivePlayer(PC);
    }
}

function NotifyBecomeSpectator(PlayerController PC) {
    super.NotifyBecomeSpectator(PC);

    if (StatusReporter != None) {
        StatusReporter.NotifyBecomeSpectator(PC);
    }
}
