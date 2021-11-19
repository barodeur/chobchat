module Uint8Array = Js.TypedArray2.Uint8Array

@val @scope("Array")
external arrayFromUint8Array: Uint8Array.t => array<int> = "from"

let charArrToString = chars => chars->Belt.Array.map(String.make(1, _))->Js.Array2.joinWith(_, "")
let stringToCharArr = str => str->Js.String2.split("")->Belt.Array.map(String.get(_, 0))
let stringToByteArr = str =>
  str->stringToCharArr->Belt.Array.map(Char.code)->Js.TypedArray2.Uint8Array.make
let byteArrToString: Uint8Array.t => string = bytes =>
  bytes->arrayFromUint8Array->Belt.Array.map(Char.chr)->charArrToString

Jest.describe("Base58", () => {
  Jest.describe("encode", () => {
    let enhanced = str => str->stringToByteArr->Base58.encode->charArrToString
    Jest.test("encode 'test'", () => {
      Jest.expect("test"->enhanced)->Jest.toEqual("3yZe7d")
    })

    Jest.test("encode 'il était une dois un petit'", () => {
      Jest.expect("il était une dois un petit"->enhanced)->Jest.toEqual(
        "FFQQC2nhWSe3xFoqXnxiqPxMeYCVRzjjyFKTR",
      )
    })
  })

  Jest.describe("decode", () => {
    let enhanced = str => str->stringToCharArr->Base58.decode->byteArrToString

    Jest.test("decode encode('test')", () => {
      Jest.expect("3yZe7d"->enhanced)->Jest.toEqual("test")
    })

    Jest.test("decode encode('il était une dois un petit')", () => {
      Jest.expect("FFQQC2nhWSe3xFoqXnxiqPxMeYCVRzjjyFKTR"->enhanced)->Jest.toEqual(
        "il était une dois un petit",
      )
    })
  })
})
