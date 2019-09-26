unit ExamplesMain;

interface

uses
  {$IFNDEF Lazarus}
    Winapi.Windows, Winapi.Messages,
    System.SysUtils, System.Variants, System.Classes,
    Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  {$ELSE}
    SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, Buttons,
    Contnrs,
  {$ENDIF}
    Algorithm, DownhillSimplexAlgorithm, SimpMath, Math3d;

type
    { TForm1 }

    TForm1 = class(TForm)
        BitBtn1: TBitBtn;
        DownhillSimplexAlgorithm1: TDownhillSimplexAlgorithm;
        procedure BitBtn1Click(Sender: TObject);
    private
        { Minimum bounding box problem. }
        SavedPointCloud: TComponentList;
        { Set of random points. }
        PointCloud: TComponentList;
        { Angles describing rotation of coordinate system. }
        Alpha, Beta, Gamma: Double;
        { Vector displaying position of center of the box. }
        BoxPosition:  TDoubleVector3;
        InitialVolume: Double;

        { TODO: saving/restoring make more efficient. }
        procedure CopyPointCloud(Src: TComponentList; var Dest: TComponentList);
        procedure SavePointCloud;
        procedure RestorePointCloud;
        procedure GenerateRandomPointCloud;
        procedure InitializeVariableParameters;
        procedure TransformPointCloudCoordinates;

        function ComputeCenterOfMass: TDoubleVector3;
        { Retuns triplet of max coordinates (actually not a vector). }
        function ComputeMaxCoordinates: TDoubleVector3;
        { Retuns triplet of min coordinates (actually not a vector). }
        function ComputeMinCoordinates: TDoubleVector3;
        { Return volume of the box, based on values of parameters. }
        function ComputeBoxVolume: Double;
    public
        { Public declarations }
    end;

var
    Form1: TForm1;

implementation

{$R *.dfm}

{ TForm1 }

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
    GenerateRandomPointCloud;
    InitializeVariableParameters;
    MessageDlg('Volumes',
        'Initial volume: ' + FloatToStr(InitialVolume) + sLineBreak,
        mtInformation, [mbOK], 0, mbOK);
end;

procedure TForm1.GenerateRandomPointCloud;
const PointCount: LongInt = 10;     //  Number of points in the cloud.
//  Cloud boundaries.
const MaxX: double = 10.0;
const MinX: double = -10.0;
const MaxY: double = 10.0;
const MinY: double = -10.0;
const MaxZ: double = 10.0;
const MinZ: double = -10.0;
var i: LongInt;
    Point: T3DVector;
begin
    Randomize;
    if PointCloud <> nil then
        PointCloud.Destroy;

    PointCloud := TComponentList.Create(True);

    for i := 0 to PointCount - 1 do
    begin
        Point := T3DVector.Create(nil);
        Point.Comps[0] := MinX + Random * (MaxX - MinX);
        Point.Comps[1] := MinY + Random * (MaxY - MinY);
        Point.Comps[2] := MinZ + Random * (MaxZ - MinZ);

        PointCloud.Add(Point);
    end;
end;

function TForm1.ComputeCenterOfMass: TDoubleVector3;
var i: LongInt;
    X, Y, Z: Double;
    Point: T3DVector;
begin
    Assert(PointCloud.Count <> 0);

    X := 0; Y := 0; Z := 0;
    for i := 0 to PointCloud.Count - 1 do
    begin
        Point := T3DVector(PointCloud[i]);
        X := X + Point.Comps[0];
        Y := Y + Point.Comps[1];
        Z := Z + Point.Comps[2];
    end;

    X := X / PointCloud.Count;
    Y := Y / PointCloud.Count;
    Z := Z / PointCloud.Count;
    Result[1] := X;
    Result[2] := Y;
    Result[3] := Z;
end;

procedure TForm1.InitializeVariableParameters;
begin
    BoxPosition := ComputeCenterOfMass;
    Alpha := 0; Beta := 0; Gamma := 0;
    InitialVolume := ComputeBoxVolume;
end;

function TForm1.ComputeMaxCoordinates: TDoubleVector3;
var i: LongInt;
    Point: T3DVector;
begin
    Assert(PointCloud.Count <> 0);

    Point := T3DVector(PointCloud[0]);
    Result[1] := Point.Comps[0];
    Result[2] := Point.Comps[1];
    Result[3] := Point.Comps[2];

    for i := 1 to PointCloud.Count - 1 do
    begin
        Point := T3DVector(PointCloud[i]);
        if Point.Comps[0] > Result[1] then
            Result[1] := Point.Comps[0];
        if Point.Comps[1] > Result[2] then
            Result[2] := Point.Comps[1];
        if Point.Comps[2] > Result[3] then
            Result[3] := Point.Comps[2];
    end;
end;

function TForm1.ComputeMinCoordinates: TDoubleVector3;
var i: LongInt;
    Point: T3DVector;
begin
    Assert(PointCloud.Count <> 0);

    Point := T3DVector(PointCloud[0]);
    Result[1] := Point.Comps[0];
    Result[2] := Point.Comps[1];
    Result[3] := Point.Comps[2];

    for i := 1 to PointCloud.Count - 1 do
    begin
        Point := T3DVector(PointCloud[i]);
        if Point.Comps[0] < Result[1] then
            Result[1] := Point.Comps[0];
        if Point.Comps[1] < Result[2] then
            Result[2] := Point.Comps[1];
        if Point.Comps[2] < Result[3] then
            Result[3] := Point.Comps[2];
    end;
end;

{$hints off}
procedure TForm1.TransformPointCloudCoordinates;
var RotX, RotY, RotZ, RotMatr: TMatrix;
    i: LongInt;
    Point: T3DVector;
    Vector: T3Vector;
begin
    { Computing matrices. }
    GetMatrixRotX(Alpha, RotX);
    GetMatrixRotY(Beta, RotY);
    GetMatrixRotZ(Gamma, RotZ);
    { Computes rotation matrix. }
    Mul3DMatrix(RotY, RotZ, RotMatr);
    Mul3DMatrix(RotX, RotMatr, RotMatr);

    for i := 0 to PointCloud.Count - 1 do
    begin
       Point := T3DVector(PointCloud[i]);
       Vector := Point.Vector;
       MulVectMatr(RotMatr, Vector);
       Point.Vector := Vector;
    end;
end;
{$hints on}

function TForm1.ComputeBoxVolume: Double;
var MaxCoords, MinCoords: TDoubleVector3;
    A, B, C: Double;    //  Sizes of the box.
begin
    { Computes volume of bounding box. }
    MaxCoords := ComputeMaxCoordinates;
    MinCoords := ComputeMinCoordinates;
    A := MaxCoords[1] - MinCoords[1];
    B := MaxCoords[2] - MinCoords[2];
    C := MaxCoords[3] - MinCoords[3];
    Result := A * B * C;
end;

procedure TForm1.CopyPointCloud(Src: TComponentList; var Dest: TComponentList);
var i: LongInt;
    Point: T3DVector;
begin
    if Dest <> nil then
        Dest.Destroy;

    Dest := TComponentList.Create(True);

    for i := 0 to Src.Count - 1 do
    begin
       Point := T3DVector.Create(nil);
       Point.Vector := T3DVector(Src[i]).Vector;
       Dest.Add(Point);
    end;
end;

procedure TForm1.SavePointCloud;
begin
    CopyPointCloud(PointCloud, SavedPointCloud);
end;

procedure TForm1.RestorePointCloud;
begin
    CopyPointCloud(SavedPointCloud, PointCloud);
end;

end.
