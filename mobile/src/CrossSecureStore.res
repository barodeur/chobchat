module Mobile = {
  // @module("expo-secure-store")
  @module("@react-native-async-storage/async-storage") @scope("default")
  external getItem: (. string) => Promise.t<Js.Null.t<string>> = "getItem"

  // @module("expo-secure-store")
  @module("@react-native-async-storage/async-storage") @scope("default")
  external setItem: (. string, string) => Promise.t<unit> = "setItem"
}

module Web = {
  type localStorage
  @get external getLocalStorage: Window.t => localStorage = "localStorage"

  let localStorage = Window.window->Belt.Option.map(getLocalStorage)

  @send external getItem: (localStorage, string) => Js.Null.t<string> = "getItem"
  @send external setItem: (localStorage, string, string) => unit = "setItem"
}

type err = Exn(exn) | MissingLocalStorage | Unknown

let getItem = {
  switch PlatformX.currentAdapter {
  | Web =>
    key =>
      Web.localStorage
      ->Belt.Option.map(storage => storage->Web.getItem(key)->Js.Null.toOption)
      ->Belt.Option.mapWithDefault(Ok(None), Result.ok)
      ->Promise.resolve
      ->PResult.mapError(err => Exn(err))
  | Mobile =>
    key =>
      Mobile.getItem(. key)
      ->PResult.result
      ->PResult.map(Js.Null.toOption)
      ->PResult.mapError(err => Exn(err))
  | _ => _key => Promise.resolve(Ok(None))
  }
}

let setItem = {
  switch PlatformX.currentAdapter {
  | Web =>
    (key, value) =>
      Web.localStorage
      ->Belt.Option.mapWithDefault(Error(MissingLocalStorage), Result.ok)
      ->Result.map(Web.setItem(_, key, value))
      ->Promise.resolve
  | Mobile => (key, value) => Mobile.setItem(. key, value)->Promise.thenResolve(Result.ok)
  | _ => (_key, _value) => Promise.resolve(Ok())
  }
}
