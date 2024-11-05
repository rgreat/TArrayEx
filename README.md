Generic Array with extra features.

Basically:
  TArrayEx<T> = record
    Items      : array of T;
    // a lot of stuff
  end;

Basic usage:

var
  A,B,C : TArrayEx<Integer>;
begin  
  A := [5,6,7,8,9];
  B := [1,2,3,4,5];
  C := A + B;

  WriteLn(A.ToString);
  WriteLn(B.ToString);
  WriteLn(C.ToString);
  WriteLn('A + B = C is ', A + B = C);
end.
