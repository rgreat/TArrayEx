Generic Array with extra features.

Basically:
```
  TArrayEx<T> = record
    Items      : array of T;
    // a lot of stuff
  end;
```
Basic usage:
```
var
  A : TArray<Integer>;
  B,C : TArrayEx<Integer>;
begin  
  A := [5,6,7,8,9];
  B := [1,2,3,4,5];
  C := A + B;  // concat and implicit typecast

  WriteLn(C.ToString);  // To string RTTI conversion
  WriteLn('A + B = C is ', A + B = C); // compare arrays

  C.Add(10);
  C.AddUnique(10);  // will not be added
  C.Delete(C.High); // delete last
  WriteLn(C.ToString);

  // More features are shown in example and in unit code.
end.
```
