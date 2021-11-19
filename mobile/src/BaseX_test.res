let {describe, test, expect, toEqual} = module(Jest)

describe("BaseX", () => {
  open BaseX
  module Uint8Array = Js.TypedArray2.Uint8Array

  describe("when using a BaseBinary", () => {
    module BaseBinary = Make({
      type digit = string
      let alphabet = ["0", "1"]
      let hash = s => s->String.get(0)->Char.code
      let eq = String.equal
    })

    test("Empty array", () => {
      expect(BaseBinary.encode(Uint8Array.fromLength(0)))->toEqual([])
    })

    test("Some values", () => {
      expect(BaseBinary.encode(Uint8Array.make([3])))->toEqual(["1", "1"])
    })
  })
})
