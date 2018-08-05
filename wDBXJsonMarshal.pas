unit wDBXJsonMarshal;

interface

uses Rtti, TypInfo, DBXJson,
     Json;

type
  TwDBXJsonMarshal = class
  private
    FContext: TRttiContext;

    function IsList(ATypeInfo: PTypeInfo): Boolean;

    function ToJson(field: TRttiField; var AValue: TValue): TJSONValue;overload;

    function ToClass(AValue: TValue): TJSONValue;
    function ToRecord(AValue: TValue): TJSONValue;
    function ToInteger(AValue: TValue): TJSONValue;
    function ToInt64(AValue: TValue): TJSONValue;
    function ToChar(AValue: TValue): TJSONValue;
    function ToFloat(field: TRttiField; AValue: TValue): TJSONValue;
    function ToJsonString(AValue: TValue): TJSONValue;
    function ToWideChar(AValue: TValue): TJSONValue;
    function ToDynArray(field: TRttiField; AValue: TValue): TJSONValue;
  public
    constructor Create;
    destructor Destroy; override;
    // Willi
    class function ToJson(AValue: TValue): TJSONValue;overload;
    class function ToJsonText(AValue: TValue): string;
    /// <summary>
    ///    add  UnMarshalling!
    /// </summary>
    class function ValueFromJson(AJSONValue: TJSONValue): TValue;
  end;

  function JSON_CorrectStringValue(const AValue: string): string;

implementation

uses SysUtils,DateUtils,StrUtils;


 //////////////////////////////////////
{function JSON_CorrectStringValue(const AValue: string): string;
 //
  procedure AddChars(const AChars: string; var Dest: string; var AIndex: Integer); inline;
  begin
    System.Insert(AChars, Dest, AIndex);
    System.Delete(Dest, AIndex + 2, 1);
    Inc(AIndex, 2);
  end;
  procedure AddUnicodeChars(const AChars: string; var Dest: string; var AIndex: Integer); inline;
  begin
    System.Insert(AChars, Dest, AIndex);
    System.Delete(Dest, AIndex + 6, 1);
    Inc(AIndex, 6);
  end;
var
  i, ix: Integer;
  AChar: Char;
begin
  Result := AValue;
  ix := 1;
  for i := 1 to System.Length(AValue) do
  begin
    AChar :=  AValue[i];
    case AChar of
      #39: begin
             System.Insert('\\', Result, ix);
             Inc(ix, 2);
           end;
      '/', '\':
      begin
        System.Insert('\\', Result, ix);
        Inc(ix, 2);
      end;
      #8:  //backspace \b
      begin
        AddChars('\\b', Result, ix);
      end;
      #9:
      begin
        AddChars('\\t', Result, ix);
      end;
      #10:
      begin
        AddChars('\\n', Result, ix);
      end;
      #12:
      begin
        AddChars('\\f', Result, ix);
      end;
      #13:
      begin
        AddChars('\r', Result, ix);
      end;
      #0 .. #7, #11, #14 .. #31:
      begin
        AddUnicodeChars('\\u' + IntToHex(Word(AChar), 4), Result, ix);
      end
      else
      begin
       // Result:=Result+AValue[i];
      //if Word(AChar) > 127 then
      //  begin
      //    AddUnicodeChars('\u' + IntToHex(Word(AChar), 4), Result, ix);
      //  end
      //  else
        begin
          Inc(ix);
        end;
      end;
    end;
  end;
end;
}

function JSON_CorrectStringValue(const AValue: string): string;
 begin
   Result:=StringReplace(AValue,'\','\\\\',[rfReplaceAll]);
   Result:=StringReplace(Result,'/','\\/',[rfReplaceAll]);
 end;


{ TDBXJsonMarshal }

constructor TwDBXJsonMarshal.Create;
begin
  FContext := TRttiContext.Create;
end;

destructor TwDBXJsonMarshal.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TwDBXJsonMarshal.IsList(ATypeInfo: PTypeInfo): Boolean;
var
  method: TRttiMethod;
begin
  method := FContext.GetType(ATypeInfo).GetMethod('Add');

  Result := (method <> nil) and
            (method.MethodKind = mkFunction) and
            (Length(method.GetParameters) = 1)
end;

function TwDBXJsonMarshal.ToJson(field: TRttiField; var AValue: TValue): TJSONValue;
begin
  case AValue.Kind of
    tkInt64: Result := ToInt64(AValue);
    tkChar: Result := ToChar(AValue);
    tkSet, tkInteger, tkEnumeration: Result := ToInteger(AValue);
    tkFloat: Result := ToFloat(field, AValue);
    tkString, tkLString, tkUString, tkWString: Result := ToJsonString(AValue);
    tkClass: Result := ToClass(AValue);
    tkWChar: Result := ToWideChar(AValue);
//    tkVariant: ToVariant;
    tkRecord: Result := ToRecord(AValue);
//    tkArray: ToArray;
    tkDynArray: Result := ToDynArray(field, AValue);
//    tkClassRef: ToClassRef;
//    tkInterface: ToInterface;
  else
    result := nil;
  end;
end;

function TwDBXJsonMarshal.ToChar(AValue: TValue): TJSONValue;
begin
  Result := TJSONString.Create(AValue.AsString);
end;

function TwDBXJsonMarshal.ToClass(AValue: TValue): TJSONValue;
var
  f: TRttiField;
  fieldValue: TValue;
  vJsonObject: TJSONObject;
  vJsonValue: TJSONValue;
  vIsList: Boolean;
begin
  Result := nil;

  if AValue.IsObject and (AValue.AsObject <> nil) then
  begin
    vIsList := IsList(AValue.TypeInfo);

    vJsonObject := nil;
    if not vIsList then
    begin
      vJsonObject := TJSONObject.Create;
    end;

    for f in FContext.GetType(AValue.AsObject.ClassType).GetFields do
    begin
      if (f.FieldType <> nil) (* and (f.Visibility in [mvPublic, mvPublished])*) then
      begin
        fieldValue := f.GetValue(AValue.AsObject);

        if fieldValue.IsObject and (fieldValue.AsObject = nil) then
        begin
          Continue;
        end;

        if vIsList then
        begin
          if (f.Name = 'FItems') then
          begin
            Exit(ToJson(f, fieldValue));
          end;
          Continue;
        end;

        vJsonValue := ToJson(f, fieldValue);

        if vJsonValue <> nil then
        begin
          vJsonObject.AddPair(TJSONPair.Create(f.Name, vJsonValue));
        end;
      end;
    end;
    Result := vJsonObject;
  end;
end;

function TwDBXJsonMarshal.ToDynArray(field: TRttiField; AValue: TValue): TJSONValue;
var
  i: Integer;
  v: TValue;
begin
  Result := TJSONArray.Create;
  for i := 0 to AValue.GetArrayLength - 1 do
  begin
    v := AValue.GetArrayElement(i);
    if not v.IsEmpty then
    begin
      TJSONArray(Result).AddElement(toJSon(field, v));
    end;
  end;
end;

function TwDBXJsonMarshal.ToFloat(field: TRttiField; AValue: TValue): TJSONValue;
begin
  Result := nil;
  if AValue.TypeInfo = TypeInfo(TDateTime) then
  begin
    if TValueData(AValue).FAsDouble > 0 then
    begin
     // if field.FormatUsingISO8601 then
     //   Result := TJSONString.Create(DelphiDateTimeToISO8601Date(AValue.AsType<TDateTime>))
     // else
     //    Result := TJSONNumber.Create(DelphiToJavaDateTime(AValue.AsType<TDateTime>));
        Result := TJSONNumber.Create(DateTimeToUnix(AValue.AsType<TDateTime>));
    end;
  end
  else
  begin
    case AValue.TypeData.FloatType of
      ftSingle: Result := TJSONNumber.Create(TValueData(AValue).FAsSingle);
      ftDouble: Result := TJSONNumber.Create(TValueData(AValue).FAsDouble);
      ftExtended: Result := TJSONNumber.Create(TValueData(AValue).FAsExtended);
      ftComp: Result := TJSONNumber.Create(TValueData(AValue).FAsSInt64);
      ftCurr: Result := TJSONNumber.Create(TValueData(AValue).FAsCurr);
    end;
  end;
end;

function TwDBXJsonMarshal.ToInt64(AValue: TValue): TJSONValue;
begin
  Result := TJSONNumber.Create(AValue.AsInt64);
end;

function TwDBXJsonMarshal.ToInteger(AValue: TValue): TJSONValue;
begin
  if AValue.TypeInfo = TypeInfo(Boolean) then
  begin
    if AValue.AsBoolean then
      Result := TJSONTrue.Create
    else
      Result := TJSONFalse.Create;
  end
  else
  begin
    Result := TJSONNumber.Create(TValueData(AValue).FAsSLong);
  end;
end;


function TwDBXJsonMarshal.ToRecord(AValue: TValue): TJSONValue;
var
  f: TRttiField;
  fieldValue: TValue;
  vJsonObject: TJSONObject;
  vJsonValue: TJSONValue;
begin
  Result := nil;

  if AValue.Kind = tkRecord then
  begin
    vJsonObject := TJSONObject.Create;

    for f in FContext.GetType(AValue.TypeInfo).GetFields do
    begin
      if (f.FieldType <> nil) then
      begin
        {$IFDEF DELPHI_2010}
          fieldValue := f.GetValue(IValueData(TValueData(AValue).FHeapData).GetReferenceToRawData);
        {$ELSE}
          fieldValue := f.GetValue(TValueData(AValue).FValueData.GetReferenceToRawData);
        {$ENDIF}

        if fieldValue.IsObject and (fieldValue.AsObject = nil) then
        begin
          Continue;
        end;

        vJsonValue := ToJson(f, fieldValue);

        if vJsonValue <> nil then
        begin
          vJsonObject.AddPair(TJSONPair.Create(f.Name, vJsonValue));
        end;
      end;
    end;
    Result := vJsonObject;
  end;
end;

class function TwDBXJsonMarshal.ToJson(AValue: TValue): TJSONValue;
var
  vMarshal: TwDBXJsonMarshal;
  v: TValue;
begin
  vMarshal := TwDBXJsonMarshal.Create;
  try
    v :=AValue;
    Result := vMarshal.ToJson(nil, v);
  finally
    vMarshal.Free;
  end;
end;

function TwDBXJsonMarshal.ToJsonString(AValue: TValue): TJSONValue;
begin
  Result := TJSONString.Create(AValue.AsString);
end;

class function TwDBXJsonMarshal.ToJsonText(AValue: TValue): string;
var
  vJson: TJSONValue;
begin
  vJson := ToJson(AValue);
  try
    Result := vJson.ToString;
  finally
    vJson.Free;
  end;
end;

function TwDBXJsonMarshal.ToWideChar(AValue: TValue): TJSONValue;
begin
  Result := TJSONString.Create(AValue.AsType<Char>);
end;


class function TwDBXJsonMarshal.ValueFromJson(AJSONValue: TJSONValue): TValue;
var
  LS:string;
  i:Integer;
  i64:Int64;
  LFlag:Boolean;
begin
  Result:=TValue.Empty;
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
end;


end.
