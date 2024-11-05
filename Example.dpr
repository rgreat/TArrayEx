program Example;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ArrayEx;

var
  A     : TArray<Integer>;
  B,C,D : TArrayEx<Integer>;


procedure PrintArray(Name: string; const Arr: TArrayEx<Integer>);
begin
  WriteLn(Name,' = [',Arr.ToString(', '),']');
end;

begin
  A := [5,6,7,8,9];
  B := [1,2,3,4,5];

  PrintArray('A', A);
  PrintArray('B', B);
  WriteLn('A = B: ', A = B);

  WriteLn;

  C := A + B;
  PrintArray('C', C);

  WriteLn('A + B = C: ', A + B = C);

  WriteLn;

  PrintArray('C',C);
  WriteLn('C Range: [', C.Low,' .. ', C.High,'] = ',C.Count,' elements.');
  WriteLn('C.First Value = ', C.First);
  WriteLn('C.Last Value = ', C.Last);

  WriteLn;

  WriteLn('Adding unique numbers 5 and 100...');

  C.AddUnique(5);
  C.AddUnique(11);

  PrintArray('C',C);

  WriteLn;

  D:=C.IndexesOf(5);
  WriteLn('Indexes of Value 5 = ', D.ToString);
  WriteLn('10 or 11 Exist in C = ',C.Exists([10,11]));
  WriteLn('10 and 11 Exist in C = ',C.Exists([10,11],True));

  WriteLn;
  WriteLn('Condensing C -> D...');
  D.Clear;
  for var Item in C do begin
    D.AddUnique(Item);
  end;
  PrintArray('D',D);

  WriteLn('Altering First and removing Last D Value...');
  D.First:=100;
  D.Delete(D.High);
  PrintArray('D',D);

  WriteLn('Sorting D...');

  D.Sort(function (const A,B: integer): TCompareResult begin
    if A<B then begin
      Result:=crLess;
    end else begin
      if A=B then begin
        Result:=crEqual;
      end else begin
        Result:=crMore;
      end;
    end;
  end);

  PrintArray('D',D);

  WriteLn;
  WriteLn('Comparing C with D...');

  var Compare:=C.CompareValuesWith(D);

  WriteLn('New elements added from D: [', TArrayEx<integer>(Compare.Added).ToString, ']');
  WriteLn('Existing elements removed from C: [', TArrayEx<integer>(Compare.Removed).ToString,']');
  WriteLn('Results come as indexes in array.');

  WriteLn;
  ReadLn;
end.
