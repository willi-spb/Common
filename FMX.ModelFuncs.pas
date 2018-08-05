unit FMX.ModelFuncs;

interface

uses System.Classes,FMX.Controls, FMX.Controls.Presentation, FMX.Controls.Model;

function FindPresentedControlForTag(const aParent:TControl; aTag:Integer):TPresentedControl;
function FindPresentedControlForClassAndTag(const aParent:TControl; aClass:TClass; aTag:Integer):TPresentedControl;
function FindFirstPresentedControl(const aParent:TControl; const AModelPropName,AValue:string):TPresentedControl;

procedure CopyModelData(aSrc,aDest:TPresentedControl; aClearDestFlag:Boolean=false);
procedure CopyModelDataFromParent(aSrcParent,aDestParent:TControl; aSelfCopyFlag:Boolean; aClearDestFlag:Boolean=true);

// procedure SetLookupDataToModel(aCtrl:TPresentedControl; const aLookupValue:Variant; const aKeyName:String='LookupValue');

/// <summary>
///    set Model.Data[AFieldName]=aValue  ATagComma>>  1=ID,2=FName,3=DESCRIPT an e.t.)
/// </summary>
procedure SetModelStringForTagControls(aSrcParent:TControl; const ATagCommaValues:string; const AFieldName:string='FieldName');

implementation

uses  System.SysUtils, System.Generics.Collections, System.Rtti;

function FindPresentedControlForTag(const aParent:TControl; aTag:Integer):TPresentedControl;
var i:Integer;
    LPC:TPresentedControl;
 begin
   Result:=nil;
   i:=0;
   while i<aParent.ControlsCount do
    begin
      if aParent.Controls[i] is TPresentedControl then
         begin
           LPC:=TPresentedControl(aParent.Controls[i]);
           if LPC.Tag=aTag then
              begin
                Result:=LPC;
                Break;
              end;
         end;
      Inc(i);
    end;
 end;

function FindPresentedControlForClassAndTag(const aParent:TControl; aClass:TClass; aTag:Integer):TPresentedControl;
var i:Integer;
    LPC:TPresentedControl;
 begin
   Result:=nil;
   i:=0;
   while i<aParent.ControlsCount do
    begin
      if aParent.Controls[i] is TPresentedControl then
         begin
           LPC:=TPresentedControl(aParent.Controls[i]);
           if (LPC.Tag=aTag) and (aClass=LPC.ClassType) then
              begin
                Result:=LPC;
                Break;
              end;
         end;
      Inc(i);
    end;
 end;

function FindFirstPresentedControl(const aParent:TControl; const AModelPropName,AValue:string):TPresentedControl;
var i:Integer;
    LPC:TPresentedControl;
 begin
   Result:=nil;
   i:=0;
   while i<aParent.ControlsCount do
    begin
      if aParent.Controls[i] is TPresentedControl then
         begin
           LPC:=TPresentedControl(aParent.Controls[i]);
           if (LPC.Model.Data[AModelPropName].IsEmpty=False) and
              (LPC.Model.Data[AModelPropName].AsString=AValue) then
              begin
                Result:=LPC;
                Break;
              end;
         end;
      Inc(i);
    end;
 end;



procedure CopyModelData(aSrc,aDest:TPresentedControl; aClearDestFlag:Boolean=false);
var LKeyStr:string;
    LV:TValue;
 begin
   if (aClearDestFlag=true) and (Assigned(aDest.Model.DataSource)) then
      aDest.Model.DataSource.Clear;
   if Assigned(aSrc.Model.DataSource) then
     for LKeyStr in aSrc.Model.DataSource.Keys do
      begin
         LV:=TValue.Empty;
         aSrc.Model.DataSource.TryGetValue(LKeyStr,LV);
         if not(LV.IsEmpty) then
           aDest.Model.Data[LKeyStr]:=LV;
         /// NO! ->  aDest.Model.DataSource.AddOrSetValue(LKeyStr,LV);
      end;
 end;

procedure CopyModelDataFromParent(aSrcParent,aDestParent:TControl; aSelfCopyFlag:Boolean; aClearDestFlag:Boolean=true);
var LsrcCtrl,LDestCtrl:TPresentedControl;
    i:Integer;
  begin
   if (aSelfCopyFlag=True) and (aSrcParent is TPresentedControl) and (aDestParent is TPresentedControl) then
      CopyModelData(TPresentedControl(aSrcParent),TPresentedControl(aDestParent),False);
   i:=0;
   while i<aSrcParent.ControlsCount do
    begin
      if aSrcParent.Controls[i] is TPresentedControl then
         begin
           LsrcCtrl:=TPresentedControl(aSrcParent.Controls[i]);
           if (LsrcCtrl.Tag>0) then
              begin
                LDestCtrl:=FindPresentedControlForClassAndTag(aDestParent,LsrcCtrl.ClassType,LsrcCtrl.Tag);
                if Assigned(LDestCtrl) then
                   CopyModelData(LsrcCtrl,LDestCtrl,aClearDestFlag);
              end;
         end;
      Inc(i);
    end;
  end;

{
procedure SetLookupDataToModel(aCtrl:TPresentedControl; const aLookupValue:Variant; const aKeyName:String='LookupValue');
 begin
   aCtrl.Model.Data[aKeyName].FromVariant(aLookupValue);
 end;
}

procedure SetModelStringForTagControls(aSrcParent:TControl; const ATagCommaValues:string; const AFieldName:string='FieldName');
 var LList:TStrings;
     LPCtrl:TPresentedControl;
     i,LIndex:Integer;
  begin
   LLIst:=TStringList.Create;
   try
    LList.CommaText:=ATagCommaValues;
    i:=0;
    while i<aSrcParent.ControlsCount do
     begin
       if aSrcParent.Controls[i] is TPresentedControl then
        begin
          LPCtrl:=TPresentedControl(aSrcParent.Controls[i]);
          if (LPCtrl.Tag<>0) then
            begin
              LIndex:=LList.IndexOfName(IntToStr(LPCtrl.Tag));
              if (LIndex>=0) then
                begin
                  LPCtrl.Model.Data[AFieldName]:=LList.ValueFromIndex[LIndex];
                end;
            end;
        end;
       Inc(i);
     end;
   finally
     LList.Free;
   end;
  end;

end.
