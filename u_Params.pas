unit u_Params;
/// модуль-класс работы с таблицей параметров - задача - получить и выставить
/// для различных контролов указанные по признаку значения (описания)
/// таблица открыта и подключена постоянно
interface


uses Classes, FireDAC.Comp.Client,
 FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.FMXUI.Wait,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB,
  FireDAC.Comp.DataSet;

type

  TstParams=class(TComponent)
    private
     FParamsTableName:string;
     FLangId:integer;
     FGroupId:integer;
     F_UGrStr:string;
     function LocateFrom(const ATableName,aParamType,aName:string):boolean;
    protected
     function PrepareSQLText(const AFilteredString:string):string;
    public
      pQuery:TFDQuery;
      pFilteredQuery:TFDQuery;
      descMinPrefix,descMaxPrefix:String;
      constructor Create(AOwner:TComponent); override;
      constructor AssignSourceData(const AFConnection:TFDConnection; const aParamsTableName:string; aLangId,aGroupId:integer);
      destructor Destroy; override;
      ///
     procedure SetDescPrefixes(const AMinPrx,aMaxPrx:String);
      ///
     function OpenTable:boolean;
     function GetFParam(const ATableName,aParamType,aName:string):double;
     function GetParam(const ATableName,aParamType,aName:string):String;
     function GetParamDesc(const ATableName,aParamType,aName:string):string;
     /// <summary>
     ///    if aValue=* then update only pDESC - if aDEsc=* - only update PVALUE
     /// </summary>
     function SetParam(const ATableName,aName,aParamType,aValue,aDesc:string):boolean;
     /// <summary>
     ///    fill MIN MAX DEF values for aName  - desc=desc***Prefix + DescSfx
     /// </summary>
     function SetDimFParam(const ATableName,aName,aDescSfx:string; aMin,aDefault,aMax:double):boolean;
     /// <summary>
     ///    get DEF Desc and replace first Char to Upper
     /// </summary>
     function GetDefDesc(const ATableName,aName:string):string;
     /// <summary>
     ///     add Hint Param
     /// </summary>
     procedure SetHintParam(const ATableName,aName,aCaption,aHintStr:string);
     function GetHintParam(const ATableName,aName:string; var aCapt:string):string;
     /// <summary>
     ///     открыть фильтрованную таблицу - вернет кол-во записей для поля
     /// </summary>
     function OpenFilteredTable(const ATableName,aName:string):Integer;
     /// <summary>
     ///    заполнить (для новой записи базы) поля значениями по умолчанию (если они заданы) - DEF параметр
     /// </summary>
     function SetDefaultParams(const ATableName:string; aEntId:Integer; const aDS:TDataset):Boolean;
     property TableName:string read FParamsTableName;
  end;


implementation

uses System.SysUtils, System.Variants;


{ TstParams }

constructor TstParams.AssignSourceData(const AFConnection: TFDConnection; const aParamsTableName:string;
  aLangId, aGroupId: integer);
begin
 FParamsTableName:=aParamsTableName;
 pQuery.Connection:=AFConnection;
 FLangId:=aLangId;
 FGroupId:=aGroupId;
 pFilteredQuery.Connection:=AFConnection;
end;

constructor TstParams.Create(AOwner:TComponent);
begin
 inherited Create(Aowner);
 pQuery:=TFDQuery.Create(nil);
 pFilteredQuery:=TFDQuery.Create(nil);
 FParamsTableName:='params_t';
end;

destructor TstParams.Destroy;
begin
  pFilteredQuery.Free;
  pQuery.Free;
  inherited;
end;

function TstParams.GetDefDesc(const ATableName, aName: string): string;
var LS:string;
begin
 Result:='';
 if LocateFrom(ATableName,'DEF',aName) then
  begin
    LS:=pQuery.FieldByName('PDESC').AsWideString;
    if Length(LS)>0 then
       LS[1]:=UpCase(LS[1]);
    Result:=LS;
  end;
end;

function TstParams.GetFParam(const ATableName, aParamType,
  aName: string): double;
 var LValue:string;
begin
 Result:=0;
 if LocateFrom(ATableName, aParamType,aName) then
  begin
    LValue:=pQuery.FieldByName('PVALUE').AsWideString;
    if Pos(',',LValue)>0 then
       LValue:=StringReplace(LValue,',',FormatSettings.DecimalSeparator,[])
    else
       if Pos('.',LValue)>0 then
          LValue:=StringReplace(LValue,'.',FormatSettings.DecimalSeparator,[]);
    TryStrToFloat(LValue,Result);
  end;
end;

function TstParams.GetHintParam(const ATableName, aName: string;
  var aCapt: string): string;
begin
  Result:='';
  if LocateFrom(ATableName,'HINT',aName) then
    begin
     Result:=pQuery.FieldByName('PVALUE').AsWideString;
     aCapt:=pQuery.FieldByName('PDESC').AsWideString;
    end;
end;

function TstParams.GetParam(const ATableName, aParamType,
  aName: string): String;
begin
 Result:='';
 if LocateFrom(ATableName, aParamType,aName) then
    Result:=pQuery.FieldByName('PVALUE').AsWideString;
end;

function TstParams.GetParamDesc(const ATableName, aParamType,
  aName: string): string;
begin
  Result:='';
  if LocateFrom(ATableName, aParamType,aName) then
     Result:=pQuery.FieldByName('PDESC').AsWideString;
end;

function TstParams.LocateFrom(const ATableName, aParamType, aName:string): boolean;
  var LParamType:String;
begin
  Result:=false;
  if aParamType='' then
     LParamType:='DEF'
  else
     LParamType:=Trim(aParamType);
  if pQuery.Locate('TBL_NAME;PNAME;PTYPE',VarArrayOF([ATableName,aName,LParamType]),[]) then
     Result:=(pQuery.FieldByName('PVALUE').IsNull=false);
end;

function TstParams.OpenFilteredTable(const ATableName, aName: string): Integer;
begin
  Result:=0;
  pFilteredQuery.Close;
  pFilteredQuery.SQL.Text:=PrepareSQLText(' (TBL_NAME='''+ATableName+''') AND (PNAME='''+aName+''')');
  pFilteredQuery.Open;
  Result:=pFilteredQuery.RecordCount;
  pFilteredQuery.First;
end;

function TstParams.OpenTable: boolean;
begin
 Result:=false;
 pQuery.Close;
 pQuery.SQL.Text:=PrepareSQLText('');
 ///
 try
   pQuery.Open;
   Result:=(pQuery.Active=true);
   except
 end;
end;

function TstParams.PrepareSQLText(const AFilteredString: string): string;
  ///
  var LS,LS1:string;
begin
 F_UGrStr:='';
 Result:='SELECT * FROM '+FParamsTableName;
 if FLangId=0 then LS:='' else LS:='(LANG_ID='+IntToStr(FLangId)+')';
 if FGroupId=0 then LS1:='' else LS1:='(GROUP_ID='+IntToStr(FGroupId)+')';
 if (LS<>'') and (LS1<>'') then
    F_UGrStr:=LS+' AND '+LS1
 else
    if (LS<>'') then
        F_UGrStr:=LS
    else if (LS1<>'') then
             F_UGrStr:=LS1
         else F_UGrStr:='';
 if F_UGrStr<>'' then
    Result:=Result+' WHERE '+F_UGrStr;
 if AFilteredString='' then
    Result:=Result+';'
 else
     if F_UGrStr='' then
        Result:=Result+' WHERE '+AFilteredString+';'
     else
        Result:=Result+' AND '+AFilteredString+';'
end;

function TstParams.SetDefaultParams(const ATableName: string; aEntId:Integer;
  const aDS: TDataset): Boolean;
 var i:Integer;
begin
 Result:=False;
 i:=0;
 while i<aDS.FieldCount do
  begin
     if aDS.Fields[i].FieldName='ENT_ID' then
        if aEntId>0 then aDS.Fields[i].AsInteger:=aEntId
        else aDS.Fields[i].AsInteger:=0;
     if aDS.Fields[i].FieldName='SIGN' then
        aDS.Fields[i].AsInteger:=0;
     if aDS.Fields[i].FieldName<>'ID' then
        {  if aDS.Fields[i].DataType in [ftSmallint,ftInteger,ftWord,
           ftBoolean,ftFloat,ftCurrency,ftDate,ftTime,ftDateTime,
           ftByte,ftLargeint,ftSingle,ftExtended,ftLongWord,ftShortint] then
            begin
             LR:=GetFParam(ATableName,'DEF',aDS.Fields[i].FieldName);
            end
          else
           begin
             if aDS.Fields[i].DataType in [ftWideString] then
                aDS.Fields[i].
           end;
       }
      if LocateFrom(ATableName,'DEF',aDS.Fields[i].FieldName) then
          begin
            aDS.Fields[i].Value:=pQuery.FieldByName('PVALUE').Value;
            Result:=True;
          end;
    Inc(i);
  end;

end;

procedure TstParams.SetDescPrefixes(const AMinPrx,aMaxPrx: String);
begin
  descMinPrefix:=AMinPrx;
  descMaxPrefix:=aMaxPrx;
end;

function TstParams.SetDimFParam(const ATableName, aName, aDescSfx: string; aMin,
  aDefault, aMax: double): boolean;
var LQ:TFDQuery;
    LS:string;
    i:integer;
begin
  Result:=false;
  LQ:=TFDQuery.Create(nil);
  try
    LQ.Connection:=pQuery.Connection;
    LS:='(PNAME='''+aName+''') AND ((PTYPE=''MIN'') OR (PTYPE=''MAX'') OR (PTYPE=''DEF''));';
    if F_UGrStr<>'' then
       LS:=F_UGrStr+' AND '+LS;
    LQ.SQL.Text:='Delete FROM '+FParamsTableName+' WHERE '+LS;
    try
      LQ.ExecSQL;
      LQ.SQL.Clear;
        /// добавление записей
      LQ.SQL.Add('INSERT INTO '+FParamsTableName+' (ID,LANG_ID,GROUP_ID,TBL_NAME,PNAME,PTYPE,PVALUE,PDESC,SIGN) '+
                             'VALUES (:ID,:LANG_ID,:GROUP_ID,:TBL_NAME,:PNAME,:PTYPE,:PVALUE,:PDESC,:SIGN);');
      LQ.Params.Bindmode := pbByNumber; {more efficient than by name }
      LQ.Params.ArraySize :=3;
      LQ.Params[0].AsIntegers[0]:=0;
      LQ.Params[0].AsIntegers[1]:=0;
      LQ.Params[0].AsIntegers[2]:=0;
      for i:=0 to 2 do LQ.Params[1].AsIntegers[i]:=FLangId;
      for i:=0 to 2 do LQ.Params[2].AsIntegers[i]:=FGroupId;
      for i:=0 to 2 do LQ.Params[3].AsStrings[i]:=ATableName;
      for i:=0 to 2 do LQ.Params[4].AsStrings[i]:=aName;
      LQ.Params[5].AsStrings[0]:='MIN';
      LQ.Params[5].AsStrings[1]:='DEF';
      LQ.Params[5].AsStrings[2]:='MAX';
      LQ.Params[6].AsStrings[0]:=FloatToStr(aMin);
      LQ.Params[6].AsStrings[1]:=FloatToStr(aDefault);
      LQ.Params[6].AsStrings[2]:=FloatToStr(aMax);
      LQ.Params[7].AsStrings[0]:=descMinPrefix+' '+aDescSfx;
      LQ.Params[7].AsStrings[1]:=aDescSfx;
      LQ.Params[7].AsStrings[2]:=descMaxPrefix+' '+aDescSfx;
      for i:=0 to 2 do LQ.Params[8].AsIntegers[i]:=0;
    ///
       LQ.Execute(LQ.Params.ArraySize);
       Result:=true;
      except
    end;
  finally
    LQ.Free;
  end;
end;

procedure TstParams.SetHintParam(const ATableName, aName, aCaption,
  aHintStr: string);
var LQ:TFDQuery;
    LSQL:String;
    LId:integer;
begin
  if pQuery.Locate('TBL_NAME;PNAME;PTYPE',VarArrayOF([ATableName,aName,'HINT']),[]) then
    begin
      LId:=pQuery.FieldByName('ID').Asinteger;
      LSQL:='Update '+FParamsTableName+' SET PVALUE='''+aHintStr+''',PDESC='''+aCaption+''''+
            ' WHERE (ID='+IntToStr(LId)+');';
    end
    else
      LSQL:=Format('INSERT INTO '+FParamsTableName+' (ID,LANG_ID,GROUP_ID,TBL_NAME,PNAME,PTYPE,PVALUE,PDESC,SIGN) '+
                             'VALUES (%d,%d,%d,''%s'',''%s'',''%s'',''%s'',''%s'',0);', //select last_insert_id();',
                             [0,FLangId,FGroupId,ATableName,aName,'HINT',aHintStr,aCaption]);
  LQ:=TFDQuery.Create(nil);
  try
    LQ.Connection:=pQuery.Connection;
    LQ.SQL.Text:=LSQL;
    try
      LQ.ExecSQL;
      pQuery.Refresh;
      if Lid<=0 then
         pQuery.Locate('TBL_NAME;PNAME;PTYPE',VarArrayOF([ATableName,aName,'HINT']),[]);
      except
    end;
  finally
    LQ.Free;
  end;
end;

function TstParams.SetParam(const ATableName, aName, aParamType, aValue,
  aDesc: string): boolean;
var LQ:TFDQuery;
    LParamType,LSQL,LDesc,LValueStr:string;
    Lid:integer;
begin
   Lid:=0;
   if aParamType='' then
     LParamType:='DEF'
   else LParamType:=Trim(aParamType);
   if aValue='*' then LValueStr:='' else LValueStr:=aValue;
   if aDesc='*' then LDesc:='' else LDesc:=aDesc;
   if pQuery.Locate('TBL_NAME;PNAME;PTYPE',VarArrayOF([ATableName,aName,LParamType]),[]) then
    begin
      LId:=pQuery.FieldByName('ID').Asinteger;
      if aDesc='*' then
         LDesc:=pQuery.FieldByName('PDESC').AsWideString;
      if aValue='*' then
         LValueStr:=pQuery.FieldByName('PVALUE').AsWideString;
      LSQL:='Update '+FParamsTableName+' SET PVALUE='''+LValueStr+''',PDESC='''+LDesc+''''+
            ' WHERE (ID='+IntToStr(LId)+');';
    end
    else
      LSQL:=Format('INSERT INTO '+FParamsTableName+' (ID,LANG_ID,GROUP_ID,TBL_NAME,PNAME,PTYPE,PVALUE,PDESC,SIGN) '+
                             'VALUES (%d,%d,%d,''%s'',''%s'',''%s'',''%s'',''%s'',0);', //select last_insert_id();',
                             [0,FLangId,FGroupId,ATableName,aName,LParamType,LValueStr,LDesc]);
  LQ:=TFDQuery.Create(nil);
  try
    LQ.Connection:=pQuery.Connection;
    LQ.SQL.Text:=LSQL;
    try
      LQ.ExecSQL;
      pQuery.Refresh;
      if Lid<=0 then
         Result:=pQuery.Locate('TBL_NAME;PNAME;PTYPE',VarArrayOF([ATableName,aName,LParamType]),[]);
      except
      Result:=false;
    end;
  finally
    LQ.Free;
  end;
end;

end.
