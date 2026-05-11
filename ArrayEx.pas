unit ArrayEx;

interface

{$IFNDEF DEBUG}
  {$D-$L-}
{$ENDIF}


// (c) Roman Lyakh  rgreat@rgreat.ru
// Freeware

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
  {$DEFINE MODERNCOMPILER}
  {$WARN 3057 off : An inherited method is hidden by "$1"}
  {$WARN 5079 off : Unit "$1" is experimental}
{$ELSE}
  {$IF CompilerVersion>27}
    {$DEFINE MODERNCOMPILER}
    {$IFNDEF DEBUG}
       {$DEFINE Inline}
    {$ENDIF}
  {$ENDIF}
  {$IF CompilerVersion>=34}
     {$DEFINE MANAGEDRECORDS}
  {$ENDIF}
{$ENDIF}

uses
  Classes, Generics.Defaults, Generics.Collections, SysUtils, Math;

const
  HashTableDefExpectedCount = 64;

type

  // -------------------------------------------------------------------------
  // ------------------------- Support Types ---------------------------------
  // -------------------------------------------------------------------------

{$REGION 'Support Types'}
  // Integer Array
  TIntegerArray = TArray<integer>;
  // String Array
  TStringArray = TArray<string>;

  // Comparator types
  TCompareResult = (crLess,crEqual,crMore);
  TCompareMode = (cmAscending, cmDescending);
  // User comparator types
{$IFDEF FPC}
  TCompareValue<T> = function(const Item1,Item2: T): TCompareResult;
  TAction<T>       = procedure(const Item: T);
{$ELSE}
  TCompareValue<T> = reference to function(const Item1,Item2: T): TCompareResult;
  TAction<T>       = reference to procedure(const Item: T);
{$ENDIF}
  TPredicate<T>    = function(const Item: T): Boolean of object;

  EIndexDuplicateKeyException = class(Exception);

  TArrayExCompareUnchangedResult = record
    Old: integer;
    New: integer;
  end;

  TArrayExCompareResults = record
    Added: TArray<integer>;
    Removed: TArray<integer>;
    Unchanged: TArray<TArrayExCompareUnchangedResult>;
  end;

{$ENDREGION}

  // -------------------------------------------------------------------------
  // --------------------- TArrayEx (Extended array) -------------------------
  // -------------------------------------------------------------------------

  {$REGION 'TArrayEx'}

  { TArrayEx }

  TArrayEx<T> = record
  public
    // Direct item access (unsafe)
    Items      : array of T;

    // User Tag
    Tag        : integer;

    // Need to free elements on destroy
    OwnValues  : Boolean;
    // Optional Alias (deprecated)
    property DoFreeData: boolean read OwnValues write OwnValues;
  private
    type
      TItems = array of T;
      PItems = ^TItems;

      TItemEnumerator = class(TEnumerator<T>)
      private
        Parent  : PItems;
        FIndex  : Integer;
        function GetCurrent: T;
      protected
        function DoGetCurrent: T; override;
        function DoMoveNext: Boolean; override;
      public
        constructor Create(const Parent: TArrayEx<T>);
        property Current: T read GetCurrent;
        function MoveNext: Boolean;
      end;

    var
{$IFNDEF MANAGEDRECORDS}
      FInitCapacity : string;                       // Workaround for older delphi
{$ENDIF}
      FIndexArray   : array of array of integer;    // Hash structure
      FComparer     : IEqualityComparer<T>;         // Comparer
      FCapacity     : integer;                      // Amount of allocated memory for items
      FOptimisation : Boolean;                      // SetLength optimisations

    function GetElement(Index: integer): T; {$IFDEF Inline} inline; {$ENDIF}
    procedure SetElement(Index: integer; const Value: T); {$IFDEF Inline} inline; {$ENDIF}
    procedure QuickSortA(const Comparer: IComparer<T>; L, R: Integer); {$IFDEF Inline} inline; {$ENDIF}
    procedure QuickSortB(L, R: Integer; CompareEvt: TCompareValue<T>; Less, More: TCompareResult); {$IFDEF Inline} inline; {$ENDIF}
    procedure HashClear(NewIndexMod: integer); {$IFDEF Inline} inline; {$ENDIF}
    procedure HashAdd(const Value: T; Index: integer); {$IFDEF Inline} inline; {$ENDIF}
    function GetHash(const Value: T): integer; {$IFDEF Inline} inline; {$ENDIF}
    procedure SetIndex(Index: Integer; const Value: T); {$IFDEF Inline} inline; {$ENDIF}
    procedure SetCount(const Value: integer); {$IFDEF Inline} inline; {$ENDIF}
    function GetCount: integer; {$IFDEF Inline} inline; {$ENDIF}
    function GetHigh: integer; {$IFDEF Inline} inline; {$ENDIF}
    procedure SetHigh(const Value: integer); {$IFDEF Inline} inline; {$ENDIF}
    function GetLow: integer; {$IFDEF Inline} inline; {$ENDIF}
    procedure FreeElement(Num: integer); {$IFDEF Inline} inline; {$ENDIF}
    procedure SetLengthFast(NewValue: integer);
    procedure SetOptimisation(const Value: Boolean);
    function GetFirst: T;
    function GetLast: T;
    procedure SetFirst(const Value: T);
    procedure SetLast(const Value: T);
{$IFDEF FPC}
    function InternalAdd(Value: T): integer;
{$ENDIF}
  public
    // Constructor
    constructor Create(OwnValues: boolean);

    // Access to elements by default
    property Elements[Index: integer]: T read GetElement write SetElement; default;

    // Clear array
    procedure Clear; overload;

    // Array items count
    property Count: integer read GetCount write SetCount;
    // First element index
    property Low: integer read GetLow;
    // Last element index
    property High: integer read GetHigh write SetHigh;
    // if Count=0 ?
    function IsEmpty: boolean;

    // Add item to the end of the array
    function Add(Value: T): integer; overload; {$IFDEF Inline} inline; {$ENDIF}
    function Add(const Values: array of T): integer; overload;
    function Add(const Values: TArrayEx<T>): integer; overload;
    function AddUnique(Value: T): integer; {$IFDEF Inline} inline; {$ENDIF}

    // Insert element by index
    procedure Insert(Index: integer; Value: T); overload; {$IFDEF Inline} inline; {$ENDIF}
    procedure Insert(Index: integer; const Values: array of T); overload;
    procedure Insert(Index: integer; const Values: TArrayEx<T>); overload;

    // Delete element(s) by index
    procedure Delete(Index: integer); {$IFDEF Inline} inline; {$ENDIF}
    procedure DeleteValues(Value: T); {$IFDEF Inline} inline; {$ENDIF}
    procedure DeleteRange(Index, Count: integer); {$IFDEF Inline} inline; {$ENDIF}
    procedure DeleteFirst; {$IFDEF Inline} inline; {$ENDIF}
    procedure DeleteLast; {$IFDEF Inline} inline; {$ENDIF}

    // Copy elements
    function Copy(Index, Count: integer): TArrayEx<T>;

    // Assign data from Source
    procedure Assign(Source: TArrayEx<T>);

    // Create Hash Table
    procedure CreateIndex(IndexMod: integer = -1);
    // Clear Hash Table
    procedure DropIndex;
    procedure ClearIndex;

    // First and last elements of array
    property First: T read GetFirst write SetFirst;
    property Last: T read GetLast write SetLast;

    // Memory management optimization
    property Optimisation: Boolean read FOptimisation write SetOptimisation;

    // Search of element in array
    function Exists(Value: T): boolean; overload; {$IFDEF Inline} inline; {$ENDIF}
    function Exists(Values: array of T; NeedAllValues: boolean = False): boolean; overload;
    function Exists(Values: TArrayEx<T>; NeedAllValues: boolean = False): boolean; overload;
    // Get first index in array for a value
    function IndexOf(Value: T): integer; {$IFDEF Inline} inline; {$ENDIF}
{$IFNDEF FPC}
    // Get all indexes in array for a value
    function IndexesOf(Value: T): TArrayEx<integer>; {$IFDEF Inline} inline; {$ENDIF}
{$ELSE}
    // Get all indexes in array for a value
    function IndexesOf(Value: T): TArray<integer>; {$IFDEF Inline} inline; {$ENDIF}
{$ENDIF}
    function IndexIsValid(Index: integer): boolean;
    function RangeIsValid(Index, Length: integer): boolean;

    // Sort array
    procedure Sort(Comparer: IComparer<T> = nil); overload;
    procedure Sort(CompareEvt: TCompareValue<T>; Mode: TCompareMode = cmAscending); overload;
    property Comparer: IEqualityComparer<T> read FComparer write FComparer;

    // Compare
    function CompareValuesWith(NewData: TArrayEx<T>): TArrayExCompareResults;
    // Serialisation to string
{$IFNDEF FPC}
    function ToString: string; overload;
    function ToString(Delimeter : string; Quotes: string = ''; Prefix: string = ''): string; overload;
{$ENDIF}

{$IFDEF MODERNCOMPILER}
    // Enumerator
    function GetEnumerator: TItemEnumerator;
  public
{$ENDIF}

{$IFDEF MANAGEDRECORDS}
    // Init array
    class operator Initialize(out Dest: TArrayEx<T>);
    class operator Finalize(var Dest: TArrayEx<T>);
{$ENDIF}

    // Class operators
    class operator Add(const A,B: TArrayEx<T>): TArrayEx<T>; overload;
    class operator Add(const A: TArrayEx<T>; const B: array of T): TArrayEx<T>; overload;
    class operator Add(const A: array of T; const B: TArrayEx<T>): TArrayEx<T>; overload;
    class operator Implicit(const A: TArrayEx<T>): TArray<T>; overload;
    class operator Implicit(const A: TArray<T>): TArrayEx<T>; overload;
    class operator Implicit(const A: array of T): TArrayEx<T>; overload;
{$IFDEF MODERNCOMPILER}
    class operator In(const A,B: TArrayEx<T>): Boolean; overload;
    class operator In(const A: array of T; B: TArrayEx<T>): Boolean; overload;
{$ENDIF}
    class operator Equal(const A,B: TArrayEx<T>): Boolean;
    class operator NotEqual(const A,B: TArrayEx<T>): Boolean;
  end;
  {$ENDREGION}

var
  // Global Modifiers

  TArrayExUseOptimisation            : boolean = True;
  TArrayExHideExceptionsOnFree       : boolean = True;
  TArrayExHideExceptionsOnRangeCheck : boolean = False;

implementation

uses TypInfo, RTTI;

{$REGION 'Support functions & Types'}

type
{$IFNDEF FPC}
   RTLString = string;
{$ELSE}
   RTLString = AnsiString;
{$ENDIF}

function CompareIntegerLocal(const Value1, Value2: Integer): TCompareResult;
begin
  if Value1<Value2 then begin
    Result:=crLess;
  end else begin
    if Value1>Value2 then begin
      Result:=crMore;
    end else begin
      Result:=crEqual;
    end;
  end;
end;

function CompareInt64Local(const Value1, Value2: Int64): TCompareResult;
begin
  if Value1<Value2 then begin
    Result:=crLess;
  end else begin
    if Value1>Value2 then begin
      Result:=crMore;
    end else begin
      Result:=crEqual;
    end;
  end;
end;

function CompareStringLocal(const Value1, Value2: String): TCompareResult;
begin
  if Value1<Value2 then begin
    Result:=crLess;
  end else begin
    if Value1>Value2 then begin
      Result:=crMore;
    end else begin
      Result:=crEqual;
    end;
  end;
end;

{$ENDREGION}

function CompareVariantLocal(const Value1, Value2: Variant): TCompareResult;
begin
  if Value1<Value2 then begin
    Result:=crLess;
  end else begin
    if Value1>Value2 then begin
      Result:=crMore;
    end else begin
      Result:=crEqual;
    end;
  end;
end;

{$REGION 'TArrayEx Implementation'}

{ TArrayEx }

procedure TArrayEx<T>.SetCount(const Value: integer);
begin
  SetLengthFast(Value);

  if Length(FIndexArray)>0 then begin
    CreateIndex(Value);
  end;
end;

procedure TArrayEx<T>.SetHigh(const Value: integer);
begin
  SetCount(Value+1);
end;

procedure TArrayEx<T>.SetIndex(Index: Integer; const Value: T);
begin
  if Length(FIndexArray)=0 then Exit;

  if Index>=Length(FIndexArray) then begin
    CreateIndex(Max(Index,FCapacity));
  end else begin
    HashAdd(Value,Index);
  end;
end;

function TArrayEx<T>.Add(Value: T): integer;
begin
  Result:=Length(Items);
  SetLengthFast(Result+1);

  Elements[Result]:=Value;
end;

function TArrayEx<T>.Add(const Values: array of T): integer;
var
  i: Integer;
begin
  Result:=Count;
  SetLengthFast(Result+Length(Values));
  for i:=0 to System.High(Values) do begin
    Elements[Result+i]:=Values[i];
  end;
  Result:=High;
end;

function TArrayEx<T>.AddUnique(Value: T): integer;
begin
  Result:=IndexOf(Value);
  if Result<0 then begin
{$IFDEF FPC}
    Result:=InternalAdd(Value);
{$ELSE}
    Result:=Add(Value);
{$ENDIF}
  end;
end;

procedure TArrayEx<T>.Assign(Source: TArrayEx<T>);
var
  i: integer;
begin
  Clear;
  Count:=Source.Count;
  for i:=0 to Source.High do begin
    Items[i]:=Source.Items[i];
  end;
end;

procedure TArrayEx<T>.Delete(Index: integer);
var
  i: Integer;
begin
  if not IndexIsValid(Index) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create(Index.ToString+' is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  if OwnValues and (PTypeInfo(TypeInfo(T)).Kind=tkClass) then begin
    FreeElement(Index);
  end;

  for i:=Index+1 to High do begin
    Items[i-1]:=Items[i];
  end;
  SetLengthFast(Length(Items)-1);

  DropIndex;
end;

procedure TArrayEx<T>.DeleteValues(Value: T);
var
  i   : integer;
  Idx : TArrayEx<integer>;
begin
  Idx:=IndexesOf(Value);

  for i:=Idx.High downto 0 do begin
    Delete(Idx[i]);
  end;
end;


procedure TArrayEx<T>.DeleteFirst;
begin
  Delete(0);
end;

procedure TArrayEx<T>.DeleteLast;
begin
  Delete(High);
end;

procedure TArrayEx<T>.DeleteRange(Index, Count: integer);
var
  i: Integer;
begin
  if not RangeIsValid(Index, Count) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create('Range ['+Index.ToString+'..'+(Index+Count-1).ToString+'] is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  if (Count<1) then Exit;
  if Index+Count>Self.Count then Count:=Self.Count-Index;

  if OwnValues and (PTypeInfo(TypeInfo(T)).Kind=tkClass) then begin
    for i:=Index to Index+Count-1 do begin
      FreeElement(i);
    end;
  end;

  for i:=Index+Count to High do begin
    Items[i-Count]:=Items[i];
  end;
  SetLengthFast(Length(Items)-Count);

  DropIndex;
end;

procedure TArrayEx<T>.DropIndex;
begin
  HashClear(0);
end;


{$IFNDEF FPC}

function TArrayEx<T>.IndexesOf(Value: T): TArrayEx<integer>;
var
  i,m    : integer;
begin
  if Count<=50 then begin
    if not Assigned(FComparer) then begin
      FComparer:=TEqualityComparer<T>.Default;
    end;
    for i:=0 to High do begin
      if FComparer.Equals(Items[i],Value) then begin
        Result.Add(i);
      end;
    end;
    Exit;
  end;

  m:=Length(FIndexArray);

  if m=0 then begin
    CreateIndex;
    m:=Length(FIndexArray);
  end;

  m:=Abs(GetHash(Value) mod m);

  Result.Clear;
  for i:=0 to System.High(FIndexArray[m]) do begin
    if FComparer.Equals(Items[FIndexArray[m,i]],Value) then begin
      Result.Add(FIndexArray[m,i]);
    end;
  end;
  Result.Sort;
end;

{$ELSE}

function TArrayEx<T>.IndexesOf(Value: T): TArray<integer>;
var
  i,m,n : integer;
begin
  if Count<=50 then begin
    if not Assigned(FComparer) then begin
      FComparer:=TEqualityComparer<T>.Default;
    end;
    n:=-1;
    for i:=0 to High do begin
      if FComparer.Equals(Items[i],Value) then begin
        inc(n);
        SetLength(Result,n+1);
        Result[n]:=i;
      end;
    end;
    Exit;
  end;

  m:=Length(FIndexArray);

  if m=0 then begin
    CreateIndex;
    m:=Length(FIndexArray);
  end;

  m:=Abs(GetHash(Value) mod m);

  SetLength(Result,0);
  n:=-1;
  for i:=0 to System.High(FIndexArray[m]) do begin
    if FComparer.Equals(Items[FIndexArray[m,i]],Value) then begin
      inc(n);
      SetLength(Result,n+1);
      Result[n]:=FIndexArray[m,i];
    end;
  end;
end;
{$ENDIF}

function TArrayEx<T>.IndexIsValid(Index: integer): boolean;
begin
  Result:=(Index>=0) and (Index<=High);
end;

function TArrayEx<T>.RangeIsValid(Index, Length: integer): boolean;
begin
  Result:=(Index>=0) and ((Index+Length<=Count));
end;


function TArrayEx<T>.IndexOf(Value: T): integer;
var
  i,m,Hash : integer;
begin
  if Count<=50 then begin
    if not Assigned(FComparer) then begin
      FComparer:=TEqualityComparer<T>.Default;
    end;
    for i:=0 to High do begin
      if FComparer.Equals(Items[i],Value) then begin
        Exit(i);
      end;
    end;
    Exit(-1);
  end;

  if Length(FIndexArray)=0 then begin
    CreateIndex;
  end;

  Hash:=GetHash(Value);
  m:=Abs(Hash mod Length(FIndexArray));

  for i:=0 to System.High(FIndexArray[m]) do begin
    if FComparer.Equals(Items[FIndexArray[m,i]],Value) then begin
      Exit(FIndexArray[m,i]);
    end;
  end;

  Result:=-1;
end;


procedure TArrayEx<T>.Insert(Index: integer; const Values: TArrayEx<T>);
begin
  Insert(Index,Values.Items);
end;

procedure TArrayEx<T>.Insert(Index: integer; const Values: array of T);
var
  i: Integer;
begin
  if (Index>0) and (Index>Count) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create(Index.ToString+' is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  SetLengthFast(Length(Items)+length(Values));
  for i:=High downto Index+length(Values) do begin
    Items[i]:=Items[i-length(Values)];
  end;

  for i:=0 to System.High(Values) do begin
    Items[Index+i]:=Values[i];
  end;

  DropIndex;
end;

function TArrayEx<T>.IsEmpty: boolean;
begin
  Result:=Count=0;
end;

function TArrayEx<T>.GetElement(Index: integer): T;
begin
  if not IndexIsValid(Index) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit(Default(T));
    raise ERangeError.Create(Index.ToString+' is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  Result:=Items[Index];
end;

function TArrayEx<T>.GetEnumerator: TItemEnumerator;
begin
  Result := TItemEnumerator.Create(Self);
end;

function TArrayEx<T>.GetFirst: T;
begin
  if IsEmpty then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit(Default(T));
    raise ERangeError.Create('Array is Empty');
  end;

  Result:=Items[0];
end;

function TArrayEx<T>.GetLast: T;
begin
  if IsEmpty then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit(Default(T));
    raise ERangeError.Create('Array is Empty');
  end;

  Result:=Items[High];
end;

function TArrayEx<T>.GetLow: integer;
begin
  Result:=0;
end;

procedure TArrayEx<T>.HashClear(NewIndexMod: integer);
begin
  if (NewIndexMod=0) and (Length(FIndexArray)=0) then Exit;

  System.SetLength(FIndexArray,0);
  if NewIndexMod>0 then begin
    System.SetLength(FIndexArray,NewIndexMod);
  end;
end;

function TArrayEx<T>.GetCount: integer;
begin
  Result:=Length(Items);
end;

function TArrayEx<T>.GetHash(const Value: T): integer;
begin
  Result:=TEqualityComparer<T>.Default.GetHashCode(Value);
end;

function TArrayEx<T>.GetHigh: integer;
begin
  Result:=System.High(Items);
end;

procedure TArrayEx<T>.HashAdd(const Value: T; Index: integer);
var
  n,m     : integer;
begin
  m:=Abs(GetHash(Value) mod Length(FIndexArray));
  n:=length(FIndexArray[m]);

  SetLength(FIndexArray[m],n+1);
  FIndexArray[m,n]:=Index;
end;

procedure TArrayEx<T>.FreeElement(Num: integer);
begin
  try
    PObject(@Items[num])^.Free;
    Items[num]:=Default(T);
  except
    if not TArrayExHideExceptionsOnFree then Raise;
  end;
end;

procedure TArrayEx<T>.Clear;
var
  i: Integer;
begin
  if OwnValues and (PTypeInfo(TypeInfo(T)).Kind=tkClass) then begin
    for i:=0 to High do begin
      FreeElement(i);
    end;
  end;

  SetLengthFast(0);
  ClearIndex;
end;

procedure TArrayEx<T>.ClearIndex;
begin
  HashClear(0);
end;

function TArrayEx<T>.CompareValuesWith(NewData: TArrayEx<T>): TArrayExCompareResults;
var
  i,Cnt: integer;
begin
  Cnt:=0;
  for i:=0 to NewData.High do begin
    if Exists(NewData[i]) then Continue;

    inc(Cnt);
    if Length(Result.Added)<Cnt then begin
      SetLength(Result.Added,Cnt+1024);
    end;
    Result.Added[Cnt-1]:=i;
  end;
  SetLength(Result.Added,Cnt);

  Cnt:=0;
  for i:=0 to High do begin
    if NewData.Exists(Items[i]) then Continue;

    inc(Cnt);
    if Length(Result.Removed)<Cnt then begin
      SetLength(Result.Removed,Cnt+1024);
    end;
    Result.Removed[Cnt-1]:=i;
  end;
  SetLength(Result.Removed,Cnt);

  Cnt:=0;
  for i:=0 to High do begin
    var n:=NewData.IndexOf(Items[i]);
    if n<0 then Continue;

    inc(Cnt);
    if Length(Result.Unchanged)<Cnt then begin
      SetLength(Result.Unchanged,Cnt+1024);
    end;
    Result.Unchanged[Cnt-1].Old:=i;
    Result.Unchanged[Cnt-1].New:=n;
  end;
  SetLength(Result.Unchanged,Cnt);
end;

function TArrayEx<T>.Copy(Index, Count: integer): TArrayEx<T>;
var
  i : integer;
begin
  Result.Clear;

  if not RangeIsValid(Index, Count) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create('Range ['+Index.ToString+'..'+(Index+Count-1).ToString+'] is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  Result.Count:=Count;
  for i:=0 to Count-1 do begin
    Result.Items[i]:=Items[Index+i];
  end;
end;

constructor TArrayEx<T>.Create(OwnValues: boolean);
begin
  Tag:=0;
  Clear;
  Self.OwnValues:=OwnValues;
end;

procedure TArrayEx<T>.CreateIndex(IndexMod: integer = -1);
var
  i : integer;
begin
  FComparer:=TEqualityComparer<T>.Default;

  if IndexMod=-1 then begin
    if Count=0 then begin
      IndexMod:=HashTableDefExpectedCount;
    end else begin
      IndexMod:=Count;
    end;
  end;
  HashClear(IndexMod);

  if IndexMod>0 then begin
    for i:=Low to High do begin
      HashAdd(Items[i],i);
    end;
  end;
end;

procedure TArrayEx<T>.Insert(Index: integer; Value: T);
var
  i: Integer;
begin
  if (Index>0) and (Index>Count) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create(Index.ToString+' is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  SetLengthFast(Length(Items)+1);
  for i:=High downto Index+1 do begin
    Items[i]:=Items[i-1];
  end;
  Items[Index]:=Value;

  DropIndex;
end;

procedure TArrayEx<T>.SetElement(Index: integer; const Value: T);
begin
  if not IndexIsValid(Index) then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create(Index.ToString+' is outside of array ['+Low.ToString+'..'+High.ToString+']');
  end;

  Items[Index]:=Value;
  SetIndex(Index,Value);
end;

procedure TArrayEx<T>.SetFirst(const Value: T);
begin
  if IsEmpty then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create('Array is Empty');
  end;

  Items[0]:=Value;
end;

procedure TArrayEx<T>.SetLast(const Value: T);
begin
  if IsEmpty then begin
    if TArrayExHideExceptionsOnRangeCheck then Exit;
    raise ERangeError.Create('Array is Empty');
  end;

  Items[High]:=Value;
end;

procedure TArrayEx<T>.SetLengthFast(NewValue: integer);
{$IFNDEF FPC}
const
  GrowLimit = 64;
{$ENDIF}
begin
{$IFNDEF MANAGEDRECORDS}
  if FInitCapacity='' then begin
    FInitCapacity:='Y';
    FCapacity:=0;
  end;
{$ENDIF}

  if NewValue<=0 then begin
    FCapacity:=0;
    SetLength(Items,0);
  end else begin
{$IFNDEF FPC}
    if FOptimisation then begin
      if (NewValue>FCapacity) or (NewValue shl 1<FCapacity) then begin
        FCapacity:=Min(NewValue shl 1,NewValue+GrowLimit);
        SetLength(Items,FCapacity);
      end;
      PNativeInt(NativeInt(@Items[0])-SizeOf(NativeInt))^:=NewValue;
    end else begin
      FCapacity:=NewValue;
      SetLength(Items,NewValue);
    end;
{$ELSE}
    FCapacity:=NewValue;
    SetLength(Items,NewValue);
{$ENDIF}
  end;
end;

procedure TArrayEx<T>.SetOptimisation(const Value: Boolean);
begin
  FOptimisation:=Value;
  if not Value then begin
    SetLength(Items,Count);
  end;
end;

{$IFDEF FPC}
function TArrayEx<T>.InternalAdd(Value: T): integer;
begin
  Result:=Length(Items);
  SetLengthFast(Result+1);

  Items[Result]:=Value;
  SetIndex(Result,Value);
end;
{$ENDIF}

procedure TArrayEx<T>.QuickSortA(const Comparer: IComparer<T>; L, R: Integer);
var
  I, J: Integer;
  pivot, temp: T;
begin
  if (Length(Items) = 0) or ((R - L) <= 0) then
    Exit;
  repeat
    I := L;
    J := R;
    pivot := Items[L + (R - L) shr 1];
    repeat
      while Comparer.Compare(Items[I], pivot) < 0 do
        Inc(I);
      while Comparer.Compare(Items[J], pivot) > 0 do
        Dec(J);
      if I <= J then
      begin
        if I <> J then
        begin
          temp := Items[I];
          Items[I] := Items[J];
          Items[J] := temp;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      QuickSortA(Comparer, L, J);
    L := I;
  until I >= R;
end;

procedure TArrayEx<T>.Sort(Comparer: IComparer<T> = nil);
var
  OIndexMod: integer;
begin
  OIndexMod:=Length(FIndexArray);
  if OIndexMod>0 then DropIndex;

  if Comparer=nil then Comparer:=TComparer<T>.Default;
  QuickSortA(Comparer, 0, High);

  if OIndexMod>0 then CreateIndex(OIndexMod);
end;

procedure TArrayEx<T>.QuickSortB(L, R: Integer; CompareEvt: TCompareValue<T>; Less, More: TCompareResult);
var
  I, J: Integer;
  pivot, temp: T;
begin
  if (Length(Items) = 0) or ((R - L) <= 0) then
    Exit;
  repeat
    I := L;
    J := R;
    pivot := Items[L + (R - L) shr 1];
    repeat
      while CompareEvt(Items[I], pivot) = crLess do
        Inc(I);
      while CompareEvt(Items[J], pivot) = crMore do
        Dec(J);
      if I <= J then
      begin
        if I <> J then
        begin
          temp := Items[I];
          Items[I] := Items[J];
          Items[J] := temp;
        end;
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      QuickSortB(L, J, CompareEvt, Less, More);
    L := I;
  until I >= R;
end;

procedure TArrayEx<T>.Sort(CompareEvt: TCompareValue<T>; Mode: TCompareMode = cmAscending);
var
  OIndexMod: integer;
  Less,More: TCompareResult;
begin
  OIndexMod:=Length(FIndexArray);
  if OIndexMod>0 then DropIndex;

  if not Assigned(CompareEvt) then Exit;

  if Mode=cmAscending then begin
    Less:=crLess;
    More:=crMore;
  end else begin
    Less:=crMore;
    More:=crLess;
  end;

  QuickSortB(Low,High,CompareEvt,Less,More);

  if OIndexMod>0 then CreateIndex(OIndexMod);
end;

{$IFNDEF FPC}
function TArrayEx<T>.ToString(Delimeter: string; Quotes: string = ''; Prefix: string = ''): string;
var
  i : Integer;
  s : string;
begin
  Result:='';
  for i:=Low to High do begin
    if (Result<>'') then begin
      s:=Delimeter+Quotes+Prefix+TValue.From<T>(Items[i]).ToString+Quotes;
    end else begin
      s:=Quotes+Prefix+TValue.From<T>(Items[i]).ToString+Quotes;
    end;
    Result:=Result+s;
  end;
end;

function TArrayEx<T>.ToString: string;
begin
  Result:=ToString(';');
end;
{$ENDIF}

function TArrayEx<T>.Exists(Value: T): boolean;
begin
  Result:=IndexOf(Value)>=0;
end;

function TArrayEx<T>.Exists(Values: array of T; NeedAllValues: boolean = False): boolean;
var
  i: Integer;
begin
  Result:=NeedAllValues;

  for i:=0 to System.High(Values) do begin
    if NeedAllValues then begin
      if IndexOf(Values[i])<0 then Exit(False);
    end else begin
      if IndexOf(Values[i])>=0 then Exit(True);
    end;
  end;
end;

{ TArrayEx<T>.TValueEnumerator }

constructor TArrayEx<T>.TItemEnumerator.Create(const Parent: TArrayEx<T>);
begin
  inherited Create;
  FIndex:=-1;
  Self.Parent:=@Parent.Items;
end;


function TArrayEx<T>.TItemEnumerator.DoGetCurrent: T;
begin
  Result:=Parent^[FIndex];
end;

function TArrayEx<T>.TItemEnumerator.DoMoveNext: Boolean;
begin
  if FIndex<System.High(Parent^) then begin
    inc(FIndex);
    Result:=True;
  end else begin
    Result:=False;
  end;
end;

function TArrayEx<T>.TItemEnumerator.GetCurrent: T;
begin
  Result:=DoGetCurrent;
end;

function TArrayEx<T>.TItemEnumerator.MoveNext: Boolean;
begin
  Result:=DoMoveNext;
end;

{$IFDEF MANAGEDRECORDS}
class operator TArrayEx<T>.Initialize(out Dest: TArrayEx<T>);
begin
  Dest.Tag:=0;
  Dest.FComparer:=nil;
  Dest.FCapacity:=0;
  Dest.FOptimisation:=TArrayExUseOptimisation;
  Dest.OwnValues:=False;
end;

class operator TArrayEx<T>.Finalize(var Dest: TArrayEx<T>);
var
  i : integer;
begin
  if Dest.OwnValues and (PTypeInfo(TypeInfo(T)).Kind=tkClass) then begin
    for i:=0 to Dest.High do begin
      Dest.FreeElement(i);
    end;
  end;
end;
{$ENDIF}

class operator TArrayEx<T>.Add(const A, B: TArrayEx<T>): TArrayEx<T>;
var
  i: Integer;
begin
  Result:=A;
  for i:=0 to B.High do begin
{$IFDEF FPC}
    Result.InternalAdd(B.Items[i]);
{$ELSE}
    Result.Add(B.Items[i]);
{$ENDIF}
  end;
end;

class operator TArrayEx<T>.Add(const A: TArrayEx<T>; const B: array of T): TArrayEx<T>;
var
  i: Integer;
begin
  Result:=A;
  for i:=0 to System.High(B) do begin
{$IFDEF FPC}
    Result.InternalAdd(B[i]);
{$ELSE}
    Result.Add(B[i]);
{$ENDIF}
  end;
end;

class operator TArrayEx<T>.Add(const A: array of T; const B: TArrayEx<T>): TArrayEx<T>;
var
  i: Integer;
begin
  Result.Clear;
  for i:=0 to System.High(A) do begin
{$IFDEF FPC}
    Result.InternalAdd(A[i]);
{$ELSE}
    Result.Add(A[i]);
{$ENDIF}
  end;
  for i:=0 to B.High do begin
{$IFDEF FPC}
    Result.InternalAdd(B.Items[i]);
{$ELSE}
    Result.Add(B.Items[i]);
{$ENDIF}
  end;
  if length(B.FIndexArray)>0 then begin
    Result.CreateIndex;
  end;
end;

function TArrayEx<T>.Add(const Values: TArrayEx<T>): integer;
var
  i: Integer;
begin
  Result:=Length(Items);
  SetLengthFast(Result+Values.Count);
  for i:=0 to Values.High do begin
    Elements[Result+i]:=Values.Items[i];
  end;
end;

class operator TArrayEx<T>.Implicit(const A: TArrayEx<T>): TArray<T>;
begin
  SetLength(Result,A.Count);
  for var i:=0 to A.High do begin
    Result[i]:=A[i];
  end;
end;

class operator TArrayEx<T>.Implicit(const A: TArray<T>): TArrayEx<T>;
begin
  Result.Clear;
  SetLength(Result.Items,Length(A));
  for var i:=0 to System.High(A) do begin
    Result.Items[i]:=A[i];
  end;
end;

class operator TArrayEx<T>.Implicit(const A: array of T): TArrayEx<T>;
begin
  Result.Clear;
  SetLength(Result.Items,Length(A));
  for var i:=0 to System.High(A) do begin
    Result.Items[i]:=A[i];
  end;
end;

{$IFDEF MODERNCOMPILER}
class operator TArrayEx<T>.In(const A, B: TArrayEx<T>): Boolean;
begin
  Result:=B.Exists(A.Items,True);
end;

class operator TArrayEx<T>.In(const A: array of T; B: TArrayEx<T>): Boolean;
begin
  Result:=B.Exists(A,True);
end;
{$ENDIF}

class operator TArrayEx<T>.Equal(const A, B: TArrayEx<T>): Boolean;
var
  i        : integer;
  Comparer : IEqualityComparer<T>;
begin
  if length(A.Items)<>length(B.Items) then Exit(False);
  Comparer:=TEqualityComparer<T>.Default;

  for i:=0 to System.High(A.Items) do begin
    if not Comparer.Equals(A.Items[i],B.Items[i]) then Exit(False);
  end;
  Result:=True;
end;

function TArrayEx<T>.Exists(Values: TArrayEx<T>; NeedAllValues: boolean): boolean;
var
  i: Integer;
begin
  Result:=NeedAllValues;

  for i:=0 to Values.High do begin
    if NeedAllValues then begin
      if IndexOf(Values.Items[i])<0 then Exit(False);
    end else begin
      if IndexOf(Values.Items[i])>=0 then Exit(True);
    end;
  end;
end;

class operator TArrayEx<T>.NotEqual(const A, B: TArrayEx<T>): Boolean;
begin
  Result:=not (A=B);
end;
{$ENDREGION}

end.


