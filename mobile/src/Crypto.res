type webcrypto = {getRandomValues: (. Js.TypedArray2.Uint8Array.t) => unit}

module Web = {
  @val external crypto: webcrypto = "crypto"
}

module Mobile = {
  @module("expo-standard-web-crypto") @val external crypto: webcrypto = "default"
}

let getRandomValues = switch PlatformX.currentAdapter {
| Web =>
  (. array) => {
    Web.crypto.getRandomValues(. array)
  }
| Mobile => (. array) => Mobile.crypto.getRandomValues(. array)
| _ => (. _) => ()
}

let generateRandomBase58 = bytes => {
  let array = Js.TypedArray2.Uint8Array.fromLength(bytes)
  getRandomValues(. array)
  array->Base58.encode->Js.Array2.map(String.make(1, _))->Js.Array2.joinWith("")
}
