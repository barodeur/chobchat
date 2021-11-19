// Encode Uint8Array into an alphabet

exception AlphabetTooShort
exception AlphabetTooLong
exception AmbiguousChar(string)

module Uint8Array = Js.TypedArray2.Uint8Array
module Math = Js.Math
module Int = Belt.Int

module type Base = {
  type digit
  let hash: digit => int
  let eq: (digit, digit) => bool
  let alphabet: array<digit>
}

module Make = (Base: Base) => {
  exception NonZeroCarry
  exception InvalidDigit(Base.digit)

  if Base.alphabet->Array.length < 2 {
    raise(AlphabetTooShort)
  }

  if Base.alphabet->Array.length > 256 {
    raise(AlphabetTooLong)
  }

  module DigitHash = Belt.Id.MakeHashable({
    type t = Base.digit
    let hash = Base.hash
    let eq = Base.eq
  })

  let baseMap = Belt.HashMap.make(~hintSize=256, ~id=module(DigitHash))
  Base.alphabet->Js.Array2.forEachi((c, i) => {
    baseMap->Belt.HashMap.set(c, i)
  })

  let baseSize = Base.alphabet->Array.length
  let leader = Base.alphabet->Array.unsafe_get(0)
  let factor = Math.log(baseSize->Int.toFloat) /. Math.log(256.)
  let ifactor = Math.log(256.) /. Math.log(baseSize->Int.toFloat)

  let encode: Uint8Array.t => array<Base.digit> = source => {
    if source->Uint8Array.length == 0 {
      []
    } else {
      // Skip & count leading zeroes.
      let zeroes = ref(0)
      let length = ref(0)
      let pbegin = ref(0)
      let pend = ref(source->Uint8Array.length)

      while (
        pbegin.contents != pend.contents && source->Uint8Array.unsafe_get(pbegin.contents) == 0
      ) {
        pbegin.contents = pbegin.contents + 1
        zeroes.contents = zeroes.contents + 1
      }

      // Allocate enough space in big-endian base58 representation.
      let size = ((pend.contents - pbegin.contents)->Int.toFloat *. ifactor +. 1.)->Math.floor_int
      let b58 = Uint8Array.fromLength(size)

      while pbegin.contents != pend.contents {
        let carry = ref(source->Uint8Array.unsafe_get(pbegin.contents))
        // Apply "b58 = b58 * 256 + ch".
        let i = ref(0)
        let it1 = ref(size - 1)
        while (carry.contents != 0 || i.contents < length.contents) && it1.contents != -1 {
          carry.contents = carry.contents + 256 * b58->Uint8Array.unsafe_get(it1.contents)
          b58->Uint8Array.unsafe_set(it1.contents, mod(carry.contents, baseSize))
          carry.contents = carry.contents / baseSize

          it1.contents = it1.contents - 1
          i.contents = i.contents + 1
        }
        if carry.contents != 0 {
          raise(NonZeroCarry)
        }
        length.contents = i.contents
        pbegin.contents = pbegin.contents + 1
      }
      let it2 = ref(size - length.contents)
      while it2.contents != size && b58->Uint8Array.unsafe_get(it2.contents) == 0 {
        it2.contents = it2.contents + 1
      }

      // Translate the result into a string.
      let str = Array.make(zeroes.contents, leader)
      while it2.contents < size {
        let newChar = Base.alphabet->Array.get(b58->Uint8Array.unsafe_get(it2.contents))
        str->Js.Array2.push(newChar)->ignore
        it2.contents = it2.contents + 1
      }

      str
    }
  }

  let decode: array<Base.digit> => Uint8Array.t = code => {
    if code->Belt.Array.length == 0 {
      Uint8Array.fromLength(0)
    } else {
      let psz = ref(0)
      let zeroes = ref(0)
      let length = ref(0)
      while code->Array.unsafe_get(psz.contents) == leader {
        zeroes.contents = zeroes.contents + 1
        psz.contents = psz.contents + 1
      }

      let size =
        ((code->Belt.Array.length - psz.contents)->Int.toFloat *. factor +. 1.)->Math.floor_int
      let b256 = Uint8Array.fromLength(size)
      while code->Belt.Array.get(psz.contents)->Belt.Option.isSome {
        let digit = code->Js.Array2.unsafe_get(psz.contents)
        let digitCode = baseMap->Belt.HashMap.get(digit)
        if digitCode->Belt.Option.isNone {
          raise(InvalidDigit(digit))
        }

        let carry = ref(digitCode->Belt.Option.getExn)
        let i = ref(0)
        let it3 = ref(size - 1)
        while (carry.contents != 0 || i.contents < length.contents) && it3.contents != -1 {
          carry.contents = carry.contents + baseSize * b256->Uint8Array.unsafe_get(it3.contents)
          b256->Uint8Array.unsafe_set(it3.contents, mod(carry.contents, 256))
          carry.contents = carry.contents / 256

          it3.contents = it3.contents - 1
          i.contents = i.contents + 1
        }

        if carry.contents != 0 {
          raise(NonZeroCarry)
        }
        length.contents = i.contents
        psz.contents = psz.contents + 1
      }

      let it4 = ref(size - length.contents)
      while it4.contents != size && b256->Uint8Array.unsafe_get(it4.contents) == 0 {
        it4.contents = it4.contents + 1
      }

      let vch = Uint8Array.fromLength(zeroes.contents + (size - it4.contents))
      vch->Uint8Array.fillRangeInPlace(0, ~start=0, ~end_=zeroes.contents)->ignore
      let j = ref(zeroes.contents)
      while it4.contents != size {
        vch->Uint8Array.unsafe_set(j.contents, b256->Uint8Array.unsafe_get(it4.contents))
        j.contents = j.contents + 1
        it4.contents = it4.contents + 1
      }

      vch
    }
  }
}
