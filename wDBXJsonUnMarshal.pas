unit wDBXJsonUnMarshal;

interface

uses Rtti, TypInfo, DBXJson,  Json;

type
  TwDBXJsonUnmarshal = class
  private
    FContext: TRttiContext;

    function GetPair(AJSONObject: TJSONObject;const APairName: UnicodeString): TJSONPair;

    function CreateInstance(ATypeInfo: PTypeInfo): TValue;
    function IsList(ATypeInfo: PTypeInfo): Boolean;
    function IsParameterizedType(ATypeInfo: PTypeInfo): Boolean;
    function GetParameterizedType(ATypeInfo: PTypeInfo): TRttiType;
    function GetFieldDefault(AField: TRttiField; AJsonPair: TJSONPair; var AOwned: Boolean): TJSONValue;

    function FromJson(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;overload;

    function FromClass(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
    function FromRecord(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
    function FromList(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
    function FromString(const AJSONValue: TJSONValue): TValue;
    function FromInt(ATypeInfo: PTypeInfo; const AJSONValue: TJSONValue): TValue;
    function FromInt64(ATypeInfo: PTypeInfo; const AJSONValue: TJSONValue): TValue;
    function FromFloat(ATypeInfo: PTypeInfo; const AJSONValue: TJSONValue): TValue;
    function FromChar(const AJSONValue: TJSONValue): TValue;
    function FromWideChar(const AJSONValue: TJSONValue): TValue;
    function FromSet(ATypeInfo: PTypeInfo; const AJSONValue: TJSONValue): TValue;
  public
    constructor Create;
    destructor Destroy; override;

    class function FromJson<T>(AJSONValue: TJSONValue): T;overload;
    class function FromJson<T>(const AJSON: string): T;overload;
    class function FromJson(AClassType: TClass; const AJSON: string): TObject;overload;
    ///
    class function ValueFromJson(AJSONValue: TJSONValue):TValue;
  end;

implementation

uses SysUtils, StrUtils, DateUtils;

{ TDBXJsonUnmarshal }

constructor TwDBXJsonUnmarshal.Create;
begin
  FContext := TRttiContext.Create;
end;

function TwDBXJsonUnmarshal.CreateInstance(ATypeInfo: PTypeInfo): TValue;
var
  rType: TRttiType;
  mType: TRTTIMethod;
  metaClass: TClass;
begin
  rType := FContext.GetType(ATypeInfo);
  if ( rType <> nil ) then
  begin
    for mType in rType.GetMethods do
    begin
      if mType.HasExtendedInfo and mType.IsConstructor and (Length(mType.GetParameters) = 0) then
      begin
        metaClass := rType.AsInstance.MetaclassType;
        exit(mType.Invoke(metaClass, []).AsObject);
      end;
    end;
  end;
  raise Exception.CreateFmt('No default constructor found for clas "%s".', [GetTypeData(ATypeInfo).ClassType.ClassName]);
end;

destructor TwDBXJsonUnmarshal.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TwDBXJsonUnmarshal.FromChar(const AJSONValue: TJSONValue): TValue;
begin
  Result := TValue.Empty;
  if (AJSONValue is TJsonString) and (Length(TJSONString(AJSONValue).Value) = 1) then
  begin
    Result := TJsonString(AJSONValue).Value[1];
  end;
end;

function TwDBXJsonUnmarshal.FromClass(ATypeInfo: PTypeInfo;AJSONValue: TJSONValue): TValue;
var
  f: TRttiField;
  v, vCast: TValue;
  vFieldPair: TJSONPair;
  vOldValue: TValue;
  vJsonValue: TJSONValue;
  vOwnedJsonValue: Boolean;
begin
  if AJSONValue is TJsonObject then
  begin
    Result := CreateInstance(ATypeInfo);
    try
      for f in FContext.GetType(Result.AsObject.ClassType).GetFields do
      begin
        if f.FieldType <> nil then
        begin
          vFieldPair := GetPair(TJsonObject(AJSONValue), f.Name);
          vJsonValue := GetFieldDefault(f, vFieldPair, vOwnedJsonValue);
          if Assigned(vJsonValue) then
          begin
            try
              try
                v := FromJson(f.FieldType.Handle, vJsonValue);
              except
                on E: Exception do
                begin
                  raise EJSONException.CreateFmt('UnMarshalling error for field "%s.%s" : %s',
                                                            [Result.AsObject.ClassName, f.Name, E.Message]);
                end;
              end;

              if not v.IsEmpty then
              begin
                vOldValue := f.GetValue(Result.AsObject);

                if not vOldValue.IsEmpty and vOldValue.IsObject then
                begin
                  vOldValue.AsObject.Free;
                end;

                if v.TryCast(f.FieldType.Handle, vCast)  then
                  f.SetValue(Result.AsObject, vCast);
              end;
            finally
              if vOwnedJsonValue then
                vJsonValue.Free;
            end;
          end;
        end;
      end;
    except
      Result.AsObject.Free;
      raise;
    end;
  end
  else if AJsonValue is TJsonArray then
  begin
    if IsList(ATypeInfo) and IsParameterizedType(ATypeInfo) then
    begin
      Result := FromList(ATypeInfo, AJSONValue);
    end;
  end
  else
  begin
    Result := TValue.Empty;
  end;
end;

function TwDBXJsonUnmarshal.FromFloat(ATypeInfo: PTypeInfo; const AJSONValue: TJSONValue): TValue;
var
  vTemp: TJSONValue;
  vJavaDateTime: Int64;
begin
  if AJSONValue Is TJsonNumber then
  begin
    if ATypeInfo = TypeInfo(TDateTime) then
    begin
      Result := UnixToDateTime(TJsonNumber(AJSONValue).AsInt64);
    end
    else
    begin
      TValue.Make(nil, ATypeInfo, Result);
      case GetTypeData(ATypeInfo).FloatType of
        ftSingle: TValueData(Result).FAsSingle :=TJsonNumber(AJSONValue).AsDouble;
        ftDouble: TValueData(Result).FAsDouble :=TJsonNumber(AJSONValue).AsDouble;
        ftExtended: TValueData(Result).FAsExtended :=TJsonNumber(AJSONValue).AsDouble;
        ftComp: TValueData(Result).FAsSInt64 :=TJsonNumber(AJSONValue).AsInt64;
        ftCurr: TValueData(Result).FAsCurr :=TJsonNumber(AJSONValue).AsDouble;
      end;
    end;
  end
  else if AJSONValue Is TJsonString then
  begin
   // if ISO8601DateToJavaDateTime(AJSONValue.AsJsonString.Value, vJavaDateTime) then
   // begin
   //   Result := JavaToDelphiDateTime(vJavaDateTime);
   // end
   // else
    begin
      vTemp := TJSONObject.ParseJSONValue(AJSONValue.Value);
      try
        if vTemp Is TJsonNumber then
          Result := FromFloat(ATypeInfo, vTemp)
        else
          Result := TValue.Empty;
      finally
        vTemp.Free;
      end;
    end;
  end
  else
  begin
    Result := TValue.Empty;
  end;
end;

function TwDBXJsonUnmarshal.FromInt(ATypeInfo: PTypeInfo;const AJSONValue: TJSONValue): TValue;
var
  TypeData: PTypeData;
  i: Integer;
  vIsValid: Boolean;
  vTemp: TJSONValue;
  vRttiType: TRttiType;
begin
  if AJSONValue Is TJsonNumber then
  begin
    i := TJsonNumber(AJSONValue).AsInt;
    TypeData := GetTypeData(ATypeInfo);
    if TypeData.MaxValue > TypeData.MinValue then
      vIsValid := (i >= TypeData.MinValue) and (i <= TypeData.MaxValue)
    else
      vIsValid := (i >= TypeData.MinValue) and (i <= Int64(PCardinal(@TypeData.MaxValue)^));

    if vIsValid then
      TValue.Make(@i, ATypeInfo, Result);
  end
  else if AJSONValue Is TJsonTrue then
  begin
    i := Ord(True);
    TValue.Make(@i, ATypeInfo, Result);
  end
  else if AJSONValue Is TJsonFalse then
  begin
    i := Ord(False);
    TValue.Make(@i, ATypeInfo, Result);
  end
  else if AJSONValue Is TJsonString then
  begin
    vRttiType := FContext.GetType(ATypeInfo);

    if vRttiType is TRttiEnumerationType then
    begin
      if not TryStrToInt(TJSONString(AJSONValue).Value,i) then
        i := Ord(GetEnumValue(ATypeInfo,TJSONString(AJSONValue).Value));
      TValue.Make(@i, ATypeInfo, Result);
    end
    else
    begin
      vTemp := TJSONObject.ParseJSONValue(AJSONValue.Value);
      try
        if not(vTemp Is TJsonString) then
          Result := FromInt(ATypeInfo, vTemp)
        else
          Result := TValue.Empty;
      finally
        vTemp.Free;
      end;
    end;
  end;
end;

function TwDBXJsonUnmarshal.FromInt64(ATypeInfo: PTypeInfo;const AJSONValue: TJSONValue): TValue;
var
  i: Int64;
begin
  if AJSONValue Is TJsonNumber then
  begin
    TValue.Make(nil, ATypeInfo, Result);
    TValueData(Result).FAsSInt64 :=TJSONNumber(AJSONValue).AsInt64;
  end
  else if AJSONValue Is TJsonString and TryStrToInt64(TJSONString(AJSONValue).Value, i) then
  begin
    TValue.Make(nil, ATypeInfo, Result);
    TValueData(Result).FAsSInt64 := i;
  end
  else
  begin
    Result := TValue.Empty;
  end;
end;

function TwDBXJsonUnmarshal.FromJson(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
begin
  begin
    case ATypeInfo.Kind of
      tkChar: Result := FromChar(AJSONValue);
      tkInt64: Result := FromInt64(ATypeInfo, AJSONValue);
      tkEnumeration, tkInteger: Result := FromInt(ATypeInfo, AJSONValue);
      tkSet: Result := fromSet(ATypeInfo, AJSONValue);
      tkFloat: Result := FromFloat(ATypeInfo, AJSONValue);
      tkString, tkLString, tkUString, tkWString: Result := FromString(AJSONValue);
      tkClass: Result := FromClass(ATypeInfo, AJSONValue);
      tkMethod: ;
      tkPointer: ;
      tkWChar: Result := FromWideChar(AJSONValue);
      tkRecord: Result := FromRecord(ATypeInfo, AJSONValue);
  //    tkInterface: Result := FromInterface;
  //    tkArray: Result := FromArray;
  //    tkDynArray: Result := FromDynArray;
  //    tkClassRef: Result := FromClassRef;
  //  else
  //    Result := FromUnknown;
    else
      Result := TValue.Empty;
    end;
  end;
end;

class function TwDBXJsonUnmarshal.FromJson(AClassType: TClass; const AJSON: string): TObject;
var
  vJsonValue: TJSONValue;
  vUnmarshal: TwDBXJsonUnmarshal;
begin
  Result := nil;
  vJsonValue := TJSONObject.ParseJSONValue(AJSON);
  try
    if vJsonValue = nil then
    begin
      raise EJSONException.CreateFmt('Invalid json: "%s"', [AJSON]);
    end;

    vUnmarshal := TwDBXJsonUnmarshal.Create;
    try
      Result := vUnmarshal.FromJson(AClassType.ClassInfo, vJsonValue).Cast(AClassType.ClassInfo).AsObject;
    finally
      vUnmarshal.Free;
    end;
    finally
    vJsonValue.Free;
  end;
end;

class function TwDBXJsonUnmarshal.FromJson<T>(const AJSON: string): T;
var
  vJsonValue: TJSONValue;
begin
  vJsonValue := TJSONObject.ParseJSONValue(AJSON);
  try
    if vJsonValue = nil then
    begin
      raise EJSONException.CreateFmt('Invalid json: "%s"', [AJSON]);
    end;
    Result :=FromJson<T>(vJsonValue);
  finally
    vJsonValue.Free;
  end;
end;

class function TwDBXJsonUnmarshal.FromJson<T>(AJSONValue: TJSONValue): T;
var
  vUnmarshal: TwDBXJsonUnmarshal;
begin
  vUnmarshal := TwDBXJsonUnmarshal.Create;
  try
    Result := vUnmarshal.FromJson(TypeInfo(T), AJSONValue).AsType<T>;
  finally
    vUnmarshal.Free;
  end;
end;

function TwDBXJsonUnmarshal.FromList(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
var
  method: TRttiMethod;
  vJsonValue: TJSONValue;
  LJAr:TJSONArray;
  vItem: TValue;
  i: Integer;
begin
  Result := CreateInstance(ATypeInfo);

  method := FContext.GetType(ATypeInfo).GetMethod('Add');
  if Not(AJSONValue is TJSONArray) then Exit;
  LJAr:=TJSONArray(AJSONValue);
  for i := 0 to LJAr.Count - 1 do
  begin
    vJsonValue := LJAr.Items[i];
    vItem := FromJson(GetParameterizedType(ATypeInfo).Handle, vJsonValue);
    if not vItem.IsEmpty then
    begin
      method.Invoke(Result.AsObject, [vItem])
    end;
  end;
end;

function TwDBXJsonUnmarshal.FromRecord(ATypeInfo: PTypeInfo; AJSONValue: TJSONValue): TValue;
var
  f: TRttiField;
  v: TValue;
  vFieldPair: TJSONPair;
  vJsonValue: TJSONValue;
  vOwnedJsonValue: Boolean;
  vInstance: Pointer;
begin
  if AJSONValue Is TJsonObject then
  begin
    TValue.Make(nil, ATypeInfo, Result);
    {$IFDEF DELPHI_2010}
      vInstance := IValueData(TValueData(Result).FHeapData).GetReferenceToRawData;
    {$ELSE}
      vInstance := TValueData(Result).FValueData.GetReferenceToRawData;
    {$ENDIF}
    try
      for f in FContext.GetType(ATypeInfo).GetFields do
      begin
        if f.FieldType <> nil then
        begin
          vFieldPair := GetPair(TJsonObject(AJSONValue), f.Name);

          vJsonValue := GetFieldDefault(f, vFieldPair, vOwnedJsonValue);

          if Assigned(vJsonValue) then
          begin
            try
              try
                v := FromJson(f.FieldType.Handle, vJsonValue);
              except
                on E: Exception do
                begin
                  raise EJSONException.CreateFmt('UnMarshalling error for field "%s.%s" : %s',
                                                            [Result.AsObject.ClassName, f.Name, E.Message]);
                end;
              end;

              if not v.IsEmpty then
              begin
                f.SetValue(vInstance, v);
              end;
            finally
              if vOwnedJsonValue then
                vJsonValue.Free;
            end;
          end;
        end;
      end;
    except
      raise;
    end;
  end
end;

function TwDBXJsonUnmarshal.FromSet(ATypeInfo: PTypeInfo;const AJSONValue: TJSONValue): TValue;
var
  i: Integer;
begin
  if AJSONValue Is TJsonNumber then
  begin
    TValue.Make(nil, ATypeInfo, Result);
    TValueData(Result).FAsSLong := TJsonNumber(AJSONValue).AsInt;
  end
  else if (AJSONValue Is TJsonString) and TryStrToInt(TJsonString(AJSONValue).Value, i) then
  begin
    TValue.Make(nil, ATypeInfo, Result);
    TValueData(Result).FAsSLong := i;
  end
  else
    Result := TValue.Empty;
end;

function TwDBXJsonUnmarshal.FromString(const AJSONValue: TJSONValue): TValue;
begin
  if AJSONValue Is TJsonNull then
  begin
    Result := ''
  end
  else if AJSONValue Is TJsonString then
  begin
    Result :=TJSONString(AJSONValue).Value;
  end
  else if AJSONValue Is TJsonNumber then
  begin
    Result :=TJsonNumber(AJSONValue).Value;
  end
  else if AJSONValue Is TJsonTrue then
  begin
    Result := 'true';
  end
  else if AJSONValue is TJsonFalse then
  begin
    Result := 'false';
  end
  else
    raise EJSONException.CreateFmt('Invalid value "%s".', [AJSONValue.ToString]);
end;

function TwDBXJsonUnmarshal.FromWideChar(const AJSONValue: TJSONValue): TValue;
begin
  Result := TValue.Empty;
  if AJSONValue Is TJsonString and (Length(TJsonString(AJSONValue).Value) = 1) then
  begin
    Result :=TJsonString(AJSONValue).Value[1];
  end;
end;

function TwDBXJsonUnmarshal.GetFieldDefault(AField: TRttiField; AJsonPair: TJSONPair; var AOwned: Boolean): TJSONValue;
var
  attr: TCustomAttribute;
begin
  AOwned := False;
  if (not Assigned(AJsonPair) or not Assigned(AJsonPair.JsonValue)) or
     (Assigned(AJsonPair) and Assigned(AJsonPair.JsonValue) and (AJsonPair.JsonValue Is TJsonNull)) or
     (Assigned(AJsonPair) and Assigned(AJsonPair.JsonValue) and (AJsonPair.JsonValue Is TJsonString)) and
     (Length(TJsonString(AJsonPair.JsonValue).Value)= 0) and Assigned(AJsonPair.JsonValue) then
  begin
  { for attr in AField.GetAttributes do
    begin
      if attr is JsonDefault then
      begin
        AOwned := True;
        Exit(TJSONObject.ParseJSONValue(JsonDefault(attr).Name));
      end;
    end;
    }
    Result:=Nil;
    Exit;
  end;
  Result := nil;
  if Assigned(AJsonPair) then
    Result := AJsonPair.JsonValue;
end;

function TwDBXJsonUnmarshal.GetPair(AJSONObject: TJSONObject;const APairName: UnicodeString): TJSONPair;
begin
  Result := AJSONObject.Get(APairName);
end;

function TwDBXJsonUnmarshal.GetParameterizedType(ATypeInfo: PTypeInfo): TRttiType;
var
  startPos,
  endPos: Integer;
  vTypeName,
  vParameterizedType: String;
begin
  Result := nil;

{$IFDEF NEXTGEN}
  vTypeName := ATypeInfo.Name.ToString();
{$ELSE  NEXTGEN}
  vTypeName := String(ATypeInfo.Name);
{$ENDIF NEXTGEN}

  startPos := AnsiPos('<', vTypeName);

  if startPos > 0 then
  begin
    endPos := Pos('>', vTypeName);

    vParameterizedType := Copy(vTypeName, startPos + 1, endPos - Succ(startPos));

    Result := FContext.FindType(vParameterizedType);
  end;
end;

function TwDBXJsonUnmarshal.IsList(ATypeInfo: PTypeInfo): Boolean;
var
  method: TRttiMethod;
begin
  method := FContext.GetType(ATypeInfo).GetMethod('Add');

  Result := (method <> nil) and
            (method.MethodKind = mkFunction) and
            (Length(method.GetParameters) = 1)
end;

function TwDBXJsonUnmarshal.IsParameterizedType(ATypeInfo: PTypeInfo): Boolean;
var
  vStartPos: Integer;
  vTypeName: string;
begin
{$IFDEF NEXTGEN}
  vTypeName := ATypeInfo.Name.ToString();
{$ELSE  NEXTGEN}
  vTypeName := String(ATypeInfo.Name);
{$ENDIF NEXTGEN}

  vStartPos := Pos('<', vTypeName);
  Result := (vStartPos > 0) and (PosEx('>', vTypeName, vStartPos) > 0);
end;

class function TwDBXJsonUnmarshal.ValueFromJson(AJSONValue: TJSONValue): TValue;
var
  vUnmarshal: TwDBXJsonUnmarshal;
  LTypeInfo:PTypeInfo;
  LS:string;
  i:Integer;
  i64:Int64;
  LFlag:Boolean;
begin
  vUnmarshal := TwDBXJsonUnmarshal.Create;
  Result:=TValue.Empty;
  try
    if AJSONValue.ClassName='TJSONNumber' then
      begin
         LS:=TJSONNumber(AJSONValue).Value;
         LFlag:=False;
         i:=1;
         while i<=Length(LS) do
           begin
             if LS[i] in [FormatSettings.DecimalSeparator,',','.'] then
               begin
                 LFlag:=True;
                 Break;
               end;
             Inc(i);
           end;
         if LFlag then
             Exit(TJSONNumber(AJSONValue).AsDouble)
         else
           begin
             i64:=TJSONNumber(AJSONValue).AsInt64;
             if (Abs(i64)<MaxLongInt-1) then
                Exit(Integer(i64))
             else Exit(i64);
           end;
      end;
    if AJSONValue.ClassName='TJSONString' then
       Exit(TJSONString(AJSONValue).ToString);
    if AJSONValue.ClassName='TJSONBool' then
       Exit(TJSONBool(AJSONValue).AsBoolean);
    if AJSONValue.ClassName='TJSONArray' then
      begin
        raise Exception.Create('Unmarshal fron JSON - no Realization!');
      end;
  finally
    vUnmarshal.Free;
  end;
end;

end.
