unit uCalcPriceFixture;

interface

uses
  DUnitX.TestFramework, System.SysUtils, uCalcPricesProc;

type
  [TestFixture]
  TCalcPriceFixture = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // CheckNum tests
    [Test]
    procedure CheckNum_TwoDecimalPlaces_ReturnsTrue;
    [Test]
    procedure CheckNum_ZeroDecimalPlaces_ReturnsTrue;
    [Test]
    procedure CheckNum_OneDecimalPlace_ReturnsTrue;
    [Test]
    procedure CheckNum_SmallFraction_ReturnsTrue;
    [Test]
    [TestCase('Three decimals', '100.555,false')]
    procedure CheckNum_ThreeDecimalPlaces_ReturnsFalse(ANum: double; AExpected: boolean);
    [Test]
    procedure CheckNum_ManyDecimalPlaces_ReturnsFalse;
    [Test]
    procedure CheckNum_Zero_ReturnsTrue;
    [Test]
    procedure CheckNum_FloatRoundTrip_ReturnsTrue;

    // CalcPricesProc — NDS 0
    [Test]
    procedure CalcPricesProc_NDS0_InputEqualsOutput;

    // CalcPricesProc — NDS 20
    [Test]
    procedure CalcPricesProc_NDS20_IntegerRoundTrip;
    [Test]
    [TestCase('118→98.33', '118.00,20,98.33,118.00')]
    [TestCase('236→196.67', '236.00,20,196.67,236.00')]
    [TestCase('1180→983.33', '1180.00,20,983.33,1180.00')]
    [TestCase('100→83.33', '100.00,20,83.33,100.00')]
    procedure CalcPricesProc_NDS20_VariousPrices(
      InputPrice: double; ProcNDS: Integer;
      ExpWithout: double; ExpWith: double);

    // CalcPricesProc — NDS 10
    [Test]
    procedure CalcPricesProc_NDS10_RoundTrip;
    [Test]
    procedure CalcPricesProc_NDS10_FractionalResult;

    // CalcPricesProc — Edge cases
    [Test]
    [TestCase('118.99', '118.99,20')]
    [TestCase('99.99', '99.99,20')]
    [TestCase('100.01', '100.01,20')]
    [TestCase('1180.50', '1180.50,20')]
    [TestCase('999.99', '999.99,20')]
    procedure CalcPricesProc_FractionalInput_FindsValidPair(
      InputPrice: double; ProcNDS: Integer);

    [Test]
    procedure CalcPricesProc_ZeroPrice_BothOutputsZero;
    [Test]
    procedure CalcPricesProc_MinimumPrice_0_01;
    [Test]
    procedure CalcPricesProc_LargePrice_1Million;
    [Test]
    procedure CalcPricesProc_LargeFractionalPrice;

    // Round-trip validation
    [Test]
    [TestCase('0.01×20', '0.01,20')]
    [TestCase('118.00×20', '118.00,20')]
    [TestCase('118.99×20', '118.99,20')]
    [TestCase('0.01×10', '0.01,10')]
    [TestCase('110.00×10', '110.00,10')]
    [TestCase('0×20', '0,20')]
    [TestCase('100000×0', '100000,0')]
    [TestCase('100000×20', '100000,20')]
    procedure CalcPricesProc_RoundTrip_ValidatesCorrectness(
      InputPrice: double; ProcNDS: Integer);
  end;

implementation

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function RoundTripHolds(WithoutNDS, WithNDS: double; ProcNDS: Integer;
  Tolerance: double = 0.01): boolean;
var
  K: double;
begin
  if ProcNDS = 0 then
    K := 1.0
  else
    K := 1.0 + ProcNDS / 100.0;
  Result := Abs(WithoutNDS * K - WithNDS) <= Tolerance;
end;

// ---------------------------------------------------------------------------
// Setup / TearDown
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.Setup;
begin
end;

procedure TCalcPriceFixture.TearDown;
begin
end;

// ---------------------------------------------------------------------------
// CheckNum
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CheckNum_TwoDecimalPlaces_ReturnsTrue;
begin
  Assert.IsTrue(CheckNum(100.50));
end;

procedure TCalcPriceFixture.CheckNum_ZeroDecimalPlaces_ReturnsTrue;
begin
  Assert.IsTrue(CheckNum(100));
end;

procedure TCalcPriceFixture.CheckNum_OneDecimalPlace_ReturnsTrue;
begin
  Assert.IsTrue(CheckNum(99.9));
end;

procedure TCalcPriceFixture.CheckNum_SmallFraction_ReturnsTrue;
begin
  Assert.IsTrue(CheckNum(0.01));
end;

procedure TCalcPriceFixture.CheckNum_ThreeDecimalPlaces_ReturnsFalse(
  ANum: double; AExpected: boolean);
begin
  Assert.AreEqual(AExpected, CheckNum(ANum));
end;

procedure TCalcPriceFixture.CheckNum_ManyDecimalPlaces_ReturnsFalse;
begin
  Assert.IsFalse(CheckNum(1.23456789));
end;

procedure TCalcPriceFixture.CheckNum_Zero_ReturnsTrue;
begin
  Assert.IsTrue(CheckNum(0));
end;

procedure TCalcPriceFixture.CheckNum_FloatRoundTrip_ReturnsTrue;
var
  Prices: array of double;
  I: Integer;
begin
  Prices := [118.00, 1200.00, 0.01, 99.99, 1000000.00];
  for I := Low(Prices) to High(Prices) do
    Assert.IsTrue(CheckNum(Prices[I]), 'Failed for price: ' + FloatToStr(Prices[I]));
end;

// ---------------------------------------------------------------------------
// CalcPricesProc — NDS 0
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CalcPricesProc_NDS0_InputEqualsOutput;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(118.00, 0, WithNDS, WithoutNDS);
  Assert.AreEqual(118.00, WithNDS, 0.001);
  Assert.AreEqual(118.00, WithoutNDS, 0.001);
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(CheckNum(WithoutNDS));
end;

// ---------------------------------------------------------------------------
// CalcPricesProc — NDS 20
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CalcPricesProc_NDS20_IntegerRoundTrip;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(120.00, 20, WithNDS, WithoutNDS);
  Assert.AreEqual(100.00, WithoutNDS, 0.001);
  Assert.AreEqual(120.00, WithNDS, 0.001);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, 20));
end;

procedure TCalcPriceFixture.CalcPricesProc_NDS20_VariousPrices(
  InputPrice: double; ProcNDS: Integer;
  ExpWithout: double; ExpWith: double);
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(InputPrice, ProcNDS, WithNDS, WithoutNDS);
  Assert.AreEqual(ExpWithout, WithoutNDS, 0.01);
  Assert.AreEqual(ExpWith, WithNDS, 0.01);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
end;

// ---------------------------------------------------------------------------
// CalcPricesProc — NDS 10
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CalcPricesProc_NDS10_RoundTrip;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(110.00, 10, WithNDS, WithoutNDS);
  Assert.AreEqual(100.00, WithoutNDS, 0.001);
  Assert.AreEqual(110.00, WithNDS, 0.001);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, 10));
end;

procedure TCalcPriceFixture.CalcPricesProc_NDS10_FractionalResult;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(111.00, 10, WithNDS, WithoutNDS);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, 10));
  Assert.IsTrue(WithoutNDS > 0);
end;

// ---------------------------------------------------------------------------
// CalcPricesProc — Edge cases
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CalcPricesProc_FractionalInput_FindsValidPair(
  InputPrice: double; ProcNDS: Integer);
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(InputPrice, ProcNDS, WithNDS, WithoutNDS);
  Assert.IsTrue(CheckNum(WithoutNDS), 'WithoutNDS has >2 decimals');
  Assert.IsTrue(CheckNum(WithNDS), 'WithNDS has >2 decimals');
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, ProcNDS),
    'Round-trip failed: ' + FloatToStr(WithoutNDS) + '*k <> ' + FloatToStr(WithNDS));
  Assert.IsTrue(WithoutNDS >= 0);
  Assert.IsTrue(WithNDS >= 0);
end;

procedure TCalcPriceFixture.CalcPricesProc_ZeroPrice_BothOutputsZero;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(0.00, 20, WithNDS, WithoutNDS);
  Assert.AreEqual(0.00, WithNDS, 0.001);
  Assert.AreEqual(0.00, WithoutNDS, 0.001);
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(CheckNum(WithoutNDS));
end;

procedure TCalcPriceFixture.CalcPricesProc_MinimumPrice_0_01;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(0.01, 20, WithNDS, WithoutNDS);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(WithoutNDS >= 0);
  Assert.IsTrue(WithNDS >= 0);
end;

procedure TCalcPriceFixture.CalcPricesProc_LargePrice_1Million;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(1_200_000.00, 20, WithNDS, WithoutNDS);
  Assert.AreEqual(1_000_000.00, WithoutNDS, 0.01);
  Assert.AreEqual(1_200_000.00, WithNDS, 0.01);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, 20));
end;

procedure TCalcPriceFixture.CalcPricesProc_LargeFractionalPrice;
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(1_199_999.99, 20, WithNDS, WithoutNDS);
  Assert.IsTrue(CheckNum(WithoutNDS));
  Assert.IsTrue(CheckNum(WithNDS));
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, 20));
  Assert.IsTrue(WithNDS >= 0);
end;

// ---------------------------------------------------------------------------
// Round-trip validation
// ---------------------------------------------------------------------------

procedure TCalcPriceFixture.CalcPricesProc_RoundTrip_ValidatesCorrectness(
  InputPrice: double; ProcNDS: Integer);
var
  WithNDS, WithoutNDS: double;
begin
  CalcPricesProc(InputPrice, ProcNDS, WithNDS, WithoutNDS);
  Assert.IsTrue(CheckNum(WithoutNDS),
    'WithoutNDS=' + FloatToStr(WithoutNDS) + ' has >2 decimals');
  Assert.IsTrue(CheckNum(WithNDS),
    'WithNDS=' + FloatToStr(WithNDS) + ' has >2 decimals');
  Assert.IsTrue(RoundTripHolds(WithoutNDS, WithNDS, ProcNDS),
    Format('Round-trip failed: %.4f * %.2f = %.4f, expected %.4f',
      [WithoutNDS, 1 + ProcNDS/100, WithoutNDS*(1+ProcNDS/100), WithNDS]));
end;

initialization
  TDUnitX.RegisterTestFixture(TCalcPriceFixture);

end.
