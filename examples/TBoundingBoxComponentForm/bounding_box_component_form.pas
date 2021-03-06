unit bounding_box_component_form;

interface

uses
  {$IF NOT DEFINED(FPC)}
    Winapi.Windows, Winapi.Messages,
    System.SysUtils, System.Variants, System.Classes,
    Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
    Vcl.StdCtrls, Vcl.Buttons, System.StrUtils, System.Types,
  {$ELSE}
    SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, Buttons,
    StdCtrls, StrUtils,
  {$ENDIF}
    Contnrs, RunningThread, SimpMath, Math3d, downhill_simplex_handler;

{$ASSERTIONS ON}

type
    p3DVector = ^T3DVector;

    T3DVector = record
        FVector: TDoubleVector3;
    end;

    { TBoundingBoxComponentForm }
    { Demonstrates integration of algorithm into application by means
      of form component. }
    TBoundingBoxComponentForm = class(TForm)
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
        Label6: TLabel;
        Memo1: TMemo;
        Memo2: TMemo;
        BitBtnFindMinimumBoundingBox: TBitBtn;
        ButtonRandomTest: TButton;
        ButtonBruteForce: TButton;
        ButtonStop: TButton;
        { An instance of component used for optimization in separate thread. }
        RunnerMinimumBoundingBox: TRunner;
        procedure FormDestroy(Sender: TObject);
        procedure BitBtnFindMinimumBoundingBoxClick(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure PostProcessStatistics;
        procedure ButtonBruteForceClick(Sender: TObject);
        procedure ButtonStopClick(Sender: TObject);
        procedure ButtonRandomTestClick(Sender: TObject);
        procedure RunnerMinimumBoundingBoxCompute;
        procedure RunnerMinimumBoundingBoxCreate(Runner: TRunner);
        procedure RunnerMinimumBoundingBoxOutput;

    private
        FFilePath: String;

        FShowAlgoDetails: Boolean;
        FShowPassed: Boolean;
        FStop: Boolean;
        { This "handler" instance is used to demonstrate execution of algorithm
          in separate thread by visual component TRunner attached to the form. }
        FHandlerMinimumBoundingBox: TDownHillSimplexHandler;
        { Keeps all instances of "handler" class for asynchronous operations. }
        FHandlers: TComponentList;
        { Best values obtained for a few optimization runs. }
        FBoxVolume: Double;
        FMinCoords, FMaxCoords: TDoubleVector3;
        { Optimization results of several algorithm runs. }
        FOptiResultBoxMinCoords, FOptiResultBoxMaxCoords: TDoubleVector3;
        FOptiResultBoxVolume: Double;

        function GetIniParamLenght: Double;
        procedure StopComputing;
        { Prints final results among a few runs. }
        procedure OutputResults;
        { Computes minimum box volume starting from a few initial points. }
        procedure FindMinBoxByVolume;
        { Displays computation results and removes container.
          Should be member of form because works with form controls.
          Removes handler from FHandlers list. }
        procedure OuputFindMinBoxByVolume(fDownHillSimplexHandler: TDownHillSimplexHandler);
        { Creates and returns container instance which should be destroyed by calling method. }
        function CreateHandler(iAlpha, iBeta, iGamma: Double;
            iDHS_InitParamLength: Double;
            iShowDetails: Boolean; RunId: Integer): TDownHillSimplexHandler;

        procedure LoadObjPointCloud(iFileName: String; iAlpha, iBeta, iGamma: single);
        procedure GenerateRandomPointCloud;

    public
        { Creates FHanlders before other operations. }
        constructor Create(AOwner: TComponent); override;
    end;

var
    BoundingBoxComponentForm: TBoundingBoxComponentForm;
    { Data can be accessed from different threads.
      That's ok until data aren't changed. }
    PointCloud: TList;

implementation

{$R *.dfm}

procedure SortUp(var iS1, iS2, iS3: double);
var
    fTmp: double;
begin
    if iS2 < iS1 then
    begin
        fTmp := iS1;
        iS1 := iS2;
        iS2 := fTmp;
    end;
    if iS3 < iS2 then
    begin
        fTmp := iS2;
        iS2 := iS3;
        iS3 := fTmp;
        if iS2 < iS1 then
        begin
            fTmp := iS1;
            iS1 := iS2;
            iS2 := fTmp;
        end;
    end;
end;

function ConvertValue(iConvStr: String; var iValue: double): Boolean;
var
    fCode: Integer;
begin
    Result := True;
    if Pos(',', iConvStr) > 0 then
        iConvStr[Pos(',', iConvStr)] := '.';
    if Pos('�', iConvStr) > 0 then
        iConvStr[Pos('�', iConvStr)] := ' ';
    iConvStr := Trim(iConvStr);
    Val(iConvStr, iValue, fCode);
    if fCode <> 0 then
    begin
        Result := False;
    end;
end;

{ TBoundingBoxComponentForm }

procedure TBoundingBoxComponentForm.FormCreate(Sender: TObject);
var
    fSearchResult: TSearchRec;
    fExt: string;
begin
    { Reads file list from the directory adjacent to the program directory. }
    FFilePath := ExtractFilePath(ParamStr(0));
    FFilePath := IncludeTrailingPathDelimiter(FFilePath) + '..' + PathDelim;
    FFilePath := ExpandFileName(FFilePath) + 'Models' + PathDelim;
    ComboBoxFiles.Items.Clear;
    if FindFirst(FFilePath + '*.*', faAnyFile, fSearchResult) = 0 then
    begin
        repeat
            fExt := LowerCase(ExtractFileExt(fSearchResult.Name));
            if (fExt = '.obj') then
            begin
                ComboBoxFiles.Items.Add(fSearchResult.Name);
            end;
        until FindNext(fSearchResult) <> 0;
    end;
    ComboBoxFiles.ItemIndex := 0;
end;

constructor TBoundingBoxComponentForm.Create(AOwner: TComponent);
begin
    { Must be created before inherited constructor which causes initializing
      other components. Keeps ownership and destroys all collection items. }
    FHandlers := TComponentList.Create(True);
    inherited Create(AOwner);
end;

function TBoundingBoxComponentForm.CreateHandler(iAlpha, iBeta, iGamma: Double;
    iDHS_InitParamLength: Double; iShowDetails: Boolean;
    RunId: Integer): TDownHillSimplexHandler;
var
    fFinalTolerance, fExitDerivate: double;
begin
    { This suppresses useless hints in Lazarus. }
    fFinalTolerance := 0.00001;
    fExitDerivate := 0.5;

    if not ConvertValue(Ed_FinalTolerance.Text, fFinalTolerance) then
    begin
        fFinalTolerance := 0.00001; // default value
    end;
    if not ConvertValue(Ed_ExitDerivate.Text, fExitDerivate) then
    begin
        fExitDerivate := 0.5;       // default value
    end;
    Result := TDownHillSimplexHandler.Create(self,
        iAlpha, iBeta, iGamma, iDHS_InitParamLength,
        fFinalTolerance, fExitDerivate, iShowDetails, RunId);
    { Adds to the list for asynchronous operations. }
    FHandlers.Add(Result);
end;

function TBoundingBoxComponentForm.GetIniParamLenght: Double;
begin
    { This suppresses useless hints in Lazarus. }
    Result := 37;
    if not ConvertValue(Ed_IniParamLenght.Text, Result) then
    begin
        Result := 37; //default value
    end;
end;

procedure TBoundingBoxComponentForm.FormDestroy(Sender: TObject);
begin
    StopComputing;
    FHandlers.Free;
end;

procedure TBoundingBoxComponentForm.BitBtnFindMinimumBoundingBoxClick(Sender: TObject);
var
    FileName: string;
begin
    FShowAlgoDetails := True;
    FStop := False;
    Memo1.Lines.Clear;
    Memo2.Lines.Clear;

    if CheckBoxRandomData.Checked then
    begin
        GenerateRandomPointCloud;
    end
    else
    begin
        { Uses model data. }
        FileName := FFilePath + ComboBoxFiles.Text;
        LoadObjPointCloud(FileName, 0, 45, 45);
    end;
    { Executes optimization algorithms in separate thread. }
    RunnerMinimumBoundingBox.Run;
end;

procedure TBoundingBoxComponentForm.PostProcessStatistics;
const
    cCriterion01 = 0.001; // criterion for relative deviation pass/fail; e.g. 0.0 1 => 0.1%
    cCriterion1 = 0.01;   // criterion for relative deviation pass/fail; e.g. 0.01 => 1%

var
    x: Integer;
    fP1, fCode: Integer;
    fString, fString2, fRateing: string;
    fValue: Single;
    fMinVolume, fDeviation, fSumTime, fX, fY, fZ: Double;
    fPassCount01, fFailCount01, fPassCount1, fFailCount1, fSumTimeCount: Integer;
    fSL: TStringList;
    Passed: Boolean;
begin
    fMinVolume := 1e20;
    { Gets optimized MinVolume. }
    for x := 0 to Memo2.Lines.Count - 1 do
    begin
        fString := Trim(Memo2.Lines[x]);
        fP1 := PosEx(' ', fString, 1);
        if fP1 > 0 then
        begin
            fString := Trim(Copy(fString, fP1, 1024));
            fP1 := PosEx(' ', fString, 1);
            if fP1 > 0 then
            begin
                fString2 := Trim(Copy(fString, fP1, 1024));
                fString := Trim(Copy(fString, 1, fP1 - 1));
                fString := StringReplace(fString, ',', '.', [rfReplaceAll]);
                Val(fString, fValue, fCode);
                if fCode = 0 then
                begin
                    if fValue < fMinVolume then
                    begin
                        fMinVolume := fValue;
                        fP1 := PosEx('(', fString2, 1);
                        fString2 := Trim(Copy(fString2, fP1 + 1, 1024));
                        fP1 := PosEx(')', fString2, 1);
                        fString2 := Trim(Copy(fString2, 1, fP1 - 1));
                        fString2 := StringReplace(fString2, ',', '.', [rfReplaceAll]);
                        fP1 := PosEx(' ', fString2, 1);
                        fString := Trim(Copy(fString2, 1, fP1 - 1));
                        Val(fString, fX, fCode);
                        fString2 := Trim(Copy(fString2, fP1 + 1, 1024));
                        fP1 := PosEx(' ', fString2, 1);
                        fString := Trim(Copy(fString2, 1, fP1 - 1));
                        Val(fString, fY, fCode);
                        fString := Trim(Copy(fString2, fP1 + 1, 1024));
                        Val(fString, fZ, fCode);
                    end;
                end;
            end;
        end;
    end;
    { Get optimized Volume Pass/Fail statistics. }
    fPassCount01 := 0;
    fFailCount01 := 0;
    fPassCount1 := 0;
    fFailCount1 := 0;
    Memo2.Lines.BeginUpdate;
    fSL := TStringList.Create;
    fSL.Duplicates := dupAccept;
    if fMinVolume > 0 then
    begin
        for x := 0 to Memo2.Lines.Count - 1 do
        begin
            fString := Trim(Memo2.Lines[x]);
            fP1 := PosEx(' ', fString, 1);
            if fP1 > 0 then
            begin
                fString := Trim(Copy(fString, fP1, 1024));
                fP1 := PosEx(' ', fString, 1);
                if fP1 > 0 then
                begin
                    fString := Trim(Copy(fString, 1, fP1 - 1));
                    fString := StringReplace(fString, ',', '.', [rfReplaceAll]);
                    Val(fString, fValue, fCode);
                    if fCode = 0 then
                    begin
                        fDeviation := (fValue - fMinVolume) / fMinVolume;
                        fRateing := 'Pass';
                        Passed := True;
                        if fDeviation < cCriterion1 then
                            Inc(fPassCount1)
                        else
                        begin
                            Inc(fFailCount1);
                            fRateing := 'F1';
                            Passed := False;
                        end;
                        if fDeviation < cCriterion01 then
                            Inc(fPassCount01)
                        else
                        begin
                            Inc(fFailCount01);
                            fRateing := 'F01';
                            Passed := False;
                        end;
                        if not Passed or FShowPassed then
                        begin
                            { Only "failed" tests are added to the resulting list. }
                            fSL.Add(Memo2.Lines[x] + ' - ' + fRateing);
                        end;
                    end;
                end;
            end;
        end;
    end;
    Memo2.Clear;
    Memo2.Text := fSL.Text;
    Memo2.Lines.EndUpdate;

    { Get Time to proccess. }
    fSumTime := 0;
    fSumTimeCount := 0;
    for x := 0 to Memo2.Lines.Count - 1 do
    begin
        fString := Trim(Memo2.Lines[x]);
        fP1 := PosEx('---', fString, 1);
        if fP1 > 0 then
        begin
            fString := Trim(Copy(fString, fP1 + 3, 1024));
            fP1 := PosEx('--', fString, 1);
            if fP1 > 0 then
            begin
                fString := Trim(Copy(fString, 1, fP1 - 1));
                fString := StringReplace(fString, ',', '.', [rfReplaceAll]);
                Val(fString, fValue, fCode);
                if fCode = 0 then
                begin
                    fSumTime := fSumTime + fValue;
                    Inc(fSumTimeCount);
                end;
            end;
        end;
    end;
    if fSumTimeCount > 0 then
        fSumTime := fSumTime / fSumTimeCount
    else
        fSumTime := 0;

    if (fPassCount01 > 0) then
    begin
        SortUp(fX, fY, fZ);
        Memo1.Lines.Add('');
        Memo1.Lines.Add('');
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        Memo1.Lines.Add('Minimum Volume    : ' +
            Format('%.4f (%6.3f %6.3f %6.3f)', [fMinVolume, fX, fY, fZ]));
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        fDeviation := (FOptiResultBoxVolume - fMinVolume) / fMinVolume * 100;
        Memo1.Lines.Add('Calculation Delta : ' +
            Format('%.4f (%.2f%%)', [(FOptiResultBoxVolume - fMinVolume), fDeviation]));
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        Memo1.Lines.Add('Passrate 0.1%     : ' + Format('%.4f%%',
            [fPassCount01 / (fPassCount01 + fFailCount01) * 100]));
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        Memo1.Lines.Add('Passrate 1%       : ' + Format('%.4f%%',
            [fPassCount1 / (fPassCount1 + fFailCount1) * 100]));
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        Memo1.Lines.Add('Time Average      : ' + Format('%.4f', [fSumTime]));
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
    end
    else
    begin
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
        Memo1.Lines.Add('Someting''s was wrong');
        Memo1.Lines.Add(
            '----------------------------------------------------------------------------');
    end;
end;

procedure TBoundingBoxComponentForm.ButtonBruteForceClick(Sender: TObject);
const
    cSteps = 2;
var
    x, y, z: Integer;
    FileName, fResult: string;
    fAlpha, fBeta, fGamma: Single;
    fMaxDeltaVolume, fMinDeltaVolume, fDeltaVolume: Single;
    fMinDeltaCord, fMaxDeltaCord, fDeltaCord: TDoubleVector3;
    Handler: TDownHillSimplexHandler;
    RunId: Integer;
begin
    FileName := FFilePath + ComboBoxFiles.Text;

    FShowAlgoDetails := False;
    FShowPassed := True;
    FStop := False;
    fMaxDeltaVolume := -1.0e20;
    fMinDeltaVolume := 1.0e20;
    Memo1.Lines.Clear;
    Memo2.Lines.Clear;
    Application.ProcessMessages;

    { Loads model data in original orientation. }
    LoadObjPointCloud(FileName, 0, 0, 0);
    { Computes optimized volume and box sizes. }
    FindMinBoxByVolume;

    RunId := 1;
    { Does the test for brute force orientation. }
    for x := 0 to (179 div cSteps) do
        for y := 0 to (179 div cSteps) do
            for z := 0 to (179 div cSteps) do
            begin
                if not FStop then
                begin
                    fAlpha := x * cSteps;
                    fBeta := y * cSteps;
                    fGamma := z * cSteps;

                    LoadObjPointCloud(FileName, fAlpha, fBeta, fGamma);
                    Handler :=
                        CreateHandler(0, 0, 0, GetIniParamLenght, False, RunId);
                    Handler.OptimizeBoundingBox;
                    if not FStop then
                    begin
                        { Computes difference in volumes calculated
                          for original and rotated orientation. }
                        with Handler do
                        begin
                            fDeltaVolume := (BoxVolume - FBoxVolume);
                            { Computes lengths of edges of bounding box. }
                            fDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                            fDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                            fDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                            { Sorts edges. }
                            SortUp(fDeltaCord[1], fDeltaCord[2], fDeltaCord[3]);
                            fResult :=
                                Format(
                                ' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
                                [fDeltaVolume, BoxVolume, fDeltaCord[1],
                                fDeltaCord[2], fDeltaCord[3], Alpha,
                                Beta, Gamma, fAlpha, fBeta, fGamma,
                                ComputationTime, CycleCount, EvaluationCount,
                                RestartCount]);
                            if fDeltaVolume > fMaxDeltaVolume then
                            begin
                                fMaxDeltaVolume := fDeltaVolume;
                                fMaxDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                                fMaxDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                                fMaxDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                                SortUp(fMaxDeltaCord[1], fMaxDeltaCord[2],
                                    fMaxDeltaCord[3]);
                            end;
                            if fDeltaVolume < fMinDeltaVolume then
                            begin
                                fMinDeltaVolume := fDeltaVolume;
                                fMinDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                                fMinDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                                fMinDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                                SortUp(fMinDeltaCord[1], fMinDeltaCord[2],
                                    fMinDeltaCord[3]);
                            end;
                            Memo2.Lines.Add(fResult);
                            Label2.Caption :=
                                Format(
                                'MinDelta Volume: %8.2f (%6.4f %6.4f %6.4f) ---  MaxDelta Volume: %8.2f (%6.4f %6.4f %6.4f)',
                                [fMinDeltaVolume, fMinDeltaCord[1], fMinDeltaCord[2],
                                fMinDeltaCord[3], fMaxDeltaVolume,
                                fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]]);
                        end;
                    end;
                    { Removes and frees inserted container. }
                    FHandlers.Remove(Handler);
                    Inc(RunId);
                    Application.ProcessMessages;
                end;
            end;
    PostProcessStatistics;
end;

procedure TBoundingBoxComponentForm.ButtonRandomTestClick(Sender: TObject);
var
    x: Integer;
    FileName, fResult: string;
    fAlpha, fBeta, fGamma: Single;
    fMinDeltaVolume, fMaxDeltaVolume, fDeltaVolume: Single;
    fMinDeltaCord, fMaxDeltaCord, fDeltaCord: TDoubleVector3;
    Handler: TDownHillSimplexHandler;
begin
    FileName := FFilePath + ComboBoxFiles.Text;

    FShowAlgoDetails := False;
    FStop := False;
    fMaxDeltaVolume := -1.0e20;
    fMinDeltaVolume := 1.0e20;
    Memo1.Lines.Clear;
    Memo2.Lines.Clear;
    Application.ProcessMessages;

    { Loads model data in original orientation. }
    LoadObjPointCloud(FileName, 0, 0, 0);
    { Computes optimized volume and box sizes. }
    FindMinBoxByVolume;

    { Does the test for random orientation. }
    Randomize;
    for x := 0 to 99999 do
    begin
        if not FStop then
        begin
            fAlpha := Random * 180;
            fBeta := Random * 180;
            fGamma := Random * 180;
            LoadObjPointCloud(FileName, fAlpha, fBeta, fGamma);

            Handler :=
                CreateHandler(0, 0, 0, GetIniParamLenght, False, x);
            Handler.OptimizeBoundingBox;
            if not FStop then
            begin
                with Handler do
                begin
                    fDeltaVolume := (BoxVolume - FBoxVolume);
                    fDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                    fDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                    fDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                    SortUp(fDeltaCord[1], fDeltaCord[2], fDeltaCord[3]);
                    fResult :=
                        Format(
                        ' %10.2f %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) -- (%6.2f %6.2f %6.2f) --- %7.4f -- %4d -- %4d -- %2d',
                        [fDeltaVolume, BoxVolume, fDeltaCord[1],
                        fDeltaCord[2], fDeltaCord[3], Alpha, Beta,
                        Gamma, fAlpha, fBeta, fGamma, ComputationTime,
                        CycleCount, EvaluationCount, RestartCount]);
                    if fDeltaVolume > fMaxDeltaVolume then
                    begin
                        fMaxDeltaVolume := fDeltaVolume;
                        fMaxDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                        fMaxDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                        fMaxDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                        SortUp(fMaxDeltaCord[1], fMaxDeltaCord[2], fMaxDeltaCord[3]);
                    end;
                    if fDeltaVolume < fMinDeltaVolume then
                    begin
                        fMinDeltaVolume := fDeltaVolume;
                        fMinDeltaCord[1] := BoxMaxCoords[1] - BoxMinCoords[1];
                        fMinDeltaCord[2] := BoxMaxCoords[2] - BoxMinCoords[2];
                        fMinDeltaCord[3] := BoxMaxCoords[3] - BoxMinCoords[3];
                        SortUp(fMinDeltaCord[1], fMinDeltaCord[2], fMinDeltaCord[3]);
                    end;
                    Memo2.Lines.Add(fResult);
                    Label2.Caption :=
                        Format(
                        'MinDelta Volume: %8.2f (%6.4f %6.4f %6.4f) ---  MaxDelta Volume: %8.2f (%6.4f %6.4f %6.4f)',
                        [fMinDeltaVolume, fMinDeltaCord[1], fMinDeltaCord[2],
                        fMinDeltaCord[3], fMaxDeltaVolume, fMaxDeltaCord[1],
                        fMaxDeltaCord[2], fMaxDeltaCord[3]]);
                end;
            end;
            { Removes and frees inserted container. }
            FHandlers.Remove(Handler);
            Application.ProcessMessages;
        end;
    end;
    PostProcessStatistics;
end;

procedure TBoundingBoxComponentForm.RunnerMinimumBoundingBoxCompute;
begin
    { Executes optimization method in separated thread. This method
      should not modify any data except members of container instance. }
    FHandlerMinimumBoundingBox.OptimizeBoundingBox;
end;

{$hints off}
procedure TBoundingBoxComponentForm.RunnerMinimumBoundingBoxCreate(Runner: TRunner
    );
begin
    { Creates optimization container, which will be executed by separated thread. }
    FHandlerMinimumBoundingBox := CreateHandler(0, 0, 0, GetIniParamLenght, True, 1);
end;
{$hints on}

procedure TBoundingBoxComponentForm.RunnerMinimumBoundingBoxOutput;
begin
    { Displays optimization results, this method is synchronized with
      main VCL thread. This method can modify any data of the form.
      Should not remove handler to allow subsequent runs. }
    FOptiResultBoxVolume := FHandlerMinimumBoundingBox.BoxVolume;
    FOptiResultBoxMaxCoords := FHandlerMinimumBoundingBox.BoxMaxCoords;
    FOptiResultBoxMinCoords := FHandlerMinimumBoundingBox.BoxMinCoords;
    OutputResults;
end;

procedure TBoundingBoxComponentForm.StopComputing;
var
    i: LongInt;
begin
    FStop := True;
    { Stops all handlers. }
    for i := 0 to FHandlers.Count - 1 do
        TDownHillSimplexHandler(FHandlers[i]).Stop;
end;

procedure TBoundingBoxComponentForm.ButtonStopClick(Sender: TObject);
begin
    StopComputing;
end;

procedure TBoundingBoxComponentForm.OuputFindMinBoxByVolume(fDownHillSimplexHandler: TDownHillSimplexHandler);
var
    fResult: string;
    fBoxSize: TDoubleVector3;
begin
    with fDownHillSimplexHandler do
    begin
        if BoxVolume < FBoxVolume then
        begin
            FBoxVolume := BoxVolume;
            FMaxCoords := BoxMaxCoords;
            FMinCoords := BoxMinCoords;
        end;
        fBoxSize[1] := BoxMaxCoords[1] - BoxMinCoords[1];
        fBoxSize[2] := BoxMaxCoords[2] - BoxMinCoords[2];
        fBoxSize[3] := BoxMaxCoords[3] - BoxMinCoords[3];
        SortUp(fBoxSize[1], fBoxSize[2], fBoxSize[3]);
        fResult := Format(
            ' Run %d: %10.2f (%6.3f %6.3f %6.3f) -- (%7.2f %7.2f %7.2f) --- %7.4f -- %4d -- %4d -- %2d',
            [RunId, BoxVolume, fBoxSize[1], fBoxSize[2], fBoxSize[3],
            Alpha, Beta, Gamma, ComputationTime, CycleCount, EvaluationCount,
            RestartCount]);
        Memo1.Lines.Add(fResult);
        Application.ProcessMessages;
    end;
    { Removes and frees container. }
    FHandlers.Remove(fDownHillSimplexHandler);
end;

procedure TBoundingBoxComponentForm.OutputResults;
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
    Memo1.Lines.Add('Minimum Volume    : ' + Format(' %10.4f', [FOptiResultBoxVolume]));
    fDelta[1] := FOptiResultBoxMaxCoords[1] - FOptiResultBoxMinCoords[1];
    fDelta[2] := FOptiResultBoxMaxCoords[2] - FOptiResultBoxMinCoords[2];
    fDelta[3] := FOptiResultBoxMaxCoords[3] - FOptiResultBoxMinCoords[3];
    SortUp(fDelta[1], fDelta[2], fDelta[3]);
    Memo1.Lines.Add('Minimum Box       : ' + Format(' %10.4f %10.4f %10.4f',
        [fDelta[1], fDelta[2], fDelta[3]]));
    Application.ProcessMessages;
end;

procedure TBoundingBoxComponentForm.FindMinBoxByVolume;
const
    cStartAngle5Runs: array[0..4] of TDoubleVector3 = (
        (0, 0, 0),
        (45, 45, 45),
        (-45, -45, -45),
        (45, -45, 45),
        (-45, 45, -45)
        );
const
    cStartAngle9Runs: array[0..8] of TDoubleVector3 = (
        (0, 0, 0),
        (45, 45, 45),
        (-45, -45, -45),
        (45, -45, 45),
        (-45, 45, -45),
        (-45, 45, 45),
        (-45, -45, 45),
        (45, -45, -45),
        (45, 45, -45)
        );
var
    i: integer;
    fRuns: integer;
    fStartAngle: TDoubleVector3;
    Handler: TDownHillSimplexHandler;
    Runners: TComponentList;
    Runner: TRunner;
begin
    fRuns := 3;
    if PointCloud.Count < 100000 then
        fRuns := 5;
    if PointCloud.Count < 25000 then
        fRuns := 9;
    FBoxVolume := 1e30;

    Runners := TComponentList.Create(True);
    for i := 0 to fRuns - 1 do
    begin
        if not FStop then
        begin
            if fRuns <= 5 then
                fStartAngle := cStartAngle5Runs[i]
            else
                fStartAngle := cStartAngle9Runs[i];

            { Runs optimization to get the minimum volume.
              CreateHandler adds hanlder to FHandlers list. }
            Handler :=
                CreateHandler(fStartAngle[1], fStartAngle[2],
                fStartAngle[3], GetIniParamLenght, False, i + 1);
            { OuputFindMinBoxByVolume removes hanlder from FHandlers list. }
            Handler.HandlerOutputProcedure := OuputFindMinBoxByVolume;
            { Creates runner. }
            Runner := TRunner.Create(nil);
            { Assign runner procedures. }
            Runner.OnCompute := Handler.OptimizeBoundingBox;
            Runner.OnOutput := Handler.DisplayOutput;
            { Adds runner to the pool. }
            Runners.Add(Runner);
            { Starts execution. }
            Runner.Run;
        end;
    end;
    { Waits until all runners finish computing. }
    for i := 0 to Runners.Count - 1 do
    begin
        Runner := TRunner(Runners[i]);
        Runner.Wait;
    end;
    Runners.Free;

    FOptiResultBoxVolume := FBoxVolume;
    FOptiResultBoxMaxCoords := FMaxCoords;
    FOptiResultBoxMinCoords := FMinCoords;
    OutputResults;
end;

procedure TBoundingBoxComponentForm.LoadObjPointCloud(iFileName: string;
    iAlpha, iBeta, iGamma: Single);
type
    TOBJCoord = record // Stores X, Y, Z coordinates
        X, Y, Z: Single;
    end;

    function GetCoords(iString: string): TOBJCoord;
    var
        P, P2, P3: Integer;
        fCoord: TOBJCoord;
    begin
        iString := Trim(Copy(iString, 3, Length(iString)));
        P := Pos(' ', iString);
        P2 := PosEx(' ', iString, P + 1);
        P3 := PosEx(' ', iString, P2 + 1);
        if P3 = 0 then
            P3 := 1000;
        iString := StringReplace(iString, '.', FormatSettings.DecimalSeparator,
            [rfReplaceAll]);
        fCoord.X := StrToFloat(Copy(iString, 1, P - 1));
        fCoord.Y := StrToFloat(Copy(iString, P + 1, P2 - P - 1));
        fCoord.Z := StrToFloat(Copy(iString, P2 + 1, P3 - P2 - 1));
        Result := fCoord;
    end;

var
    x: Integer;
    F: TextFile;
    S: string;
    fCoord: TOBJCoord;
    fPoint: p3DVector;
    RotX, RotY, RotZ, Matr: TMatrix;
    fVector: T3Vector;
begin
    if PointCloud <> nil then
    begin
        for x := 0 to PointCloud.Count - 1 do
        begin
            fPoint := PointCloud[x];
            Dispose(fPoint);
        end;
        PointCloud.Free;
        PointCloud := nil;
    end;
    PointCloud := TList.Create;
    if FileExists(iFileName) then
    begin
        RotX := MatrixRotX(DegToRad(iAlpha));
        RotY := MatrixRotY(DegToRad(iBeta));
        RotZ := MatrixRotZ(DegToRad(iGamma));
        { Computes rotation matrix. }
        Matr := UnitMatrix;
        Mul3DMatrix(RotZ, Matr, Matr);
        Mul3DMatrix(RotY, Matr, Matr);
        Mul3DMatrix(RotX, Matr, Matr);

        fVector[1] := 1;
        fVector[2] := 0;
        fVector[3] := 0;
        MulVectMatr(Matr, fVector);

        AssignFile(F, iFileName);
        Reset(F);
        while not (EOF(F)) do
        begin
            Application.ProcessMessages;
            Readln(F, S);
            if (Length(S) >= 2) and (S[1] <> '#') then
            begin
                S := Uppercase(S);
                if (S[1] = 'V') and (S[2] = ' ') then
                begin
                    { Reads vertex data. }
                    New(fPoint);
                    fCoord := GetCoords(S);
                    fVector[1] := fCoord.X;
                    fVector[2] := fCoord.Y;
                    fVector[3] := fCoord.Z;
                    MulVectMatr(Matr, fVector);

                    fPoint^.FVector := fVector;
                    PointCloud.Add(fPoint);
                end;
            end;
        end;
        CloseFile(F);
    end;
end;

{$warnings off}
{$hints off}
procedure TBoundingBoxComponentForm.GenerateRandomPointCloud;
const
    PointCount: LongInt = 10;     //  Number of points in the cloud.
    { Dispersion boundaries. }
    MaxX: double = 0.5;
    MinX: double = -0.5;
    MaxY: double = 0.5;
    MinY: double = -0.5;
    MaxZ: double = 0.5;
    MinZ: double = -0.5;
    { Boundaries along (1,1,1) axis. }
    Max111: double = 10.0;
    Min111: double = -10.0;
var
    i, x: LongInt;
    Point: p3DVector;
    Translation111: double;
begin
    Randomize;
    if PointCloud <> nil then
    begin
        for x := 0 to PointCloud.Count - 1 do
        begin
            Point := PointCloud[x];
            Dispose(Point);
        end;
        PointCloud.Free;
        PointCloud := nil;
    end;

    PointCloud := TList.Create;

    for i := 0 to PointCount - 1 do
    begin
        new(Point);
        { Coordinates are located mainly along (1,1,1) axis
          with relatively small dispersion. }
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
