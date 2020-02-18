open Jest;
open Expect;

describe("Uuid", () => {
  test("checks is valid fails", () => {
    "foobar" |> SihlCoreUuid.V4.isValid |> expect |> ExpectJs.toBeFalsy
  });
  test("checks is valid", () => {
    "cd6c1c3f-1089-477f-8146-7becaa37dcfb"
    |> SihlCoreUuid.V4.isValid
    |> expect
    |> ExpectJs.toBeTruthy
  });
  test("checks is valid fails slightly wrong uuid", () => {
    "cd6c1c3f-1089-477f-8146-7becaa37dcfz"
    |> SihlCoreUuid.V4.isValid
    |> expect
    |> ExpectJs.toBeFalsy
  });
});
