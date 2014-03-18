/*
   StatusReporter
   Copyright (C) 2012 Maxim "WGH"
   
   This program is free software; you can redistribute and/or modify 
   it under the terms of the Open Unreal Mod License version 1.1.
*/
class StatusReporter_MutSettings extends Settings;

function SetSpecialValue(name PropertyName, string NewValue)
{
    super.SetSpecialValue(PropertyName, NewValue);

    if (PropertyName == 'WebAdmin_Init') {
        WebAdmin_Init();
    } else if (PropertyName == 'WebAdmin_Save') {
        WebAdmin_Save();
    } else if (PropertyName == 'WebAdmin_Cleanup') {
        WebAdmin_Cleanup(); 
    }
}

function string GetSpecialValue(name PropertyName)
{
    // a hack: GetSpecialValue('WebAdmin_groups') is called each time 
    // WebAdmin renders settings

    if (PropertyName == 'WebAdmin_Groups') {
        
    }

    return super.GetSpecialValue(PropertyName);
}

function WebAdmin_Cleanup()
{
}

function WebAdmin_Init()
{
    SetIntProperty(0, int(class'StatusReporter.StatusReporter_Mut'.default.bEnable));
    SetStringProperty(1, class'StatusReporter.StatusReporter_Mut'.default.URL);
}

function WebAdmin_Save()
{
    local int tmp;
    local Actor ActorRef;
    local StatusReporter_Mut M;

    GetIntProperty(0, tmp);
    class'StatusReporter.StatusReporter_Mut'.default.bEnable = (tmp != 0);

    GetStringProperty(1, class'StatusReporter.StatusReporter_Mut'.default.URL);
    
    class'StatusReporter.StatusReporter_Mut'.static.StaticSaveConfig();

    // a terrible hack borrowed from TTF
    ActorRef = Actor(FindObject("Engine.Default__Actor", Class'Actor'));

    if (ActorRef != None) {
        foreach ActorRef.DynamicActors(class'StatusReporter.StatusReporter_Mut', M) {
            M.DefaultsUpdated(); 
        }
    }

}

defaultproperties
{
    Properties(0)=(PropertyID=0,Data=(Type=SDT_Int32))
    Properties(1)=(PropertyID=1,Data=(Type=SDT_String))
    
    PropertyMappings(0)=(ID=0,Name="bEnable",ColumnHeaderText="Enable",MappingType=PVMT_IDMapped,ValueMappings=((ID=0,Name="No"),(ID=1,Name="Yes")))
    PropertyMappings(1)=(ID=1,Name="URL",ColumnHeaderText="URL",MaxVal=128)
}
