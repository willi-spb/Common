unit FMX.FormFuncs;

interface

uses
 System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
 FMX.Types, //System.Rtti,
 FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
 FMX.Controls.Presentation, FMX.Effects, FMX.Objects, FMX.Layouts;

type
  TcpStateFlag=(cp_All,cpOnlyPos,cp_Visibled);
  TCpStateFlags=set of TcpStateFlag;

  TCopyStateRecord=record
    Regime:Integer;
    Src,Dest:TControl;
    Flags:TCpStateFlags;
  end;
/// <summary>
///     копировать из 1 в 2 основные свойства и события
/// </summary>
/// <param name="aCopyRg">
///     =1 (не исп.)
/// </param>
function CopyControlProperties(aCopyRg:Integer; aCtrl1,aCtrl2:TControl):Boolean;
/// <summary>
///     копировать визуальное состояние: создаем контролы в Dest, копируем им свойства
///  - внутри выз. CopyControlProperties
/// </summary>
function CopyControlVisualStates(acRec:TCopyStateRecord):Boolean;
///
/// <summary>
///     установить значение Value для контрола в зависимости от его типа- если TEdit -> Text и проч.
/// </summary>
function SetValueToControl(aCtrl:TControl; const aValue:Variant):Boolean;
///
function GetValueFromControl(aCtrl:TControl):Variant;
/// <summary>
///     вернуть поле Text для тех контролов, у которых оно есть и может отличаться от поля значения Value
/// </summary>
function GetTextFromControl(aCtrl:TControl; const aEmptyStr:string=''):string;
/// <summary>
///    выставить значение Min Max для контрола типа progressbar, numberBox
/// </summary>
function SetDimenstionToControl(aCtrl:TControl; const aMin,aMax:Single):Boolean;
/// <summary>
///    выставить Increment-ы для нумбербокса как часть от интервала  - 0-не использовать Increment
/// </summary>
function SetIncrementToControl(aCtrl:TControl; aHorDelta,aVertDelta:single):Boolean;
/// <summary>
///    найти контрол в layout по классу и тэгу (тэг должен быть уником, найдется первый либо nil)
/// </summary>
//function GetControlInLayout(aL:TLayout; aClass:TClass; aTag:integer):TControl;
/// <summary>
///     найти в Parent нужный контрол по его Tag
/// </summary>
function GetControlInParent(aPar:TControl; aClass:TClass; aTag:integer):TControl;
///
/// <summary>
///    найти первый с подходящим тегом
/// </summary>
function FindFirstControlInParent(aPar:TControl; aTag:integer):TControl;
///
/// <summary>
///    Find Min and Max Tag for All Children Controls
/// </summary>
procedure GetTagDimension(aPar:TControl; var aMinTag,aMaxTag:integer; aOnlyVisibleFlag:Boolean=true);
///
/// <summary>
///     найти в Parent нужный контрол по его Имени
/// </summary>
//function GetControlInParentFromName(aPar:TControl; aClass:TClass; aTag:integer):TControl;

/// <summary>
///     очистить список Layout-ов внутри какого-либо компонента
///     вернет количество удаленных полос - вернет 0 - если нечего удалять
/// </summary>
function ClearLayouts(const aParent:TControl):Integer;
///
/// <summary>
///    добавить в событие к дочерним компонентам обработку от их parent
/// </summary>
procedure ModifyCtrlFocusEvents(const aParent:TControl; aMouseEvent:TMouseEvent; aKeyEvent:TKeyEvent; aEvent:TNotifyEvent);
///
///
/// <summary>
 ///      корректировка стиля для групбоксов - вытягивание по длине Rect заголовка бокса
 /// </summary>
  function GroupBox_CorrectStyle(aSenderObj:TObject):Boolean;
 /// <summary>
    ///   перевыровнять кнопки радио
 /// </summary>
procedure RealignRadioButtons(const aGroup:TGroupBox; aHomeTag:Integer=0);
/// <summary>
///    найти таг включенной радиокнопки
/// </summary>
function FindRadioButtonCheckTag(const aGroup:TGroupBox):Integer;
/// <summary>
///     найти кнопку по тэгу
/// </summary>
function FindRadioButtonsFromTag(const aGroup:TGroupBox; aTag:integer):TRadioButton;
/// <summary>
///    включить радиокнопку по её тэгу
/// </summary>
function CheckRadioButtonFromTag(const aGroup:TGroupBox; aTag:integer):Boolean;
///
/// <summary>
///    найти кнопку указанного типа на заданном контроле, которая нажата
///    или Checked
/// </summary>
function FindPressOrCheckControl(aPar:TControl; aCheckStateFlag:Boolean=false):TControl;
///
/// <summary>
///    Correct VerticalGridFromControlPos
///  if none Shift -> Result=false;
/// </summary>
function CorrectSBContentVerticalPositionForControl(aCont:TScrollContent; aBandCtrl:TControl):Boolean;
/// <summary>
///    SetDimension
/// </summary>

implementation

uses
{$IFDEF HOVER_LAB}
    FMX.HoverLabel,
{$ENDIF}
  FMX.Text,FMX.Edit,FMX.NumberBox,FMX.ListBox;

function CopyControlProperties(aCopyRg:Integer; aCtrl1,aCtrl2:TControl):Boolean;
 begin
  Result:=False;
     aCtrl2.TagString:=aCtrl1.TagString;
     aCtrl2.Tag:=aCtrl1.Tag;
     aCtrl2.Enabled:=aCtrl1.Enabled;
     aCtrl2.Locked:=aCtrl1.Locked;

         aCtrl2.Anchors:=aCtrl1.Anchors;
         aCtrl2.Padding.Rect:=aCtrl1.Padding.Rect;
         aCtrl2.Margins.Rect:=aCtrl1.Margins.Rect;
         aCtrl2.Position:=aCtrl1.Position;
         aCtrl2.Align:=aCtrl1.Align;
         aCtrl2.Width:=aCtrl1.Width;
         aCtrl2.Height:=aCtrl1.Height;
         aCtrl2.Opacity:=aCtrl1.Opacity;
         aCtrl2.ClipChildren:=aCtrl1.ClipChildren;
         aCtrl2.ClipParent:=aCtrl1.ClipParent;
         ///
       aCtrl2.HitTest:=aCtrl1.HitTest;
         aCtrl2.OnClick:=aCtrl1.OnClick;
         aCtrl2.OnMouseDown:=aCtrl1.OnMouseDown;
         aCtrl2.OnMouseMove:=aCtrl1.OnMouseMove;
         aCtrl2.OnMouseUp:=aCtrl1.OnMouseUp;
         aCtrl2.OnMouseWheel:=aCtrl1.OnMouseWheel;
         aCtrl2.OnMouseEnter:=aCtrl1.OnMouseEnter;
         aCtrl2.OnMouseLeave:=aCtrl1.OnMouseLeave;
         aCtrl2.OnDblClick:=aCtrl1.OnDblClick;
         aCtrl2.OnKeyDown:=aCtrl1.OnKeyDown;
         aCtrl2.OnKeyUp:=aCtrl1.OnKeyUp;
         aCtrl2.OnCanFocus:=aCtrl1.OnCanFocus;
         aCtrl2.OnEnter:=aCtrl1.OnEnter;
         aCtrl2.OnExit:=aCtrl1.OnExit;
         aCtrl2.OnResize:=aCtrl1.OnResize;
   Result:=True;
 end;

function CopyControlVisualStates(acRec:TCopyStateRecord):Boolean;
var LCsrc,LCD:TControl;
    L1,L2:TLabel;
    LB1,LB2:TButton;
    LEd1,Led2:TEdit;
    LA1,LA2:TAniIndicator;
    LP1,LP2:TProgressBar;
    LIm1,LIm2:TImage;
    {$IFDEF HOVER_LAB}
    LH1,LH2:THoverLabel;
    {$ENDIF}
    Line1,Line2:TLine;
    LR1,LR2:TRectangle;
    LCh1,LCh2:TCheckBox;
    LNumBox1,LNumBox2:TNumberBox;
    LSpBtn1,LSpBtn2:TSpeedButton;
    LComboBox1,LComboBox2:TComboBox;
    bbb:Boolean;
    i:integer;
    procedure L_SetVStates(aCtrl1,aCtrl2:TControl);
     begin
       if (cp_Visibled in acRec.Flags) or (cp_All in acRec.Flags) then
          aCtrl2.Visible:=aCtrl1.Visible;
     end;
 begin
   bbb:=False;
   Result:=False;
   i:=acRec.Src.ControlsCount;
   for I :=0 to acRec.Src.ControlsCount-1 do
    begin
      LCsrc:=acRec.Src.Controls[i];
    //  ShowMessage(LCsrc.Name+':'+LCsrc.ClassName);
      bbb:=False;
      if (LCsrc.Tag>=0) then
       while bbb=false do
        begin
         if LCsrc.ClassName='TLabel' then
          begin
            L1:=TLabel(LCsrc);
            L2:=TLabel.Create(acRec.Dest.Owner);
            L2.Parent:=acRec.Dest;
            CopyControlProperties(1,L1,L2);
            L2.StyledSettings:=L1.StyledSettings;
            L2.TextSettings:=L1.TextSettings;
            L2.StyleLookup:=L1.StyleLookup;
            L_SetVStates(L1,L2);
            L2.Text:=L1.Text;
            Break;
          end;
         if LCsrc.ClassName='TButton' then
          begin
            LB1:=TButton(LCsrc);
            LB2:=TButton.Create(acRec.Dest.Owner);
            LB2.Parent:=acRec.Dest;
            CopyControlProperties(1,LB1,LB2);
            LB2.StyledSettings:=LB1.StyledSettings;
            LB2.TextSettings:=LB1.TextSettings;
            LB2.StyleLookup:=LB1.StyleLookup;
            LB2.Text:=LB1.Text;
            L_SetVStates(LB1,LB2);
             Break;
          end;
          if LCsrc.ClassName='TEdit' then
          begin
            LEd1:=TEdit(LCsrc);
            LEd2:=TEdit.Create(acRec.Dest.Owner);
            LEd2.Parent:=acRec.Dest;
            CopyControlProperties(1,LEd1,LEd2);
            LEd2.StyledSettings:=LEd1.StyledSettings;
            LEd2.TextSettings:=LEd1.TextSettings;
            Led2.KeyboardType:=Led1.KeyboardType;
            Led2.KillFocusByReturn:=Led1.KillFocusByReturn;
            Led2.MaxLength:=Led1.MaxLength;
            Led2.Password:=Led1.Password;
            Led2.ReadOnly:=Led1.ReadOnly;
            Led2.ReturnKeyType:=Led1.ReturnKeyType;
            Led2.Caret.Assign(LEd1.Caret);
            LEd2.StyleLookup:=LEd1.StyleLookup;
            LEd2.Text:=LEd1.Text;
            L_SetVStates(LEd1,LEd2);
             Break;
          end;
         if LCsrc.ClassName='TAniIndicator' then
          begin
            La1:=TAniIndicator(LCsrc);
            La2:=TAniIndicator.Create(acRec.Dest.Owner);
            La2.Parent:=acRec.Dest;
            CopyControlProperties(1,La1,La2);
            LA2.Style:=LA1.Style;
            La2.StyleLookup:=La1.StyleLookup;
            LA2.EnableDragHighlight:=LA1.EnableDragHighlight;
            L_SetVStates(LA1,LA2);
             Break;
          end;
         if LCsrc.ClassName='TProgressBar' then
          begin
            LP1:=TProgressBar(LCsrc);
            LP2:=TProgressBar.Create(acRec.Dest.Owner);
            LP2.Parent:=acRec.Dest;
            CopyControlProperties(1,LP1,LP2);
            LP2.Max:=LP1.Max; // ~
            LP2.Min:=LP1.Min; // ~
            LP2.Value:=LP1.Value; // ~
            LP2.StyleLookup:=LP1.StyleLookup;
            L_SetVStates(LP1,LP2);
             Break;
          end;
         if LCsrc.ClassName='TImage' then
          begin
             LIm1:=TImage(LCsrc);
             LIm2:=TImage.Create(acRec.Dest.Owner);
             LIm2.Parent:=acRec.Dest;
             CopyControlProperties(1,LIm1,LIm2);
             LIm2.MultiResBitmap.Assign(LIm1.MultiResBitmap);
             LIm2.WrapMode:=LIm1.WrapMode;
             L_SetVStates(LIm1,LIm2);
             Break;
          end;
         {$IFDEF HOVER_LAB}
         if LCsrc.ClassName='THoverLabel' then
          begin
             LH1:=THoverLabel(LCsrc);
             LH2:=THoverLabel.Create(acRec.Dest.Owner);
             LH2.Parent:=acRec.Dest;
             CopyControlProperties(1,LH1,LH2);
             LH2.StyledSettings:=LH1.StyledSettings;
             LH2.TextSettings:=LH1.TextSettings;
             LH2.StyleLookup:=LH1.StyleLookup;
             LH2.AssignSettings(1,LH1);
             LH2.Text:=LH1.Text;
             L_SetVStates(LH1,LH2);
            Break;
          end;
         {$ENDIF}
         if LCsrc.ClassName='TLine' then
          begin
             Line1:=TLine(LCsrc);
             Line2:=TLine.Create(acRec.Dest.Owner);
             Line2.Parent:=acRec.Dest;
             CopyControlProperties(1,Line1,Line2);
             Line2.LineType:=Line1.LineType;
             Line2.Stroke.Assign(Line1.Stroke);
             L_SetVStates(Line1,Line2);
            Break;
          end;
         if LCsrc.ClassName='TRectangle' then
          begin
             LR1:=TRectangle(LCsrc);
             LR2:=TRectangle.Create(acRec.Dest.Owner);
             LR2.Parent:=acRec.Dest;
             LR2.Fill.Assign(LR1.Fill);
             LR2.Stroke.Assign(LR1.Stroke);
             //
             CopyControlProperties(1,LR1,LR2);
             LR2.Corners:=LR1.Corners;
             LR2.Sides:=LR1.Sides;
             LR2.CornerType:=LR1.CornerType;
             LR2.XRadius:=LR1.XRadius;
             LR2.YRadius:=LR1.YRadius;
             L_SetVStates(LR1,LR2);
            Break;
          end;
         if LCsrc.ClassName='TCheckBox' then
          begin
             LCh1:=TCheckBox(LCsrc);
             LCh2:=TCheckBox.Create(acRec.Dest.Owner);
             LCh2.Parent:=acRec.Dest;
             LCh2.Text:=LCh1.Text;
             LCh2.IsChecked:=(LCh1.IsChecked=True);
            // LCh2.IsInflated
             LCh2.Enabled:=LCh1.Enabled;
             /// важен порядок
             CopyControlProperties(1,LCh1,LCh2);
             ///
             L_SetVStates(LCh1,LCh2);
            Break;
          end;
         if LCsrc.ClassName='TNumberBox' then
          begin
             LNumBox1:=TNumberBox(LCsrc);
             LNumBox2:=TNumberBox.Create(acRec.Dest.Owner);
             LNumBox2.Parent:=acRec.Dest;
            // LNumBox2.Text:=LNumBox1.Text;
             LNumBox2.ValueType:=LNumBox1.ValueType;
             LNumBox2.ValueRange:=LNumBox1.ValueRange; // Min_Max
             LNumBox2.Value:=LNumBox1.Value;
             LNumBox2.DecimalDigits:=LNumBox1.DecimalDigits;
            // LCh2.IsInflated
             LNumBox2.Enabled:=LNumBox1.Enabled;
             /// важен порядок
             CopyControlProperties(1,LNumBox1,LNumBox2);
             LNumBox2.StyledSettings:=LNumBox1.StyledSettings;
             LNumBox2.TextSettings:=LNumBox1.TextSettings;
             LNumBox2.StyleLookup:=LNumBox1.StyleLookup;
             LNumBox2.HorzIncrement:=LNumBox1.HorzIncrement;
             LNumBox2.VertIncrement:=LNumBox1.VertIncrement;
             ///
             L_SetVStates(LNumBox1,LNumBox2);
            Break;
          end;
         if LCsrc.ClassName='TSpeedButton' then
          begin
            LSpBtn1:=TSpeedButton(LCsrc);
            LSpBtn2:=TSpeedButton.Create(acRec.Dest.Owner);
            LSpBtn2.Parent:=acRec.Dest;
            CopyControlProperties(1,LSpBtn1,LSpBtn2);
            LSpBtn2.StyledSettings:=LSpBtn1.StyledSettings;
            LSpBtn2.TextSettings:=LSpBtn1.TextSettings;
            LSpBtn2.StyleLookup:=LSpBtn1.StyleLookup;
            L_SetVStates(LSpBtn1,LSpBtn2);
            Break;
          end;
         if LCsrc.ClassName='TComboBox' then
          begin
            LComboBox1:=TComboBox(LCsrc);
            LComboBox2:=TComboBox.Create(acRec.Dest.Owner);
            LComboBox2.Parent:=acRec.Dest;
            CopyControlProperties(1,LComboBox1,LComboBox2);
            LComboBox2.DropDownCount:=LComboBox1.DropDownCount;
            LComboBox2.DropDownKind:=LComboBox1.DropDownKind;
            LComboBox2.ItemWidth:=LComboBox1.ItemWidth;
            LComboBox2.ItemHeight:=LComboBox1.ItemHeight;
            LComboBox2.OnChange:=LComboBox1.OnChange;
            LComboBox2.Items.Assign(LComboBox1.Items);
            LComboBox2.StyleLookup:=LComboBox1.StyleLookup;
            L_SetVStates(LComboBox1,LComboBox2);
            Break;
          end;
        //ShowMessage(LCsrc.Name+':'+LCsrc.ClassName);
        bbb:=True;
       end;
    end;
 end;

function SetValueToControl(aCtrl:TControl; const aValue:Variant):Boolean;
var LCBox:TComboBox;
    i:Integer;
   // LS:string;
 begin
   if VarIsNull(aValue) then
      begin
        Result:=False;
        Exit;
      end;
   Result:=True;
   if aCtrl is TLabel then
    begin
      TLabel(aCtrl).Text:=aValue;
      Exit;
    end;
   if aCtrl.ClassName='TEdit' then
    begin
      TEdit(aCtrl).Text:=aValue;
      Exit;
    end;
   if aCtrl is TProgressBar then
    begin
      TProgressBar(aCtrl).Value:=aValue;
      Exit;
    end;
   if aCtrl is TCheckBox then
    begin
      TCheckBox(aCtrl).IsChecked:=aValue;
      Exit;
    end;
   if aCtrl is TNumberBox then
    begin
      TNumberBox(aCtrl).Value:=aValue;
      Exit;
    end;
   if aCtrl is TComboBox then
    begin
      LCBox:=TComboBox(aCtrl);
      i:=LCBox.Items.IndexOf(aValue);
      if i>=0 then
         LCBox.ItemIndex:=i
      else LCBox.ItemIndex:=-1; // ?
      Exit;
    end;
   Result:=False;
 end;

function GetValueFromControl(aCtrl:TControl):Variant;
var LCBox:TComboBox;
    LNumBox:TNumberBox;
   // LS:string;
 begin
   Result:=null;
   if aCtrl is TLabel then
    begin
      Result:=TLabel(aCtrl).Text;
      Exit;
    end;
   if aCtrl.ClassName='TEdit' then
    begin
      Result:=TEdit(aCtrl).Text;
      Exit;
    end;
   if aCtrl is TProgressBar then
    begin
      Result:=TProgressBar(aCtrl).Value;
      Exit;
    end;
   if aCtrl is TCheckBox then
    begin
      Result:=(TCheckBox(aCtrl).IsChecked=True);
      Exit;
    end;
   if aCtrl is TNumberBox then
    begin
      LNumBox:=TNumberBox(aCtrl);
      if LNumBox.ValueType=TNumValueType.Integer then
         Result:=Trunc(LNumBox.Value)
      else
         Result:=LNumBox.Value;
      Exit;
    end;
   if aCtrl is TComboBox then
    begin
      LCBox:=TComboBox(aCtrl);
      if LCBox.ItemIndex>=0 then
         Result:=LCBox.Items[LCBox.ItemIndex];
      Exit;
    end;
   Result:=False;
  end;

function GetTextFromControl(aCtrl:TControl; const aEmptyStr:string):string;
var LNumBox:TNumberBox;
   // LComboBox:TComboBox;
 begin
  Result:=aEmptyStr;
  if aCtrl is TNumberBox then
    begin
      LNumBox:=TNumberBox(aCtrl);
      Exit(LNumBox.Text);
    end;
 { if aCtrl is TComboBox then
    begin
      LComboBox:=TComboBox(aCtrl);
      Exit(LComboBox.);
    end;
    }
 end;

function SetDimenstionToControl(aCtrl:TControl; const aMin,aMax:Single):Boolean;
var LNumBox:TNumberBox;
    LPBar:TProgressBar;
  //  LValue:Single;
 begin
   Result:=False;
   if aCtrl is TProgressBar then
    begin
      LPBar:=TProgressBar(aCtrl);
      LPBar.Min:=aMin;
      LPBar.Max:=aMax;
      Result:=True;
      Exit;
    end;
   if aCtrl is TNumberBox then
    begin
      LNumBox:=TNumberBox(aCtrl);
      LNumBox.Min:=aMin;
      LNumBox.Max:=aMax;
      Result:=True;
      Exit;
    end;
 end;

function SetIncrementToControl(aCtrl:TControl; aHorDelta,aVertDelta:single):Boolean;
var LNumBox:TNumberBox;
 begin
   Result:=false;
   if aCtrl is TNumberBox then
    begin
      LNumBox:=TNumberBox(aCtrl);
      if aHorDelta>=0 then
         LNumBox.HorzIncrement:=aHorDelta
      else LNumBox.HorzIncrement:=0;
      if aVertDelta>=0 then
         LNumBox.VertIncrement:=aVertDelta
      else LNumBox.VertIncrement:=0;
      Result:=True;
      Exit;
    end;

 end;


function GetControlInParent(aPar:TControl; aClass:TClass; aTag:integer):TControl;
 var i:Integer;
 begin
    Result:=nil;
  i:=0;
  while i<apar.ControlsCount do
    begin
      if aPar.Controls[i].ClassType=aClass then
       if (aTag=aPar.Controls[i].Tag) then
        begin
          Result:=aPar.Controls[i];
          break;
        end;
      Inc(i);
    end;
 end;

function FindFirstControlInParent(aPar:TControl; aTag:integer):TControl;
var LCtrl:TControl;
 begin
  Result:=nil;
  for LCtrl in aPar.Controls do
    if LCtrl.Tag=aTag then
       begin
         Result:=LCtrl;
         Break;
       end;
 end;


procedure GetTagDimension(aPar:TControl; var aMinTag,aMaxTag:integer; aOnlyVisibleFlag:Boolean=true);
var LCtrl:TControl;
 begin
   aMinTag:=10000000; aMaxTag:=-1;
   for LCtrl in aPar.Controls do
      if (aOnlyVisibleFlag=False) or (LCtrl.Visible=True) then
       begin
         if (LCtrl.Tag>0) and (LCtrl.Tag<aMinTag) then
             aMinTag:=LCtrl.Tag;
         if (LCtrl.Tag>0) and (LCtrl.Tag>aMaxTag) then
             aMaxTag:=LCtrl.Tag;
       end;
   if (aMinTag=10000000) then
      if aMaxTag<>-1 then aMinTag:=aMaxTag
      else aMintag:=0;
   if (aMaxTag=-1) then
      if aMinTag<>10000000 then aMaxTag:=aMinTag
      else aMaxtag:=0;
 end;

 function ClearLayouts(const aParent:TControl):Integer;
 var i:Integer;
     LPar:TControl;
  begin
    Result:=0;
    Lpar:=aParent;
    if aParent is TVertScrollBox then
      LPar:=TVertScrollBox(aParent).Content;
    i:=0;
    while i<LPar.ControlsCount do
     begin
       if LPar.Controls[i] is TLayout then
         begin
          LPar.Controls[i].Free;
          Inc(Result);
         end
       else Inc(i);
     end;
  end;


procedure ModifyCtrlFocusEvents;
 var i:Integer;
     LPar,LC:TControl;
  begin
    Lpar:=aParent;
    if aParent is TVertScrollBox then
      LPar:=TVertScrollBox(aParent).Content;
    i:=0;
    while i<LPar.ControlsCount do
     begin
      LC:=LPar.Controls[i];
       if not Assigned(LC.OnMouseDown) then
          LC.OnMouseDown:=aMouseEvent;
       if not Assigned(LC.OnKeyDown) then
          LC.OnKeyDown:=aKeyEvent;
       if not Assigned(LC.OnEnter) then
          LC.OnEnter:=aEvent;
       Inc(i);
     end;
  end;


 ///////////////////////////////////////////////////////////////////////
 ///
 ///
 /// <summary>
 ///      корректировка стиля для групбоксов
 /// </summary>
  function GroupBox_CorrectStyle(aSenderObj:TObject):Boolean;
var LObj:TFmxObject;
    LRect:TRectangle;
    LText:TText;
    LgrBox:TGroupBox;
 begin
    Result:=False;
    if (Assigned(aSenderObj)=False) or (aSenderObj is TGroupBox=False) then
       Exit
    else LgrBox:=TGroupBox(aSenderObj);
   // if correctFlag=true then begin Result:=True; Exit; end;
    LText:=nil; LRect:=nil;
    LObj:=LGRBox.FindStyleResource('trect_caption');
    if (LObj<>nil) and (LObj is TRectangle) then
       LRect:=TRectangle(Lobj);
    LObj:=LGRBox.FindStyleResource('text');
    if (LObj<>nil) and (LObj is TText) then
       LText:=TText(Lobj);
    if (LText<>nil) and (LRect<>nil) then
     begin
       if LText.Text='' then LRect.Visible:=False
       else
        begin
          LRect.SetBounds(LText.Position.X-4,LText.Position.Y-2,LText.Width+8,LText.Height+5);
        end;
       Result:=True;
     end;
   // correctFlag:=True;
 end;


procedure RealignRadioButtons(const aGroup:TGroupBox; aHomeTag:Integer=0);
var i,k,LCC:integer;
    LR,LH:Single;
 begin
   if aGroup.ChildrenCount=0 then Exit;
   LCC:=1;
   for I :=0 to aGroup.ChildrenCount-1 do
    if (aGroup.Children[i] is TRadioButton) and
       (aGroup.Children[i].Tag>0) and (TRadioButton(aGroup.Children[i]).Visible=true) then
          Inc(LCC);
   ///
   if LCC=0 then Exit;
   LR:=aGroup.Height/LCC;
   for I :=0 to aGroup.ChildrenCount-1 do
   begin
    if (aGroup.Children[i] is TRadioButton) and
       (aGroup.Children[i].Tag>0) and (TRadioButton(aGroup.Children[i]).Visible=true) then
      begin
        k:=aGroup.Children[i].tag-aHomeTag;
        LH:=0.5*TRadioButton(aGroup.Children[i]).Height;
        TRadioButton(aGroup.Children[i]).Position.Y:=k*LR-LH;
      end
   end;
 end;

 function FindRadioButtonCheckTag(const aGroup:TGroupBox):Integer;
var i:Integer;
 begin
   Result:=-1;
   i:=0;
   while i<aGroup.ChildrenCount do
    begin
      if (aGroup.Children[i] is TRadioButton) and (aGroup.Children[i].Tag>0) then
         if TRadioButton(aGroup.Children[i]).IsChecked=True then
           begin
             Result:=aGroup.Children[i].Tag;
             Break;
           end;
      Inc(i);
    end;
 end;

function FindRadioButtonsFromTag(const aGroup:TGroupBox; aTag:integer):TRadioButton;
var i:Integer;
 begin
   Result:=nil;
   i:=0;
   while i<aGroup.ChildrenCount do
    begin
      if (aGroup.Children[i] is TRadioButton) and (aGroup.Children[i].Tag=aTag) then
           begin
             Result:=TRadioButton(aGroup.Children[i]);
             Break;
           end;
      Inc(i);
    end;
 end;

function CheckRadioButtonFromTag(const aGroup:TGroupBox; aTag:integer):Boolean;
var i:Integer;
 begin
   Result:=False;
   i:=0;
   while i<aGroup.ChildrenCount do
    begin
      if (aGroup.Children[i] is TRadioButton) and (aGroup.Children[i].Tag=aTag) and
          (TRadioButton(aGroup.Children[i]).Visible=True) and
          (TRadioButton(aGroup.Children[i]).Enabled=True) then
          begin
            TRadioButton(aGroup.Children[i]).IsChecked:=True;
            Result:=True;
             Break;
          end;
      Inc(i);
    end;
 end;

function FindPressOrCheckControl(aPar:TControl; aCheckStateFlag:Boolean=false):TControl;
 var i:Integer;
 begin
  Result:=nil;
  i:=0;
  while i<apar.ControlsCount do
    begin
       if (Result=nil) and
          (aPar.Controls[i] is TCustomButton) and (TCustomButton(aPar.Controls[i]).IsPressed=True) then
               Result:=aPar.Controls[i];
       if (Result=nil) and
          (aPar.Controls[i] is TRadioButton) then
           begin
            if (aCheckStateFlag=False) and (TRadioButton(aPar.Controls[i]).IsPressed=True) then
                Result:=aPar.Controls[i]
            else
                if (aCheckStateFlag=true) and (TRadioButton(aPar.Controls[i]).IsChecked=True) then
                Result:=aPar.Controls[i];
           end;
       if (Result=nil) and
          (aPar.Controls[i] is TCheckBox) then
           begin
            if (aCheckStateFlag=False) and (TCheckBox(aPar.Controls[i]).IsPressed=True) then
                Result:=aPar.Controls[i]
            else
                if (aCheckStateFlag=true) and (TCheckBox(aPar.Controls[i]).IsChecked=True) then
                Result:=aPar.Controls[i];
           end;
       if Assigned(Result) then
          Break;
       Inc(i);
    end;
 end;

 function CorrectSBContentVerticalPositionForControl(aCont:TScrollContent; aBandCtrl:TControl):Boolean;
 var LShiftY,LDeltaY:Single;
  begin
   Result:=False;
   LDeltaY:=0;
   LShiftY:=aCont.ScrollBox.ViewportPosition.Y;
   if (aBandCtrl.Position.Y+aBandCtrl.Height)>LShiftY+aCont.Height then
      LDeltaY:=(LShiftY+aCont.Height)-(aBandCtrl.Position.Y+aBandCtrl.Height)
   else
      if (aBandCtrl.Position.Y<LShiftY) then
          LDeltaY:=LShiftY-aBandCtrl.Position.Y;
   ///
   if LDeltaY<>0 then
    begin
      aCont.ScrollBox.ScrollBy(0,LDeltaY);
      Result:=True;
    end;
  end;


end.
