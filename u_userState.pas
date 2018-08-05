unit u_userState;
///  класс для упаковки-распаковки строки состояния программы
interface

 uses System.Types, System.UITypes, System.Classes, System.Variants,
      FMX.Types,System.Rtti,
      System.Generics.Collections,
      FireDAC.Comp.Client;

 type
  TUserAppSaveRegime=(uas_State,uas_Model);
  TUserAppSaveRegimes=set of TUserAppSaveRegime;
  const uasr_All=[uas_State,uas_Model];
 type
  TUserAppState=class(TComponent)
   private
     FSuffixUsed:Boolean;
     FConn:TFDConnection;
     FID:Integer;
     FUserID,FAppID:Integer;
     FTableName:string;
     FFillFlag:Boolean;
   protected
     procedure FromJSON(const AStr:string; const aDict:TDictionary<String,TValue>);
     function ToJSON(const aDict:TDictionary<String,TValue>):string;
   public
    Items:TDictionary<String,TValue>;
    ModelData:TDictionary<String,TValue>;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AssignDbParams(aUserId,aAppId:Integer;
        const aConn:TFDConnection; const aTableName:string);
    ///
    function FillFromDB(aUReg:TUserAppSaveRegimes=[uas_State]):Integer; virtual;
    function SaveToDB(aUReg:TUserAppSaveRegimes=[uas_State]):boolean; virtual;
    ///
    function ToListText(const ADict:TDictionary<String,TValue>):string;
    ///
    property ID:Integer read FID;
    property UserId:Integer read FUserID;
    property AppId:Integer read FAppID;
    property TableName:string read FTableName;
    property FilledFlag:Boolean read FFillFlag;
    ///
    /// <summary>
    ///   true - к названиям состояний и состояний модели перед маршаллингом
    ///   обавляется суффикс типа AAA -> AAA_int   BBB -> BBB_ustr,
    ///   при загрузке словарей из JSON - если true - выкидывается суффикс из названия,
    ///   а TValue меняет свой Kind на тип из суффикса - рекомендуется для точной передачи типов,
    ///   т.к. в JSON нет явного указания типа для пар
    ///  (false - по умолчанию)
    /// </summary>
    property SuffixUsed:Boolean read FSuffixUsed write FSuffixUsed;
   end;

implementation

 uses System.SysUtils,
      System.JSON,
      wDBXJsonMarshal;

function ExtractSuffix(const AStr:string):string;
var i:Integer;
 begin
   Result:='';
   i:=Length(AStr);
   while (i>0) do
    begin
      if (AStr[i]='_') and (i<Length(AStr)) then
         begin
           Result:=Copy(AStr,i+1,Length(AStr)-i);
           Break;
         end;
      Dec(i);
    end;
 end;

 function RemoveSuffix(const AStr:string):string;
var i:Integer;
 begin
   Result:=AStr;
   i:=Length(AStr);
   while (i>0) do
    begin
      if (AStr[i]='_') and (i>1) then
         begin
           Result:=Copy(AStr,1,i-1);
           Break;
         end;
      Dec(i);
    end;
 end;

/// сохранять-загружать поля с указанием типа в названии
function GetKindFromSuffix(const aSfx:string):TTypeKind;
var LSfx:string;
 begin
   LSfx:=LowerCase(Trim(aSfx));
   if LSfx='' then Exit(tkUnknown);
   if (LSfx='int') then Exit(tkInteger);
   if (LSfx='char') or (LSfx='ch') then Exit(tkChar);
   if (LSfx='en') or (LSfx='enum') then Exit(tkEnumeration);
   if (LSfx='f') or (LSfx='fl') or (LSfx='float') then Exit(tkFloat);
   if (LSfx='s') or (LSfx='st') or (LSfx='str') then Exit(tkString);
   if (LSfx='set') then Exit(tkSet);
   if (LSfx='class') then Exit(tkClass);
   if (LSfx='method') then Exit(tkMethod);
   if (LSfx='wchar') or (LSfx='wch') then Exit(tkWChar);
   if (LSfx='lstr') then Exit(tkLString);
   if (LSfx='wstr') then Exit(tkWString);
   if (LSfx='v') or (LSfx='var') then Exit(tkVariant);
   if (LSfx='a') or (LSfx='ar') then Exit(tkArray);
   if (LSfx='rec') or (LSfx='rc') then Exit(tkRecord);
   if (LSfx='inter') or (LSfx='interface') then Exit(tkInterface);
   if (LSfx='i64') or (LSfx='int64') then Exit(tkInt64);
   if (LSfx='da') then Exit(tkDynArray);
   if (LSfx='us') or (LSfx='ust') or (LSfx='ustr') then Exit(tkUString);
   if (LSfx='cref') then Exit(tkClassRef);
   if (LSfx='pt') then Exit(tkPointer);
   if (LSfx='proc') then Exit(tkProcedure);
 end;

 function GetSuffixFromKind(const aV:TValue):string;
  begin
    Result:='';
    case aV.Kind of
      tkUnknown: Result:='';
      tkInteger: Result:='int';
      tkChar: Result:='char';
      tkEnumeration: Result:='enum';
      tkFloat: Result:='fl';
      tkString: Result:='st';
      tkSet:  Result:='set';
      tkClass: Result:='class';
      tkMethod: Result:='method';
      tkWChar: Result:='wchar';
      tkLString: Result:='lstr';
      tkWString: Result:='wstr';
      tkVariant: Result:='var';
      tkArray: Result:='ar';
      tkRecord: Result:='rec';
      tkInterface: Result:='inter';
      tkInt64: Result:='int64';
      tkDynArray: Result:='da';
      tkUString: Result:='ustr';
      tkClassRef: Result:='cref';
      tkPointer: Result:='pt';
      tkProcedure: Result:='proc';
    end;
  end;

 function SetValueKind(const aV:TValue; aKind:TTypeKind):TValue;
  begin
    case aV.Kind of
      tkInteger: Result:=aV.AsInteger;
      tkChar: Result:=aV.AsString;
      tkFloat: Result:=aV.AsExtended;
      tkString: Result:=aV.AsString;
      tkClass: Result:=av.AsClass;
      tkWChar: Result:=av.ToString;
      tkLString: Result:=av.ToString;
      tkWString: Result:=av.ToString;
      tkVariant: Result.FromVariant(av.AsVariant);
      tkInt64: Result:=av.AsInt64;
      tkUString: Result:=av.ToString;
    end;
  end;

{ TUserAppState }

procedure TUserAppState.AssignDbParams(aUserId, aAppId: Integer;
  const aConn: TFDConnection; const aTableName: string);
begin
  FUserID:=aUserId;
  FAppID:=aAppId;
  FConn:=aConn;
  FTableName:=aTableName;
end;

constructor TUserAppState.Create(AOwner: TComponent);
begin
  inherited;
  FSuffixUsed:=False;
  FFillFlag:=False;
  FID:=0;
  FUserID:=0;
  FAppID:=0;
  Items:=TDictionary<String,TValue>.Create;
  ModelData:=TDictionary<String,TValue>.Create;
end;

destructor TUserAppState.Destroy;
begin
  Items.Free;
  ModelData.Free;
  inherited;
end;

function TUserAppState.FillFromDB(aUReg:TUserAppSaveRegimes): Integer;
 var LS,LMS:string;
     LFQ:TFDQuery;
begin
 Result:=0;
 LS:=''; LMS:='';
 LFQ:=TFDQuery.Create(nil);
 try
   LFQ.Connection:=FConn;
   LFQ.SQL.Text:='SELECT * FROM '+FTableName+' WHERE (USER_ID='+
      IntToStr(FUserId)+') AND (APP_ID='+IntToStr(FAppId)+');';
   try
    LFQ.Open;
    if (LFQ.FieldByName('ID').IsNull=False) then
     begin
      if (LFQ.FieldByName('STATE').IsNull=False) then
         LS:=LFQ.FieldByName('STATE').AsWideString;
      if (LFQ.FieldByName('MODEL_STATE').IsNull=False) then
          LMS:=LFQ.FieldByName('MODEL_STATE').AsWideString;
     end;
    if uas_State in aUReg then
     begin
       Items.Clear;
       Self.FromJSON(LS,Items);
     end;
    if uas_Model in aUReg then
     begin
      ModelData.Clear;
      Self.FromJSON(LMS,ModelData);
     end;
    except on E:Exception do
      begin

      end;
   end;
 finally
   LFQ.Free;
 end;
end;

procedure TUserAppState.FromJSON(const AStr: string;
  const aDict: TDictionary<String, TValue>);
var JSONObject:TJSONObject;
    JsonPair:TJSONPair;
    i:Integer;
    LStr,LSfx:string;
    L_TK:TTypeKind;
    LValue:TValue;
begin
  JSONObject:=nil;
  if Astr<>'' then
   begin
    try
      LStr:=AStr;
      JSONObject:=TJSONObject.ParseJSONValue(LStr) as TJSONObject;
     except
       JSONObject:=nil;
    end;
    if Assigned(JSONObject) then
       try
        I:=0;
        while i<JSONObject.Count do
          begin
            JsonPair:=JSONObject.Pairs[I];
            LStr:=JsonPair.JsonString.Value;
          //  LValue:=JsonPair.JsonValue.Value;
            LValue:=TwDBXJsonmarshal.ValueFromJson(JsonPair.JsonValue);
            ///
            if FSuffixUsed then
             begin
               LSfx:=ExtractSuffix(LStr);
               L_TK:=GetKindFromSuffix(LSfx);
               if L_TK<>TTypeKind.tkUnknown then
                begin
                 LValue:=SetValueKind(LValue,L_TK);
                 LStr:=RemoveSuffix(LStr);
                end;
             end;
           // LValue:=TValue.Empty;
           // JsonPair.JsonValue.TryGetValue(LValue);
            aDict.AddOrSetValue(LStr,LValue);
            Inc(i);
          end;
       finally
         JSONObject.Free;
       end;
   end;
end;

function TUserAppState.ToListText(const ADict:TDictionary<String,TValue>): string;
var LList:TStringList;
    LS:string;
begin
  LList:=TStringList.Create;
  try
    for LS in ADict.Keys do
      LList.Add(LS+'='+ADict.Items[LS].ToString);
    Result:=LList.Text;
  finally
    LList.Free;
  end;
end;

function TUserAppState.SaveToDB(aUReg:TUserAppSaveRegimes): boolean;
 var LSQL,LStr,LModelStr:string;
     LFQ:TFDQuery;
     LID:Integer;
begin
  Result:=False;
  LFQ:=TFDQuery.Create(nil);
  try
   LFQ.Connection:=FConn;
   try
    LFQ.Open('SELECT ID,STATE,MODEL_STATE FROM '+FTableName+' WHERE (USER_ID='+
      IntToStr(FUserId)+') AND (APP_ID='+IntToStr(FAppId)+');');
    if (LFQ.FieldByName('ID').IsNull=false) and
       (LFQ.FieldByName('ID').AsInteger>0) then
        LID:=LFQ.FieldByName('ID').AsInteger
    else LID:=0;
    ///
    if (LID>0) and (LFQ.FieldByName('STATE').IsNull=false) then
       LStr:=LFQ.FieldByName('STATE').AsWideString
    else LStr:='';
    if (LID>0) and (LFQ.FieldByName('MODEL_STATE').IsNull=false) then
       LModelStr:=LFQ.FieldByName('MODEL_STATE').AsWideString
    else LModelStr:='';
    ///
    LFQ.Close;
    ///
    if uas_State in aUReg then
       LStr:=Self.ToJSON(Items);
    if uas_Model in aUReg then
       LModelStr:=Self.ToJSON(ModelData);
    ///
    if LID=0 then
       LSQL:=Format('INSERT INTO '+FTableName+' (ID,USER_ID,APP_ID,STATE,MODEL_STATE) '+
                             'VALUES (%d,%d,%d,''%s'',''%s'');', //select last_insert_id();',
                             [0,FUserId,FAppID,LStr,LModelStr])
    else
       LSQL:='Update '+FTableName+' SET STATE='''+LStr+''', MODEL_STATE='''+LModelStr+''''+
            ' WHERE (ID='+IntToStr(LId)+');';
    ///
    LFQ.SQL.Text:=LSQL;
    LFQ.ExecSQL;
    Result:=True;
    ///
    except on E:Exception do
      begin
        Result:=False;
      end;
   end;
 finally
   LFQ.Free;
 end;
end;

function TUserAppState.ToJSON(const aDict: TDictionary<String, TValue>): string;
 var JSONObject:TJSONObject;
    JsonPair:TJSONPair;
    LJVal:TJSONValue;
    JPList:TList<TJSONPair>;
    i:Integer;
    LValue:TValue;
    LStr,LName,LSfx:string;
    L_TK:TTypeKind;
begin
  Result:='';
  JSONObject:=TJSONObject.Create;
  JPList:=TList<TJSONPair>.Create;
  try
    for LStr in Items.Keys do
      if LStr<>'' then
       begin
        LName:=LStr;
        LValue:=TValue.Empty;
        aDict.TryGetValue(LStr,LValue);
        if LValue.IsEmpty=false then
         begin
          if FSuffixUsed then
             begin
               //
               LSfx:=GetSuffixFromKind(LValue);
               L_TK:=GetKindFromSuffix(LSfx);
               if L_TK<>TTypeKind.tkUnknown then
                begin
                  LValue:=SetValueKind(LValue,GetKindFromSuffix(LSfx));
                  LName:=Concat(LName,'_',LSfx);
                end;
             end;
          LJVal:=TwDBXJsonMarshal.ToJson(LValue);
          JsonPair:=TJSONPair.Create(LName,LJVal);
          JPList.Add(JsonPair);
         end;
       end;
     JSONObject.SetPairs(JPList);
     Result:=JSON_CorrectStringValue(JSONObject.ToString);
    finally
     JSONObject.Free;
  end;
end;

end.
