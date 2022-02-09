type err = StorageError(CrossSecureStore.err)

let generateId = () => {
  let array = Js.TypedArray2.Uint8Array.fromLength(16)
  Crypto.getRandomValues(. array)
  let randomPart = array->Base58.encode->ArrayX.map(String.make(1, _))->ArrayX.joinWith("")
  `dev_${randomPart}`
}

let deviceId: Jotai.Atom.t<_, Jotai.Atom.Actions.set<string>, _> = Jotai.Atom.makeComputedAsync(_ =>
  CrossSecureStore.getItem("deviceId")
  ->PResult.map(deviceIdOpt => deviceIdOpt->Belt.Option.getWithDefault(generateId()))
  ->PResult.flatMap(deviceId =>
    CrossSecureStore.setItem("deviceId", deviceId)->Promise.thenResolve(_ => Ok(deviceId))
  )
  ->PResult.mapError(err => StorageError(err))
)
