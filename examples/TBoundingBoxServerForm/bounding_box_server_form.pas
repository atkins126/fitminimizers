unit bounding_box_server_form;

interface

uses
  {$IFNDEF Lazarus}
    Winapi.Windows, Winapi.Messages,
    System.SysUtils, System.Variants, System.Classes,
    Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
    Vcl.StdCtrls, Vcl.Buttons, System.StrUtils,
  {$ELSE}
    SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, Buttons,
    StdCtrls, StrUtils, Windows,
  {$ENDIF}
    Contnrs, SimpMath, Math3d, downhill_simplex_handler;

{$ASSERTIONS ON}

type
    p3DVector = ^T3DVector;
    T3DVector = record
        FVector: TDoubleVector3;
    end;

    { TBoundingBoxServerForm }
    { Demonstrates the simplest way of integration of algorithm into application.
      The form directly implements IDownhillSimplexServer interface. }
    TBoundingBoxServerForm = class(TForm)
        ComboBoxFiles: TComboBox;
        CheckBoxRandomData: TCheckBox;
        Label1: TLabel;
        Label2: TLabel;
        Label3: TLabel;
        Ed_IniParamLenght: TEdit;
        Ed_FinalTolerance: TEdit;
        Ed_ExitDerivate: TEdit;
        Label4: TLabel;
        Label5: TLabel;
        Label6: TLabel;Memo1: TMemo;
        Memo2: TMemo;
        BitBtn1: TBitBtn;
        ButtonRandomTest: TButton;
        ButtonBruteForce: TButton;
        ButtonStop: TButton;
        function GetIniParamLenght: Double;
        procedure OutputResults;
        procedure BitBtn1Click(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure PostProcessStatistics;
        procedure ButtonBruteForceClick(Sender: TObject);
        procedure ButtonStopClick(Sender: TObject);
        procedure ButtonRandomTestClick(Sender: TObject);
        function DoOptimizeVolume(iAlpha, iBeta, iGamma: Double; iDHS_InitParamLength: Double): double;
        function FindMinBoxByVolume(var iMinCoords, iMaxCoords: TDoubleVector3): double;
    private
        { Minimum bounding box problem. }
        fDownHillSimplexHandler: TDownHillSimplexHandler;

        FilePath: String;

        { Angles describing rotation of coordinate system (in degrees). }
        Alpha, Beta, Gamma: Double;

        { Vectors containing triplets of maximum and minimum coordinates of
          model points. They are used to compute bounding box volume. }
        BoxMinCoords, BoxMaxCoords: TDoubleVector3;
        BoxVolume: Double;

        { DownHillSimplex Algorythm statistical details}
        DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount: integer;

        ShowAlgoDetails: boolean;

        Stop: Boolean;

        { Executes optimization algorithm. }
        procedure OptimizeVolume(iAlpha, iBeta, iGamma: Double; iDHS_InitParamLength: Double; iShowDetails:Boolean);

        procedure LoadObjPointCloud(iFileName:String; iAlpha, iBeta, iGamma: single);
        procedure GenerateRandomPointCloud;
        function DegToRad(Deg: Double): Double;
    public
        { Public declarations }
    end;

var
    BoundingBoxServerForm: TBoundingBoxServerForm;
    PointCloud: TList;

implementation

{$R *.dfm}

procedure SortUp(var iS1, iS2, iS3: double);
var fTmp: double;
begin
  if iS2 < iS1 then begin
    fTmp:= iS1;
    iS1:= iS2;
    iS2:= fTmp;
  end;
  if iS3 < iS2 then begin
    fTmp:= iS2;
    iS2:= iS3;
    iS3:= fTmp;
    if iS2 < iS1 then begin
      fTmp:= iS1;
      iS1:= iS2;
      iS2:= fTmp;
    end;
  end;
end;

function ConvertValue(iConvStr: String; var iValue: double): Boolean;
var  fCode: Integer;
begin
  Result:= True;
  if Pos(',', iConvStr) > 0 then iConvStr[Pos(',', iConvStr)]:= '.';
  if Pos('�', iConvStr) > 0 then iConvStr[Pos('�', iConvStr)]:= ' ';
  iConvStr:= Trim(iConvStr);
  Val(iConvStr, iValue, fCode);
  if fCode <> 0 then begin
    Result:= False;
  end;
end;

{ TBoundingBoxServerForm }

procedure TBoundingBoxServerForm.FormCreate(Sender: TObject);
var fSearchResult: TSearchRec;
    fExt: string;
begin
  fDownHillSimplexHandler:= nil;
  FilePath:= ExtractFilePath(ParamStr(0));
  ComboBoxFiles.Items.Clear;
  if FindFirst(FilePath + '*.*', faAnyFile, fSearchResult) = 0 then begin
    repeat
      fExt:= LowerCase(ExtractFileExt(fSearchResult.Name));
      if (fExt = '.obj') then begin
        ComboBoxFiles.Items.Add(fSearchResult.Name);
      end;
    until FindNext(fSearchResult) <> 0;
  end;
  ComboBoxFiles.ItemIndex:= 0;
end;

procedure TBoundingBoxServerForm.OptimizeVolume(iAlpha, iBeta, iGamma: Double; iDHS_InitParamLength: Double; iShowDetails:Boolean);
var fFinalTolerance, fExitDerivate: double;
begin
   if not ConvertValue(Ed_FinalTolerance.Text, fFinalTolerance) then begin
     fFinalTolerance:= 0.00001; //default Value
   end;
   if not ConvertValue(Ed_ExitDerivate.Text, fExitDerivate) then begin
     fFinalTolerance:= 0.5; //default Value
   end;
   fDownHillSimplexHandler:= TDownHillSimplexHandler.Create(self);
   fDownHillSimplexHandler.ShowAlgoDetails:= iShowDetails;
   fDownHillSimplexHandler.SetExitParameters(fFinalTolerance, fExitDerivate);
   fDownHillSimplexHandler.OptimizeBoundingBox(iAlpha, iBeta, iGamma, iDHS_InitParamLength);
   // get the optiomization results
   Alpha:= fDownHillSimplexHandler.Alpha;
   Beta:= fDownHillSimplexHandler.Beta;
   Gamma:= fDownHillSimplexHandler.Gamma;
   // get box details
   BoxVolume:= fDownHillSimplexHandler.BoxVolume;
   BoxMinCoords:= fDownHillSimplexHandler.BoxMinCoords;
   BoxMaxCoords:= fDownHillSimplexHandler.BoxMaxCoords;
   // algorithm statistics
   DHS_CycleCount:= fDownHillSimplexHandler.DHS_CycleCount;
   DHS_EvaluationCount:= fDownHillSimplexHandler.DHS_EvaluationCount;
   DHS_RestartCount:= fDownHillSimplexHandler.DHS_RestartCount;
   fDownHillSimplexHandler.Free;
   fDownHillSimplexHandler:= nil;
end;

function TBoundingBoxServerForm.GetIniParamLenght: Double;
begin
   if not ConvertValue(Ed_IniParamLenght.Text, Result) then begin
     Result:= 37; //default Value
   end;
end;

function TBoundingBoxServerForm.DoOptimizeVolume(iAlpha, iBeta, iGamma: Double; iDHS_InitParamLength: Double): Double;
var
  fPerformanceFrequency, fStartTime, fEndTime: Int64;
begin
  QueryPerformanceFrequency(fPerformanceFrequency);
  QueryPerformanceCounter(fStartTime);
  OptimizeVolume(iAlpha, iBeta, iGamma, iDHS_InitParamLength, False);
  QueryPerformanceCounter(fEndTime);
  Result:= (fEndTime - fStartTime) / fPerformanceFrequency;
end;

procedure TBoundingBoxServerForm.OutputResults;
var
  fDelta: TDoubleVector3;
begin
  Memo1.Lines.Add('');
  if CheckBoxRandomData.Checked then
    Memo1.Lines.Add('Random Points')
  else
    Memo1.Lines.Add('File: ' + ComboBoxFiles.Text);
  Memo1.Lines.Add('No of Points: ' + Format(' %10d', [PointCloud.Count]));
  Memo1.Lines.Add('');
  Memo1.Lines.Add('Minimum Volume    : ' + Format(' %10.4f', [BoxVolume]));
  Memo1.Lines.Add('');
  Memo1.Lines.Add(Format('Rotation Angles   :   Alpha: %.4f Beta: %.4f Gamma: %.4f', [Alpha, Beta, Gamma]));
  Memo1.Lines.Add('');
  fDelta[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
  fDelta[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
  fDelta[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
  Memo1.Lines.Add('Minimum Box       : ' + Format(' %10.4f %10.4f %10.4f', [fDelta[1], fDelta[2], fDelta[3]]));
  SortUp(fDelta[1], fDelta[2], fDelta[3]);
  Memo1.Lines.Add('Minimum Box sorted: ' + Format(' %10.4f %10.4f %10.4f', [fDelta[1], fDelta[2], fDelta[3]]));
  Application.ProcessMessages;
end;

procedure TBoundingBoxServerForm.BitBtn1Click(Sender: TObject);
var FileName: string;
begin
    ShowAlgoDetails:= True;
    Stop:= False;
    Memo1.Lines.Clear;
    Memo2.Lines.Clear;

    if CheckBoxRandomData.Checked then
    begin
        GenerateRandomPointCloud;
    end
    else
    begin
        //  Uses model data.
        FileName:= FilePath + ComboBoxFiles.Text;
        LoadObjPointCloud(FileName, 0, 45, 45);
    end;
    OptimizeVolume(0, 0, 0, GetIniParamLenght, True);
    OutputResults;
end;

procedure TBoundingBoxServerForm.PostProcessStatistics;
const
  cCriterion01 = 0.001; // criterion for relative deviation pass/fail; e.g. 0.01 => 1%
  cCriterion1 = 0.01; // criterion for relative deviation pass/fail; e.g. 0.01 => 1%
var x: Integer;
  fP1, fCode: Integer;
  fString, fString2, fRateing: string;
  fValue: Single;
  fMinVolume, fDeviation, fSumTime, fX, fY, fZ: Double;
  fPassCount01, fFailCount01, fPassCount1, fFailCount1, fSumTimeCount: Integer;
  fSL: TStringList;
begin
  fMinVolume:= 1e20;
  //get optimized MinVolume
  for x:= 0 to Memo2.Lines.Count - 1 do begin
    fString:= Trim(Memo2.Lines[x]);
    fP1:= PosEx(' ', fString, 1);
    if fP1 > 0 then begin
      fString:= Trim(Copy(fString, fP1, 1024));
      fP1:= PosEx(' ', fString, 1);
      if fP1 > 0 then begin
        fString2:= Trim(Copy(fString, fP1, 1024));
        fString:= Trim(Copy(fString, 1, fP1 - 1));
        fString:= StringReplace(fString, ',', '.', [rfReplaceAll]);
        Val(fString, fValue, fCode);
        if fCode = 0 then begin
          if fValue < fMinVolume then begin
            fMinVolume:= fValue;
            fP1:= PosEx('(', fString2, 1);
            fString2:= Trim(Copy(fString2, fP1 + 1, 1024));
            fP1:= PosEx(')', fString2, 1);
            fString2:= Trim(Copy(fString2, 1, fP1 - 1));
            fString2:= StringReplace(fString2, ',', '.', [rfReplaceAll]);
            fP1:= PosEx(' ', fString2, 1);
            fString:= Trim(Copy(fString2, 1, fP1 - 1));
            Val(fString, fX, fCode);
            fString2:= Trim(Copy(fString2, fP1 + 1, 1024));
            fP1:= PosEx(' ', fString2, 1);
            fString:= Trim(Copy(fString2, 1, fP1 - 1));
            Val(fString, fY, fCode);
            fString:= Trim(Copy(fString2, fP1 + 1, 1024));
            Val(fString, fZ, fCode);
          end;
        end;
      end
    end;
  end;
  //get optimized Volume Pass/Fail statistics
  fPassCount01:= 0;
  fFailCount01:= 0;
  fPassCount1:= 0;
  fFailCount1:= 0;
  Memo2.Lines.BeginUpdate;
  fSL:= TStringList.Create;
  fSL.Duplicates:= dupAccept;
  if fMinVolume > 0 then begin
    for x:= 0 to Memo2.Lines.Count - 1 do begin
      fString:= Trim(Memo2.Lines[x]);
      fP1:= PosEx(' ', fString, 1);
      if fP1 > 0 then begin
        fString:= Trim(Copy(fString, fP1, 1024));
        fP1:= PosEx(' ', fString, 1);
        if fP1 > 0 then begin
          fString:= Trim(Copy(fString, 1, fP1 - 1));
          fString:= StringReplace(fString, ',', '.', [rfReplaceAll]);
          Val(fString, fValue, fCode);
          if fCode = 0 then begin
            fDeviation:= (fValue - fMinVolume) / fMinVolume;
            fRateing:= 'Pass';
            if fDeviation < cCriterion1 then Inc(fPassCount1)
            else begin
              Inc(fFailCount1);
              fRateing:= 'F1'
            end;
            if fDeviation < cCriterion01 then Inc(fPassCount01)
            else begin
              Inc(fFailCount01);
              fRateing:= 'F01'
            end;
            fSL.Add (Memo2.Lines[x] + ' - ' + fRateing);
          end;
        end
      end;
    end;
  end;
  Memo2.Clear;
  Memo2.Text:= fSL.Text;
  Memo2.Lines.EndUpdate;

  // get Time to proccess
  fSumTime:= 0;
  fSumTimeCount:= 0;
  for x:= 0 to Memo2.Lines.Count - 1 do begin
    fString:= Trim(Memo2.Lines[x]);
    fP1:= PosEx('---', fString, 1);
    if fP1 > 0 then begin
      fString:= Trim(Copy(fString, fP1 + 3, 1024));
      fP1:= PosEx('--', fString, 1);
      if fP1 > 0 then begin
        fString:= Trim(Copy(fString, 1, fP1 - 1));
        fString:= StringReplace(fString, ',', '.', [rfReplaceAll]);
        Val(fString, fValue, fCode);
        if fCode = 0 then begin
          fSumTime:= fSumTime + fValue;
          Inc(fSumTimeCount);
        end;
      end
    end;
  end;
  if fSumTimeCount > 0 then fSumTime:= fSumTime / fSumTimeCount
  else fSumTime:= 0;

  if (fPassCount01 > 0) then begin
    SortUp(fX, fY, fZ);
    Memo1.Lines.Add('');
    Memo1.Lines.Add('');
    Memo1.Lines.Add('----------------------------------------------------------------------------');
    Memo1.Lines.Add('Minimum Volume    : ' + Format('%.2f (%6.3f %6.3f %6.3f)', [fMinVolume, fX, fY, fZ]));
    Memo1.Lines.Add('----------------------------------------------------------------------------');
    Memo1.Lines.Add('Passrate 0.1%     : ' + Format('%.2f%%', [fPassCount01 / (fPassCount01 + fFailCount01) * 100]));
    Memo1.Lines.Add('----------------------------------------------------------------------------');
    Memo1.Lines.Add('Passrate 1%       : ' + Format('%.2f%%', [fPassCount1 / (fPassCount1 + fFailCount1) * 100]));
    Memo1.Lines.Add('----------------------------------------------------------------------------');
    Memo1.Lines.Add('Time Average      : ' + Format('%.4f', [fSumTime]));
    Memo1.Lines.Add('----------------------------------------------------------------------------');
  end
  else begin
    Memo1.Lines.Add('----------------------------------------------------------------------------');
    Memo1.Lines.Add('Someting''s was wrong');
    Memo1.Lines.Add('----------------------------------------------------------------------------');
  end;
end;

procedure TBoundingBoxServerForm.ButtonBruteForceClick(Sender: TObject);
const cSteps = 2;
var x, y, z: Integer;
  FileName, fResult: string;
  fAlpha, fBeta, fGamma: Single;
  fMaxDeltaVolume, fMinDeltaVolume, fDeltaVolume, fTime: Single;
  fBoxVolume: Double;
  fMinCoords, fMaxCoords, fMinDeltaCord, fMaxDeltaCord, fDeltaCord: TDoubleVector3;
begin
  FileName:= FilePath + ComboBoxFiles.Text;

  ShowAlgoDetails:= False;
  Stop:= False;
  fMaxDeltaVolume:= -1.0e20;
  fMinDeltaVolume:= 1.0e20;
  Memo1.Lines.Clear;
  Memo2.Lines.Clear;
  Application.ProcessMessages;

  // get the optimized volume and Box size
  LoadObjPointCloud(FileName, 0, 0, 0); //load it in original orientation
  fBoxVolume:= FindMinBoxByVolume(fMinCoords, fMaxCoords);

  // do the test for brute force orientation
  for x:= 0 to (179 div cSteps) do
    for y:= 0 to (179 div cSteps) do
      for z:= 0 to (179 div cSteps) do begin
        if not Stop then begin
          fAlpha:= x * cSteps;
          fBeta:= y * cSteps;
          fGamma:= z * cSteps;

          LoadObjPointCloud(FileName, fAlpha, fBeta, fGamma);
          fTime:= DoOptimizeVolume(0, 0, 0, GetIniParamLenght);
          if not Stop then begin
            //  Computes difference in volumes calculated
            //  for original and rotated orientation.
            fDeltaVolume:= (BoxVolume - fBoxVolume);
            //  Computes lengths of edges of bounding box.
            fDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
            fDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
            fDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
            //  Sorts edges.
            SortUp(fDeltaCord[1], fDeltaCord[2], fDeltaCord[3]);
            fResult:= Format(' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
              [fDeltaVolume, BoxVolume, fDeltaCord[1], fDeltaCord[2], fDeltaCord[3], Alpha, Beta, Gamma, fAlpha, fBeta, fGamma, fTime, DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount]);
            if fDeltaVolume > fMaxDeltaVolume then begin
              fMaxDeltaVolume:= fDeltaVolume;
              fMaxDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
              fMaxDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
              fMaxDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
              SortUp(fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]);
            end;
            if fDeltaVolume < fMinDeltaVolume then begin
              fMinDeltaVolume:= fDeltaVolume;
              fMinDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
              fMinDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
              fMinDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
              SortUp(fMinDeltaCord[1], fMinDeltaCord[2], fMinDeltaCord[3]);
            end;
            Memo2.Lines.Add(fResult);
            Label2.Caption:= Format('MinDelta Volume: %8.2f (%6.4f %6.4f %6.4f) ---  MaxDelta Volume: %8.2f (%6.4f %6.4f %6.4f)',
              [fMinDeltaVolume, fMinDeltaCord[1], fMinDeltaCord[2], fMinDeltaCord[3], fMaxDeltaVolume, fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]]);
          end;
          Application.ProcessMessages;
        end;
      end;
  PostProcessStatistics;
end;

procedure TBoundingBoxServerForm.ButtonRandomTestClick(Sender: TObject);
var x: Integer;
  FileName, fResult: string;
  fAlpha, fBeta, fGamma: Single;
  fMinDeltaVolume, fMaxDeltaVolume, fDeltaVolume, fTime: Single;
  fBoxVolume: Double;
  fMinCoords, fMaxCoords, fMinDeltaCord, fMaxDeltaCord, fDeltaCord: TDoubleVector3;
begin
  FileName:= FilePath + ComboBoxFiles.Text;

  ShowAlgoDetails:= False;
  Stop:= False;
  fMaxDeltaVolume:= -1.0e20;
  fMinDeltaVolume:= 1.0e20;
  Memo1.Lines.Clear;
  Memo2.Lines.Clear;
  Application.ProcessMessages;

  // get the optimized volume and Box size
  LoadObjPointCloud(FileName, 0, 0, 0); //load it in original orientation
  fBoxVolume:= FindMinBoxByVolume(fMaxCoords, fMinCoords);

  // do the test for random orientation
  Randomize;
  for x:= 0 to 99999 do begin
    if not Stop then begin
      fAlpha:= Random * 180;
      fBeta:= Random * 180;
      fGamma:= Random * 180;
      LoadObjPointCloud(FileName, fAlpha, fBeta, fGamma);

      fTime:= DoOptimizeVolume(0, 0, 0, GetIniParamLenght);
      if not Stop then begin
        fDeltaVolume:= (BoxVolume - fBoxVolume);
        fDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
        fDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
        fDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
        SortUp(fDeltaCord[1], fDeltaCord[2], fDeltaCord[3]);
        fResult:= Format(' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
          [fDeltaVolume, BoxVolume, fDeltaCord[1], fDeltaCord[2], fDeltaCord[3], Alpha, Beta, Gamma, fAlpha, fBeta, fGamma, fTime, DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount]);
        if fDeltaVolume > fMaxDeltaVolume then begin
          fMaxDeltaVolume:= fDeltaVolume;
          fMaxDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
          fMaxDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
          fMaxDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
          SortUp(fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]);
        end;
        if fDeltaVolume < fMinDeltaVolume then begin
          fMinDeltaVolume:= fDeltaVolume;
          fMinDeltaCord[1]:= BoxMaxCoords[1] - BoxMinCoords[1];
          fMinDeltaCord[2]:= BoxMaxCoords[2] - BoxMinCoords[2];
          fMinDeltaCord[3]:= BoxMaxCoords[3] - BoxMinCoords[3];
          SortUp(fMinDeltaCord[1], fMinDeltaCord[2], fMinDeltaCord[3]);
        end;
        Memo2.Lines.Add(fResult);
        Label2.Caption:= Format('MinDelta Volume: %8.2f (%6.4f %6.4f %6.4f) ---  MaxDelta Volume: %8.2f (%6.4f %6.4f %6.4f)',
          [fMinDeltaVolume, fMinDeltaCord[1], fMinDeltaCord[2], fMinDeltaCord[3], fMaxDeltaVolume, fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]]);
      end;
      Application.ProcessMessages;
    end;
  end;
  PostProcessStatistics;
end;

procedure TBoundingBoxServerForm.ButtonStopClick(Sender: TObject);
begin
  Stop:= True;
  if assigned(fDownHillSimplexHandler) then fDownHillSimplexHandler.Stop;
end;

function TBoundingBoxServerForm.FindMinBoxByVolume(var iMinCoords, iMaxCoords: TDoubleVector3): Double;
var
  fBoxVolume, fTime, fMinBoxAlpha, fMinBoxBeta, fMinBoxGamma: Double;
  fResult: string;
begin
  // 1st Optimization to get the minimum Volume
  fTime:= DoOptimizeVolume(0, 0, 0, GetIniParamLenght);
  fBoxVolume:= BoxVolume;
  fMinBoxAlpha:= Alpha;
  fMinBoxBeta:= Beta;
  fMinBoxGamma:= Gamma;
  iMaxCoords:= BoxMaxCoords;
  iMinCoords:= BoxMinCoords;
  fResult:= Format(' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
    [0.0, BoxVolume, BoxMaxCoords[1] - BoxMinCoords[1], BoxMaxCoords[2] - BoxMinCoords[2], BoxMaxCoords[3] - BoxMinCoords[3], Alpha, Beta, Gamma, 0.0, 0.0, 0.0, fTime, DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount]);
  Memo1.Lines.Add(fResult);
  Application.ProcessMessages;
  if not Stop then begin
    // 2nd Optimization to get the minimum Volume - with different start parameters
    fTime:= DoOptimizeVolume(30, 30, 30, GetIniParamLenght);
    if BoxVolume < fBoxVolume then begin
      fBoxVolume:= BoxVolume;
      fMinBoxAlpha:= Alpha;
      fMinBoxBeta:= Beta;
      fMinBoxGamma:= Gamma;
      iMaxCoords:= BoxMaxCoords;
      iMinCoords:= BoxMinCoords;
    end;
    fResult:= Format(' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
      [0.0, BoxVolume, BoxMaxCoords[1] - BoxMinCoords[1], BoxMaxCoords[2] - BoxMinCoords[2], BoxMaxCoords[3] - BoxMinCoords[3], Alpha, Beta, Gamma, 0.0, 0.0, 0.0, fTime, DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount]);
    Memo1.Lines.Add(fResult);
    Application.ProcessMessages;
    if not Stop then begin
      // 3rd Optimization to get the minimum Volume - with different start parameters
      fTime:= DoOptimizeVolume(60, 60, 60, GetIniParamLenght);
      if BoxVolume < fBoxVolume then begin
        fBoxVolume:= BoxVolume;
        fMinBoxAlpha:= Alpha;
        fMinBoxBeta:= Beta;
        fMinBoxGamma:= Gamma;
        iMaxCoords:= BoxMaxCoords;
        iMinCoords:= BoxMinCoords;
      end;
      fResult:= Format(' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
        [0.0, BoxVolume, BoxMaxCoords[1] - BoxMinCoords[1], BoxMaxCoords[2] - BoxMinCoords[2], BoxMaxCoords[3] - BoxMinCoords[3], Alpha, Beta, Gamma, 0.0, 0.0, 0.0, fTime, DHS_CycleCount, DHS_EvaluationCount, DHS_RestartCount]);
      Memo1.Lines.Add(fResult);
      Application.ProcessMessages;
    end;
  end;

  Result:= fBoxVolume;

  BoxVolume:= fBoxVolume;
  Alpha:= fMinBoxAlpha;
  Beta:= fMinBoxBeta;
  Gamma:= fMinBoxGamma;
  BoxMaxCoords:= iMaxCoords;
  BoxMinCoords:= iMinCoords;
  OutputResults;
end;

procedure TBoundingBoxServerForm.LoadObjPointCloud(iFileName: string; iAlpha, iBeta, iGamma: Single);
type TOBJCoord = record // Stores X, Y, Z coordinates
    X, Y, Z: Single;
  end;

  function GetCoords(iString: string): TOBJCoord;
  var P, P2, P3: Integer;
    fCoord: TOBJCoord;
  begin
    iString:= Trim(Copy(iString, 3, Length(iString)));
    P:= Pos(' ', iString);
    P2:= PosEx(' ', iString, P + 1);
    P3:= PosEx(' ', iString, P2 + 1);
    if P3 = 0 then P3:= 1000;
    iString:= StringReplace(iString, '.', FormatSettings.DecimalSeparator, [rfReplaceAll]);
    fCoord.X:= StrToFloat(Copy(iString, 1, P - 1));
    fCoord.Y:= StrToFloat(Copy(iString, P + 1, P2 - P - 1));
    fCoord.Z:= StrToFloat(Copy(iString, P2 + 1, P3 - P2 - 1));
    Result:= fCoord;
  end;

var x: Integer;
  F: TextFile;
  S: string;
  fCoord: TOBJCoord;
  fPoint: p3DVector;
  RotX, RotY, RotZ, Matr: TMatrix;
  fVector: T3Vector;
begin
  if PointCloud <> nil then begin
    for x:= 0 to PointCloud.Count - 1 do begin
      fPoint:= PointCloud[x];
      Dispose(fPoint);
    end;
    PointCloud.Free;
    PointCloud:= nil;
  end;
  PointCloud:= TList.Create;
  if FileExists(iFileName) then
  begin
    GetMatrixRotX(DegToRad(iAlpha), RotX);
    GetMatrixRotY(DegToRad(iBeta), RotY);
    GetMatrixRotZ(DegToRad(iGamma), RotZ);
    { Computes rotation matrix. }
    GetUnitMatrix(Matr);
    Mul3DMatrix(RotZ, Matr, Matr);
    Mul3DMatrix(RotY, Matr, Matr);
    Mul3DMatrix(RotX, Matr, Matr);

    fVector[1]:= 1;
    fVector[2]:= 0;
    fVector[3]:= 0;
    MulVectMatr(Matr, fVector);

    AssignFile(F, iFileName);
    Reset(F);
    while not (EOF(F)) do begin
      Application.ProcessMessages;
      Readln(F, S);
      if (Length(S) >= 2) and (S[1] <> '#') then
      begin
        S:= Uppercase(S);
        if (S[1] = 'V') and (S[2] = ' ') then begin
          // Read Vertex Data
          New(fPoint);
          fCoord:= GetCoords(S);
          fVector[1]:= fCoord.X;
          fVector[2]:= fCoord.Y;
          fVector[3]:= fCoord.Z;
          MulVectMatr(Matr, fVector);

          fPoint^.FVector:= fVector;
          PointCloud.Add(fPoint);
        end;
      end;
    end;
    CloseFile(F);
  end;
end;

function TBoundingBoxServerForm.DegToRad(Deg: Double): Double;
begin
    Result := Deg * Pi / 180.0;
end;

{$warnings off}
{$hints off}
procedure TBoundingBoxServerForm.GenerateRandomPointCloud;
const
    PointCount: LongInt = 10;     //  Number of points in the cloud.
    //  Dispersion boundaries.
    MaxX: double = 0.5;
    MinX: double = -0.5;
    MaxY: double = 0.5;
    MinY: double = -0.5;
    MaxZ: double = 0.5;
    MinZ: double = -0.5;
    //  Boundaries along (1,1,1) axis.
    Max111: double = 10.0;
    Min111: double = -10.0;
var
    i, x: LongInt;
    Point: p3DVector;
    Translation111: double;
begin
    Randomize;
    if PointCloud <> nil then begin
        for x := 0 to PointCloud.Count -1 do begin
          Point:= PointCloud[x];
          Dispose(Point);
        end;
        PointCloud.Free;
        PointCloud:= nil;
    end;

    PointCloud := TList.Create;

    for i := 0 to PointCount - 1 do
    begin
        new(Point);
        //  Coordinates are located mainly along (1,1,1) axis
        //  with relatively small dispersion.
        Translation111 := Min111 + Random * (Max111 - Min111);
        Point^.FVector[1] := Translation111 + MinX + Random * (MaxX - MinX);
        Point^.FVector[2] := Translation111 + MinY + Random * (MaxY - MinY);
        Point^.FVector[3] := Translation111 + MinZ + Random * (MaxZ - MinZ);

        PointCloud.Add(Point);
    end;
end;
{$hints on}
{$warnings on}

end.
