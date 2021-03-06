type webcrypto = {getRandomValues: (. Js.TypedArray2.Uint8Array.t) => unit}

module Web = {
  @val external crypto: webcrypto = "crypto"
}

module Mobile = {
  @module("expo-standard-web-crypto") @val external crypto: webcrypto = "default"
}

let getRandomValues = switch PlatformX.platform {
| Web(_) =>
  (. array) => {
    Web.crypto.getRandomValues(. array)
  }
| Mobile(_) => (. array) => Mobile.crypto.getRandomValues(. array)
| _ => (. _) => ()
}

let generateRandomBase58 = bytes => {
  let array = Js.TypedArray2.Uint8Array.fromLength(bytes)
  getRandomValues(. array)
  array->Base58.encode->ArrayX.map(String.make(1, _))->ArrayX.joinWith("")
}
