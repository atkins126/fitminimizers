{------------------------------------------------------------------------------------------------------------------------
    This software is distributed under MPL 2.0 https://www.mozilla.org/en-US/MPL/2.0/ in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR ANY PARTICULAR PURPOSE.

    Copyright (C) Dmitry Morozov: dvmorozov@hotmail.com
                        LinkedIn: https://www.linkedin.com/in/dmitry-morozov-79490a59/
                        Facebook: https://www.facebook.com/dmitry.v.morozov
------------------------------------------------------------------------------------------------------------------------}
unit SimpMath;

{$IFDEF Lazarus}
{$MODE Delphi}
{$ENDIF}

{$ASSERTIONS ON}

interface

uses
    Math, Classes, CBRCComponent, SysUtils;

const
    TINY = 1e-6;

type
    EPointsArrayIsNotAssigned = class(Exception);
    TwoDimArray = array of array[1..2] of Double;

type
    TDoubleVector3 = array[1..3] of Double;

    IVector = interface;

    //  Vector space.
    ISpace = interface
        //  Return scalar (inner) product of vectors.
        function GetScalarMul(const Vect1, Vect2: IVector): Double;
    end;

    //  Vector of arbitrary number of dimensions containing real numbers.
    IVector = interface
        function GetSpace: ISpace;
        procedure SetSpace(const ASpace: ISpace);
        function GetNorma: Double;
        function GetCompsNumber: LongInt;
        function GetComp(index: LongInt): Double;
        procedure SetComp(index: LongInt; AComp: Double);
        function GetNormComp(index: LongInt): Double;

        property Space: ISpace read GetSpace write SetSpace;
        property Norma: Double read GetNorma;
        //  Returns number of vector coordinates (dimensions).
        property CompsNumber: LongInt read GetCompsNumber;
        //  Gets/sets value of vector coordinate. Index is zero-based.
        property Comps[index: LongInt]: Double read GetComp write SetComp;
        property NormComps[index: LongInt]: Double read GetNormComp;
    end;

    //  Vector of arbitrary number of dimensions containing complex number.
    IComplexVector = interface(IVector)
        function GetImComp(index: LongInt): Double;
        procedure SetImComp(index: LongInt; AImComp: Double);
        function GetNormImComp(index: LongInt): Double;

        //  Imaginary parts of vector components.
        property ImComps[index: LongInt]: Double read GetImComp write SetImComp;
        //  Imaginary parts of normalized vector components.
        property NormImComps[index: LongInt]: Double read GetNormImComp;
    end;

    E3DVector = class(Exception);

    //  Vector of 3D space.
    T3DVector = class(TCBRCComponent, IVector)
    protected
        FSpace: ISpace;
        FVector: TDoubleVector3;
        FNormalizedVector: TDoubleVector3;
        FNorma: Double;

        function GetSpace: ISpace;
        procedure SetSpace(const ASpace: ISpace);
        function GetNorma: Double;
        procedure SetNorma(const ANorma: Double); virtual; abstract;
        function GetCompsNumber: LongInt;
        function GetComp(index: LongInt): Double;
        //  TODO: normalized vector should be recomputed.
        procedure SetComp(index: LongInt; AComp: Double);
        function GetNormComp(index: LongInt): Double;
        function GetVector: TDoubleVector3;
        procedure SetVector(Vector: TDoubleVector3);

    public
        property Space: ISpace read GetSpace write SetSpace;
        property Norma: Double read GetNorma;
        property CompsNumber: LongInt read GetCompsNumber;
        property Comps[index: LongInt]: Double read GetComp write SetComp;
        property NormComps[index: LongInt]: Double read GetNormComp;
        property Vector: TDoubleVector3 read GetVector write SetVector;
    end;

    T3DComplexVector = class(T3DVector, IComplexVector)
    protected
        FImVector: TDoubleVector3;  //  Imaginary part.

        function GetImComp(index: LongInt): Double; virtual; abstract;
        procedure SetImComp(index: LongInt; AImComp: Double); virtual; abstract;
        function GetNormImComp(index: LongInt): Double; virtual; abstract;
    public
        property ImComps[index: LongInt]: Double read GetImComp write SetImComp;
        property NormImComps[index: LongInt]: Double read GetNormImComp;
    end;

//  Theta must be in interval from 0 to pi; Phi - in interval from -pi to pi.
procedure ConvertSphericalToDekart(Theta, Phi, R: Double; var x, y, z: Double);
procedure ConvertDekartToSpherical(x, y, z: Double; var Theta, Phi, R: Double);
//  Convert vector from cartesian coordinates to affine.
//  Parameter Alpha isn't used (see conditions below).
procedure ConvertDekartToAphine(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vector: TDoubleVector3);
//  Convert vector from affine to cartesian coordinates.
//  Parameter Alpha isn't used (see conditions below).
//  Conversion is done in following assumptions:
//  1. Alpha, Beta, Gamma - angles between axis in affine coordinates (expressed in radians),
//  besides Gamma = e1^e2, Beta = e3^e1, Alpha = e2^e3.
//  2. Axis e1 of affine coordinate system coincides with the axis e1 of cartesian coordinate system.
//  3. Axis e2 of affine coordinate system belongs to the e1e2 plane of cartesian coordinate system.
procedure ConvertAphineToDekart(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vector: TDoubleVector3);

procedure DecPhi(Dec: Double; var Phi: Double);
procedure DecTheta(Dec: Double; var Theta: Double);
procedure IncPhi(Inc: Double; var Phi: Double);
procedure IncTheta(Inc: Double; var Theta: Double);

//  Put given value into the interval.
procedure PutValueIntoInterval(const MinLimit, MaxLimit: Double; var Value: Double);
//  Return True if Value belongs to the given interval, False otherwise.
function IsValueIntoInterval(const MinLimit, MaxLimit, Value: Double): Boolean;
//  Return scalar (inner) product in orthonormal coordinate system.
function GetScalarMul(const Vect1, Vect2: TDoubleVector3): Double;
//  Return scalar (inner) product in affine coordinate system.
//  Angles between basal vectors are given in radians: Gamma = e1^e2; Beta = e3^e1; Alpha = e2^e3.
function GetScalarMulA(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
//  Return scalar (inner) product in affine coordinate system between normalized vectors.
//  Angles between basal vectors are given in radians: Gamma = e1^e2; Beta = e3^e1; Alpha = e2^e3.
function GetScalarMulAN(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
//  Return angle between vectors.
function GetAngle(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
//  Return cross product in affine coordinate system.
//  Angles between basal vectors are given in radians: Gamma = e1^e2; Beta = e3^e1; Alpha = e2^e3.
function GetVectorMulA(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): TDoubleVector3;
//  Return modulus of vector given in cartesian coordinate system.
function GetVectModule(const Vect: TDoubleVector3): Double;
//  Return modulus of vector given in affine coordinate system.
function GetVectModuleA(const Vect: TDoubleVector3;
    const A, B, C, Alpha, Beta, Gamma: Double): Double;
//  Calculate unit vector for the vector given in cartesian coordinate system.
procedure GetUnitVect(const Vect: TDoubleVector3; var UnitVect: TDoubleVector3);
//  Calculate unit vector for the vector given in affine coordinate system.
procedure GetUnitVectA(const Vect: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double; var UnitVect: TDoubleVector3);
//  Return 3 mutual vectors to the given vectors forming basis with given parameters, besides
//  Vect1 = (1/V)[e2 x e3], |Vect1| = (1/V)|e2||e3|Sin(Alpha),
//  Vect2 = (1/V)[e3 x e1], |Vect2| = (1/V)|e1||e3|Sin(Beta),
//  Vect3 = (1/V)[e1 x e2], |Vect3| = (1/V)|e1||e2|Sin(Gamma),
//  |e1| = A, |e2| = B, |e3| = C,
//  Gamma = e1^e2, Beta = e3^e1, Alpha = e2^e3 (angles are given in radians),
//  V - volume of the cell built on the basal vectors.
procedure GetMutualVectors(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vect1, Vect2, Vect3: TDoubleVector3);

procedure GetMutualVectorsInNewBasis(
    //  Parameters of initial basis in which all vectors are defined.
    const A, B, C, Alpha, Beta, Gamma: Double;
    //  Vectors of new basis (are defined in the initial basis).
    NewBasisVect1, NewBasisVect2, NewBasisVect3: TDoubleVector3;
    //  Mutual vectors to the new vectors (are defined in the initial basis).
    var Vect1, Vect2, Vect3: TDoubleVector3);

//  Return volume of the cell built on the basal vectors.
function GetVolume(const A, B, C, Alpha, Beta, Gamma: Double): Double;
//  Return coordinates of vector in new basis.
function GetVectInNewBasis(
    //  Parameters of initial basis in which all vectors are defined.
    const A, B, C, Alpha, Beta, Gamma: Double;
    //  Vectors of new basis (are defined in the initial basis).
    NewBasisVect1, NewBasisVect2, NewBasisVect3: TDoubleVector3;
    //  Vector given in the initial basis.
    InitialVect: TDoubleVector3): TDoubleVector3;

function MulVectByValue(const Vect: TDoubleVector3; Value: Double): TDoubleVector3;
procedure SetVectModule(var Vect: TDoubleVector3;
    const A, B, C, Alpha, Beta, Gamma, Module: Double);

function GetSubVect(Vect1, Vect2: TDoubleVector3): TDoubleVector3;
function ArcSin(x: Double): Double;
function ArcCos(x: Double): Double;
//  Return decimal order of given number.
function GetNumberDegree(Number: Double): LongInt;
function GetPowerOf10(Power: LongInt): Double;
function Sign(Number: Double): LongInt;

function Lagrange(PointsArray: TwoDimArray;   //  The first - X, the second - Y.
    const X: Double): Double;

function GaussPoint(const A,    //  Integral of function by definition area.
    Sigma, x0, x: Double): Double;
function LorentzPoint(const A,    //  Integral of function by definition area.
    Sigma, x0, x: Double): Double;
function PseudoVoigtPoint(const A, Sigma, Eta, x0, x: Double): Double;
function AsymPseudoVoigtPoint(const A, Sigma, Eta, x0, x, DeltaSigma: Double): Double;
function TwoBranchesPseudoVoigtPoint(
    const A, Sigma, Eta, SigmaRight, EtaRight, x0, x: Double): Double;
procedure Gauss(PointsArray: TwoDimArray; const A, Sigma, x0: Double);
procedure Lorentz(PointsArray: TwoDimArray; const A, Sigma, x0: Double);
procedure PseudoVoigt(PointsArray: TwoDimArray; const A, Sigma, Eta, x0: Double);
procedure AsymPseudoVoigt(PointsArray: TwoDimArray;
    const A, Sigma, Eta, x0, DeltaSigma: Double);
procedure TwoBranchesPseudoVoigt(PointsArray: TwoDimArray;
    const A, Sigma, Eta, SigmaRight, EtaRight, x0: Double);
function CalcPolinom2(const A, B, C, x0, x: Double): Double;

implementation

//  Auxiliary functions to work with vectors.
function GetD(const Alpha, Beta, Gamma: Double): Double; forward;
function GetPAlpha(const Alpha, Beta, Gamma: Double): Double; forward;
function GetPBeta(const Alpha, Beta, Gamma: Double): Double; forward;
function GetPGamma(const Alpha, Beta, Gamma: Double): Double; forward;

function ArcSin(x: Double): Double;
var
    TempDouble: Double;
begin
    TempDouble := 1 - Sqr(x);
    if Abs(TempDouble) < TINY then
        TempDouble := 0;
    TempDouble := Sqrt(TempDouble);
    if TempDouble <> 0 then
        Result := ArcTan2(x, TempDouble)
    else
        Result := pi / 2;
end;

function ArcCos(x: Double): Double;
var
    TempDouble: Double;
begin
    TempDouble := 1 - Sqr(x);
    if Abs(TempDouble) < TINY then
        TempDouble := 0;
    if x <> 0 then
        Result := ArcTan2(Sqrt(TempDouble), x)
    else
        Result := pi / 2;
end;

function GetScalarMul(const Vect1, Vect2: TDoubleVector3): Double;
begin
    Result := Vect1[1] * Vect2[1] + Vect1[2] * Vect2[2] + Vect1[3] * Vect2[3];
end;

function GetScalarMulA(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
begin
    Result := Vect1[1] * Vect2[1] * Sqr(A) + Vect1[2] * Vect2[2] *
        Sqr(B) + Vect1[3] * Vect2[3] * Sqr(C) + (Vect1[2] * Vect2[1] +
        Vect1[1] * Vect2[2]) * A * B * Cos(Gamma) +
        (Vect1[1] * Vect2[3] + Vect1[3] * Vect2[1]) * C * A * Cos(Beta) +
        (Vect1[3] * Vect2[2] + Vect1[2] * Vect2[3]) * B * C * Cos(Alpha);
end;

function GetScalarMulAN(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
var
    V1, V2: TDoubleVector3;
begin
    V1[1] := 0;
    V1[2] := 0;
    V1[3] := 0;
    V2[1] := 0;
    V2[2] := 0;
    V2[3] := 0;
    GetUnitVectA(Vect1, A, B, C, Alpha, Beta, Gamma, V1);
    GetUnitVectA(Vect2, A, B, C, Alpha, Beta, Gamma, V2);

    Result := GetScalarMulA(V1, V2, A, B, C, Alpha, Beta, Gamma);
end;

function GetAngle(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): Double;
begin
    Result := ArcCos(GetScalarMulAN(Vect1, Vect2, A, B, C, Alpha, Beta, Gamma));
end;

function GetVectModule(const Vect: TDoubleVector3): Double;
begin
    Result := Sqrt(GetScalarMul(Vect, Vect));
end;

function GetVectModuleA(const Vect: TDoubleVector3;
    const A, B, C, Alpha, Beta, Gamma: Double): Double;
begin
    Result := Sqrt(GetScalarMulA(Vect, Vect, A, B, C, Alpha, Beta, Gamma));
end;

function MulVectByValue(const Vect: TDoubleVector3; Value: Double): TDoubleVector3;
begin
    Result[1] := Vect[1] * Value;
    Result[2] := Vect[2] * Value;
    Result[3] := Vect[3] * Value;
end;

procedure SetVectModule(var Vect: TDoubleVector3;
    const A, B, C, Alpha, Beta, Gamma, Module: Double);
var
    TempModule: Double;
begin
    TempModule := GetVectModuleA(Vect, A, B, C, Alpha, Beta, Gamma);
    if TempModule <> 0 then
        Vect := MulVectByValue(Vect, Module / TempModule);
end;

function GetSubVect(Vect1, Vect2: TDoubleVector3): TDoubleVector3;
begin
    Result[1] := Vect1[1] - Vect2[1];
    Result[2] := Vect1[2] - Vect2[2];
    Result[3] := Vect1[3] - Vect2[3];
end;

procedure ConvertSphericalToDekart(Theta, Phi, R: Double; var x, y, z: Double);
begin
    x := R * Sin(Theta) * Cos(Phi);
    y := R * Sin(Theta) * Sin(Phi);
    z := R * Cos(Theta);
end;

procedure ConvertDekartToSpherical(x, y, z: Double; var Theta, Phi, R: Double);
begin
    R := Sqrt(Sqr(x) + Sqr(y) + Sqr(z));
    if z <> 0 then
        Theta := ArcTan2(Sqrt(Sqr(x) + Sqr(y)), z)
    else
        Theta := pi / 2;
    if x <> 0 then
        Phi := ArcTan2(y, x)
    else if y >= 0 then
        Phi := pi / 2
    else
        Phi := -pi / 2;
end;

procedure DecPhi(Dec: Double; var Phi: Double);
begin
    Phi := Phi - Dec;
    if Phi > pi then
        Phi := -pi + (Phi - pi)
    else if Phi <= -pi then
        Phi := pi - (-pi - Phi);
end;

procedure DecTheta(Dec: Double; var Theta: Double);
begin
    Theta := Theta - Dec;
    if Theta < 0 then
        Theta := 0;
end;

procedure IncPhi(Inc: Double; var Phi: Double);
begin
    Phi := Phi + Inc;
    if Phi > pi then
        Phi := -pi + (Phi - pi)
    else if Phi <= -pi then
        Phi := pi - (-pi - Phi);
end;

procedure IncTheta(Inc: Double; var Theta: Double);
begin
    Theta := Theta + Inc;
    if Theta > pi then
        Theta := pi;
end;

function GetNumberDegree(Number: Double): LongInt;
var
    i: LongInt;
    TempDouble: Double;
begin
    TempDouble := Number;
    if Number = 0 then
    begin
        Result := 1;
        Exit;
    end;
    if Number >= 1 then
    begin
        i := -1;
        while Int(TempDouble) <> 0 do
        begin
            Inc(i);
            TempDouble := TempDouble / 10;
        end;
    end
    else
    begin
        i := 0;
        while Int(TempDouble) = 0 do
        begin
            Dec(i);
            TempDouble := TempDouble * 10;
        end;
    end;
    Result := i;
end;

function GetPowerOf10(Power: LongInt): Double;
var
    i: LongInt;
    TempDouble: Double;
begin
    TempDouble := 1;
    if Power >= 0 then
        for i := 1 to Power do
            TempDouble := TempDouble * 10
    else
        for i := -1 downto Power do
            TempDouble := TempDouble * 0.1;
    Result := TempDouble;
end;

function Sign(Number: Double): LongInt;
begin
    if Number >= 0 then
        Result := 1
    else
        Result := -1;
end;

function Lagrange(PointsArray: TwoDimArray;(*The first - X, the second - Y*)
    const X: Double): Double;
var
    Lagr: Double;
    p1, p2: Double;
    i, j1: LongInt;
begin
    if not Assigned(PointsArray) then
    begin
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');
        Exit;
    end;
    Lagr := 0;
    for i := 0 to Length(PointsArray) - 1 do
    begin
        p1 := 1;
        p2 := 1;
        for j1 := 0 to Length(PointsArray) - 1 do
        begin
            if i <> j1 then
            begin
                p1 := p1 * (PointsArray[i][1] - PointsArray[j1][1]);
                p2 := p2 * (X - PointsArray[j1][1]);
            end;
        end;
        if p1 <> 0 then
            Lagr := Lagr + PointsArray[i][2] * p2 / p1;
    end;
    Result := Lagr;
end;

//  FWHM = 2 * Sqrt(2 * ln(2)) * Sigma
function GaussPoint(const A,    //  Integral of function by definition area.
    Sigma, x0, x: Double): Double;
begin
    Assert(A >= 0);
    Assert(Sigma >= 0);
    Result := (A / (Sigma * Sqrt(2 * pi))) * exp(-1 * Sqr(x0 - x) /
        (2 * Sqr(Sigma)));
end;

//  FWHM = Sigma
function LorentzPoint(const A,    //  Integral of function by definition area.
    Sigma, x0, x: Double): Double;
begin
    Assert(A >= 0);
    Assert(Sigma >= 0);
    (*
    Result := (A / (Sigma * Sqrt(2 * pi))) *
        exp(-1 * Abs(x0 - x) / (2 * Sqr(Sigma)));
    *)
    Result := A * (1 / (pi * Sigma / 2)) *
        (1 / (1 + Sqr((x - x0) / (Sigma / 2))));
end;

function PseudoVoigtPoint(const A, Sigma, Eta, x0, x: Double): Double;
begin
    Assert(A >= 0);
    Assert(Sigma >= 0);
    Assert((Eta >= 0) and (Eta <= 1));

    Result := A * ((1 - Eta) * (2 * Sqrt(Ln(2)) / (Sigma * Sqrt(pi)) *
        exp(-4 * Ln(2) * Sqr(x0 - x) / Sqr(Sigma))) + Eta *
        ((2 / (pi * Sigma)) * (1 / (1 + Sqr(2 * (x - x0) / Sigma)))));
end;

function AsymPseudoVoigtPoint(const A, Sigma, Eta, x0, x, DeltaSigma: Double): Double;
begin
    Assert(A >= 0);
    Assert(Sigma >= 0);
    Assert((Eta >= 0) and (Eta <= 1));

    if (x >= x0) then
    begin
        Result := A * ((1 - Eta) *
            (exp(-4 * Ln(2) * Sqr(x0 - x) / Sqr((Sigma + DeltaSigma)))) +
            Eta * ((1 / (1 + Sqr(2 * (x - x0) / (Sigma + DeltaSigma))))));
    end
    else
    begin
        Result := A * ((1 - Eta) *
            (exp(-4 * Ln(2) * Sqr(x0 - x) / Sqr((Sigma - DeltaSigma)))) +
            Eta * ((1 / (1 + Sqr(2 * (x - x0) / (Sigma - DeltaSigma))))));
    end;
end;

function TwoBranchesPseudoVoigtPoint(
    const A, Sigma, Eta, SigmaRight, EtaRight, x0, x: Double): Double;
begin
    Assert(A >= 0);
    Assert(Sigma >= 0);
    Assert((Eta >= 0) and (Eta <= 1));
    Assert(SigmaRight >= 0);
    Assert((EtaRight >= 0) and (EtaRight <= 1));

    if (x >= x0) then
    begin
        Result := A * ((1 - EtaRight) *
            (exp(-4 * Ln(2) * Sqr(x0 - x) / Sqr(SigmaRight))) +
            EtaRight * ((1 / (1 + Sqr(2 * (x - x0) / SigmaRight)))));
    end
    else
    begin
        Result := A * ((1 - Eta) *
            (exp(-4 * Ln(2) * Sqr(x0 - x) / Sqr(Sigma))) + Eta *
            ((1 / (1 + Sqr(2 * (x - x0) / Sigma)))));












    end;
end;

procedure Gauss(PointsArray: TwoDimArray; const A, Sigma, x0: Double);
var
    i: LongInt;
begin
    if not Assigned(PointsArray) then
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');

    for i := 0 to Length(PointsArray) - 1 do
        PointsArray[i][2] := GaussPoint(A, Sigma, x0, PointsArray[i][1]);
end;

procedure Lorentz(PointsArray: TwoDimArray; const A, Sigma, x0: Double);
var
    i: LongInt;
begin
    if not Assigned(PointsArray) then
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');

    for i := 0 to Length(PointsArray) - 1 do
        PointsArray[i][2] := LorentzPoint(A, Sigma, x0, PointsArray[i][1]);
end;

procedure PseudoVoigt(PointsArray: TwoDimArray; const A, Sigma, Eta, x0: Double);
var
    i: LongInt;
begin
    if not Assigned(PointsArray) then
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');

    for i := 0 to Length(PointsArray) - 1 do
        PointsArray[i][2] := PseudoVoigtPoint(A, Sigma, Eta, x0, PointsArray[i][1]);
end;

procedure AsymPseudoVoigt(PointsArray: TwoDimArray;
    const A, Sigma, Eta, x0, DeltaSigma: Double);
var
    i: LongInt;
begin
    if not Assigned(PointsArray) then
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');

    for i := 0 to Length(PointsArray) - 1 do
        PointsArray[i][2] := AsymPseudoVoigtPoint(
            A, Sigma, Eta, x0, PointsArray[i][1], DeltaSigma);
end;

procedure TwoBranchesPseudoVoigt(PointsArray: TwoDimArray;
    const A, Sigma, Eta, SigmaRight, EtaRight, x0: Double);
var
    i: LongInt;
begin
    if not Assigned(PointsArray) then
        raise EPointsArrayIsNotAssigned.Create('Points array is not assigned...');

    for i := 0 to Length(PointsArray) - 1 do
        PointsArray[i][2] := TwoBranchesPseudoVoigtPoint(
            A, Sigma, Eta, SigmaRight, EtaRight, x0, PointsArray[i][1]);
end;

procedure PutValueIntoInterval(const MinLimit, MaxLimit: Double; var Value: Double);
begin
    if Value > MaxLimit then
        Value := MinLimit + Frac((Value - MaxLimit) / (MaxLimit - MinLimit)) *
            (MaxLimit - MinLimit);
    if Value < MinLimit then
        Value := MaxLimit - Frac((MinLimit - Value) / (MaxLimit - MinLimit)) *
            (MaxLimit - MinLimit);
end;

function IsValueIntoInterval(const MinLimit, MaxLimit, Value: Double): Boolean;
begin
    if (Value >= MinLimit) and (Value <= MaxLimit) then
        Result := True
    else
        Result := False;
end;

procedure ConvertDekartToAphine(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vector: TDoubleVector3);
var
    V1, V2, V3, Result: TDoubleVector3;
begin
    //  Vectors of orthonormal coordinate system are calculated
    //  in the basis of initial affine coordinates.
    V1[1] := 1;
    V1[2] := 0;
    V1[3] := 0;
    V2[1] := 0;
    V2[2] := 1;
    V2[3] := 0;
    V3 := GetVectorMulA(V1, V2, A, B, C, Alpha, Beta, Gamma);
    GetUnitVectA(V1, A, B, C, Alpha, Beta, Gamma, V1);
    GetUnitVectA(V3, A, B, C, Alpha, Beta, Gamma, V3);
    V2 := GetVectorMulA(V3, V1, A, B, C, Alpha, Beta, Gamma);
    GetUnitVectA(V2, A, B, C, Alpha, Beta, Gamma, V2);
    //  V1, V2, V3 - orthonormal basis built in initial basis.
    Result[1] := Vector[1] * V1[1] + Vector[2] * V2[1] + Vector[3] * V3[1];
    Result[2] := Vector[1] * V1[2] + Vector[2] * V2[2] + Vector[3] * V3[2];
    Result[3] := Vector[1] * V1[3] + Vector[2] * V2[3] + Vector[3] * V3[3];
    Vector := Result;
end;

procedure ConvertAphineToDekart(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vector: TDoubleVector3);
var
    V1, V2, V3, Result: TDoubleVector3;
begin
    //  Mutual vectors to orthonormal basis coincide with vectors themselves.
    //  Coordinates of vector in new basis are equal to inner products of
    //  the vector with vectors mutual to vectors of new basis.
    V1[1] := 1;
    V1[2] := 0;
    V1[3] := 0;
    V2[1] := 0;
    V2[2] := 1;
    V2[3] := 0;
    V3 := GetVectorMulA(V1, V2, A, B, C, Alpha, Beta, Gamma);
    GetUnitVectA(V1, A, B, C, Alpha, Beta, Gamma, V1);
    GetUnitVectA(V3, A, B, C, Alpha, Beta, Gamma, V3);
    V2 := GetVectorMulA(V3, V1, A, B, C, Alpha, Beta, Gamma);
    GetUnitVectA(V2, A, B, C, Alpha, Beta, Gamma, V2);
    //  V1, V2, V3 - orthonormal basis built in original basis.
    Result[1] := GetScalarMulA(Vector, V1, A, B, C, Alpha, Beta, Gamma);
    Result[2] := GetScalarMulA(Vector, V2, A, B, C, Alpha, Beta, Gamma);
    Result[3] := GetScalarMulA(Vector, V3, A, B, C, Alpha, Beta, Gamma);
    Vector := Result;
end;

//  Calculate unit vector for the vector given in Cartesian system.
procedure GetUnitVect(const Vect: TDoubleVector3; var UnitVect: TDoubleVector3);
var
    Module: Double;
begin
    Module := GetVectModule(Vect);
    if Module <> 0 then
    begin
        UnitVect[1] := Vect[1] / Module;
        UnitVect[2] := Vect[2] / Module;
        UnitVect[3] := Vect[3] / Module;
    end
    else
    begin
        UnitVect[1] := 0;
        UnitVect[2] := 0;
        UnitVect[3] := 0;
    end;
end;

procedure GetUnitVectA(
    //  Calculate unit vector for the vector given in affine system.    
    const Vect: TDoubleVector3; A, B, C, Alpha, Beta, Gamma: Double;
    var UnitVect: TDoubleVector3);
var
    Module: Double;
begin
    Module := GetVectModuleA(Vect, A, B, C, Alpha, Beta, Gamma);
    if Module <> 0 then
    begin
        UnitVect[1] := Vect[1] / Module;
        UnitVect[2] := Vect[2] / Module;
        UnitVect[3] := Vect[3] / Module;
    end
    else
    begin
        UnitVect[1] := 0;
        UnitVect[2] := 0;
        UnitVect[3] := 0;
    end;
end;

function GetD(const Alpha, Beta, Gamma: Double): Double;
begin
    Result := 1 - Sqr(Cos(Alpha)) - Sqr(Cos(Beta)) - Sqr(Cos(Gamma)) +
        2 * Cos(Alpha) * Cos(Beta) * Cos(Gamma);
end;

function GetPAlpha(const Alpha, Beta, Gamma: Double): Double;
begin
    Result := Cos(Beta) * Cos(Gamma) - Cos(Alpha);
end;

function GetPBeta(const Alpha, Beta, Gamma: Double): Double;
begin
    Result := Cos(Alpha) * Cos(Gamma) - Cos(Beta);
end;

function GetPGamma(const Alpha, Beta, Gamma: Double): Double;
begin
    Result := Cos(Beta) * Cos(Alpha) - Cos(Gamma);
end;

function GetVolume(const A, B, C, Alpha, Beta, Gamma: Double): Double;
begin
    Result := A * B * C * Sqrt(GetD(Alpha, Beta, Gamma));
end;

procedure GetMutualVectors(const A, B, C, Alpha, Beta, Gamma: Double;
    var Vect1, Vect2, Vect3: TDoubleVector3);
var
    SqrtD: Double;
    PAlpha, PBeta, PGamma: Double;
    V: Double;
    Angle: Double;
    TempVect: TDoubleVector3;
begin
    SqrtD := Sqrt(GetD(Alpha, Beta, Gamma));
    PAlpha := GetPAlpha(Alpha, Beta, Gamma);
    PBeta := GetPBeta(Alpha, Beta, Gamma);
    PGamma := GetPGamma(Alpha, Beta, Gamma);
    V := GetVolume(A, B, C, Alpha, Beta, Gamma);

    Vect1[1] := C * B * Sqr(Sin(Alpha)) / (A * SqrtD);
    Vect1[2] := C * PGamma / SqrtD;
    Vect1[3] := B * PBeta / SqrtD;
    Vect1 := MulVectByValue(Vect1, 1 / V);
    TempVect[1] := 1;
    TempVect[2] := 0;
    TempVect[3] := 0;
    Angle := GetAngle(Vect1, TempVect, A, B, C, Alpha, Beta, Gamma);
    if Angle > pi / 2 then
        Vect1 := MulVectByValue(Vect1, -1);

    Vect2[1] := C * PGamma / SqrtD;
    Vect2[2] := A * C * Sqr(Sin(Beta)) / (B * SqrtD);
    Vect2[3] := A * PAlpha / SqrtD;
    Vect2 := MulVectByValue(Vect2, 1 / V);
    TempVect[1] := 0;
    TempVect[2] := 1;
    TempVect[3] := 0;
    Angle := GetAngle(Vect2, TempVect, A, B, C, Alpha, Beta, Gamma);
    if Angle > pi / 2 then
        Vect2 := MulVectByValue(Vect2, -1);

    Vect3[1] := B * PBeta / SqrtD;
    Vect3[2] := A * PAlpha / SqrtD;
    Vect3[3] := A * B * Sqr(Sin(Gamma)) / (C * SqrtD);
    Vect3 := MulVectByValue(Vect3, 1 / V);
    TempVect[1] := 0;
    TempVect[2] := 0;
    TempVect[3] := 1;
    Angle := GetAngle(Vect3, TempVect, A, B, C, Alpha, Beta, Gamma);
    if Angle > pi / 2 then
        Vect3 := MulVectByValue(Vect3, -1);
end;

procedure GetMutualVectorsInNewBasis(
    //  Parameters of the original basis in which all vectors are given.
    const A, B, C, Alpha, Beta, Gamma: Double;
    //  Vectors of new basis defined via vectors of old basis.
    NewBasisVect1, NewBasisVect2, NewBasisVect3: TDoubleVector3;
    //  Mutual vectors to the vectors of new basis (defined in old basis).
    var Vect1, Vect2, Vect3: TDoubleVector3);
//  Parameters of the new basis.    
var
    NewA, NewB, NewC, NewAlpha, NewBeta, NewGamma: Double;
    //  Volume of the parallelepiped built on the vectors of new basis.
    NewV: Double;
begin
    NewA := GetVectModuleA(NewBasisVect1, A, B, C, Alpha, Beta, Gamma);
    NewB := GetVectModuleA(NewBasisVect2, A, B, C, Alpha, Beta, Gamma);
    NewC := GetVectModuleA(NewBasisVect3, A, B, C, Alpha, Beta, Gamma);
    NewAlpha := GetAngle(NewBasisVect2, NewBasisVect3, A, B, C, Alpha, Beta, Gamma);
    NewBeta := GetAngle(NewBasisVect1, NewBasisVect3, A, B, C, Alpha, Beta, Gamma);
    NewGamma := GetAngle(NewBasisVect1, NewBasisVect2, A, B, C, Alpha, Beta, Gamma);
    NewV := GetVolume(NewA, NewB, NewC, NewAlpha, NewBeta, NewGamma);

    Vect1 := GetVectorMulA(NewBasisVect2, NewBasisVect3, A, B, C, Alpha, Beta, Gamma);
    Vect1 := MulVectByValue(Vect1, 1 / NewV);
    Vect2 := GetVectorMulA(NewBasisVect3, NewBasisVect1, A, B, C, Alpha, Beta, Gamma);
    Vect2 := MulVectByValue(Vect2, 1 / NewV);
    Vect3 := GetVectorMulA(NewBasisVect1, NewBasisVect2, A, B, C, Alpha, Beta, Gamma);
    Vect3 := MulVectByValue(Vect3, 1 / NewV);
end;

//  Return coordinates relative to new basis.
function GetVectInNewBasis(
    //  Parameters of the original basis in which all vectors are given.
    const A, B, C, Alpha, Beta, Gamma: Double;
    //  Vectors of new basis defined via vectors of old basis.
    NewBasisVect1, NewBasisVect2, NewBasisVect3: TDoubleVector3;
    //  Vector in the old basis.
    InitialVect: TDoubleVector3): TDoubleVector3;
var
    MutVect1, MutVect2, MutVect3: TDoubleVector3;
begin
    MutVect1[1] := 0;
    MutVect1[2] := 0;
    MutVect1[3] := 0;
    MutVect2[1] := 0;
    MutVect2[2] := 0;
    MutVect2[3] := 0;
    MutVect3[1] := 0;
    MutVect3[2] := 0;
    MutVect3[3] := 0;
    GetMutualVectorsInNewBasis(A, B, C, Alpha, Beta, Gamma,
        NewBasisVect1, NewBasisVect2, NewBasisVect3,
        MutVect1, MutVect2, MutVect3);
    Result[1] := GetScalarMulA(InitialVect, MutVect1, A, B, C, Alpha, Beta, Gamma);
    Result[2] := GetScalarMulA(InitialVect, MutVect2, A, B, C, Alpha, Beta, Gamma);
    Result[3] := GetScalarMulA(InitialVect, MutVect3, A, B, C, Alpha, Beta, Gamma);
end;

function GetVectorMulA(const Vect1, Vect2: TDoubleVector3;
    A, B, C, Alpha, Beta, Gamma: Double): TDoubleVector3;
var
    V1, V2, V3: TDoubleVector3;
begin
    V1[1] := 0;
    V1[2] := 0;
    V1[3] := 0;
    V2[1] := 0;
    V2[2] := 0;
    V2[3] := 0;
    V3[1] := 0;
    V3[2] := 0;
    V3[3] := 0;
    GetMutualVectors(A, B, C, Alpha, Beta, Gamma, V1, V2, V3);
    V1 := MulVectByValue(V1, Vect1[2] * Vect2[3] - Vect1[3] * Vect2[2]);
    V2 := MulVectByValue(V2, Vect1[3] * Vect2[1] - Vect1[1] * Vect2[3]);
    V3 := MulVectByValue(V3, Vect1[1] * Vect2[2] - Vect1[2] * Vect2[1]);
    Result[1] := V1[1] + V2[1] + V3[1];
    Result[2] := V1[2] + V2[2] + V3[2];
    Result[3] := V1[3] + V2[3] + V3[3];
    Result := MulVectByValue(Result, GetVolume(A, B, C, Alpha, Beta, Gamma));
end;

function T3DVector.GetSpace: ISpace;
begin
    if Assigned(FSpace) then
        Result := FSpace
    else
        raise E3DVector.Create('Space is not assigned...');
end;

procedure T3DVector.SetSpace(const ASpace: ISpace);
begin
    FSpace := ASpace;
end;

function T3DVector.GetNorma: Double;
begin
    Result := FNorma;
end;

function T3DVector.GetCompsNumber: LongInt;
begin
    Result := 3;
end;

function T3DVector.GetVector: TDoubleVector3;
begin
    Result[1] := Comps[0];
    Result[2] := Comps[1];
    Result[3] := Comps[2];
end;

procedure T3DVector.SetVector(Vector: TDoubleVector3);
begin
    Comps[0] := Vector[1];
    Comps[1] := Vector[2];
    Comps[2] := Vector[3];
end;

function T3DVector.GetComp(index: LongInt): Double;
begin
    if (Index < 0) or (index >= CompsNumber) then
        raise E3DVector.Create('Invalid index...')
    else
        Result := FVector[index + 1];
end;

procedure T3DVector.SetComp(index: LongInt; AComp: Double);
begin
    if (Index < 0) or (index >= CompsNumber) then
        raise E3DVector.Create('Invalid index...')
    else
        FVector[index + 1] := AComp;
end;

function T3DVector.GetNormComp(index: LongInt): Double;
begin
    if (Index < 0) or (index >= CompsNumber) then
        raise E3DVector.Create('Invalid index...')
    else
        Result := FNormalizedVector[index + 1];
end;

function CalcPolinom2(const A, B, C, x0, x: Double): Double;
begin
    Result := A * Sqr(x0 - x) + B * (x0 - x) + C;
end;

initialization
end.
