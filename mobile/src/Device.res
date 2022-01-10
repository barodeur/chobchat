type err = StorageError(CrossSecureStore.err)

let generateId = () => {
  let array = Js.TypedArray2.Uint8Array.fromLength(16)
  Crypto.getRandomValues(. array)
  let randomPart = array->Base58.encode->Js.Array2.map(String.make(1, _))->Js.Array2.joinWith("")
  `dev_${randomPart}`
}

let deviceId = Jotai.Atom.makeAsyncDerived(_ =>
  CrossSecureStore.getItem("deviceId")
  ->PResult.map(deviceIdOpt => deviceIdOpt->Belt.Option.getWithDefault(generateId()))
  ->PResult.flatMap(deviceId =>
    CrossSecureStore.setItem("deviceId", deviceId)->Promise.thenResolve(_ => Ok(deviceId))
  )
  ->PResult.mapError(err => StorageError(err))
)
