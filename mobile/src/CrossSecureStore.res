module Mobile = {
  @module("@react-native-async-storage/async-storage") @scope("default")
  external getItem: (. string) => Promise.t<Js.Null.t<string>> = "getItem"

  @module("@react-native-async-storage/async-storage") @scope("default")
  external setItem: (. string, string) => Promise.t<unit> = "setItem"

  @module("@react-native-async-storage/async-storage") @scope("default")
  external removeItem: (. string) => Promise.t<unit> = "removeItem"
}

module Web = {
  type localStorage
  @get external getLocalStorage: Window.t => localStorage = "localStorage"

  let localStorage = Window.window->Belt.Option.map(getLocalStorage)

  @send external getItem: (localStorage, string) => Js.Null.t<string> = "getItem"
  @send external setItem: (localStorage, string, string) => unit = "setItem"
  @send external removeItem: (localStorage, string) => unit = "removeItem"
}

type err = Exn(exn) | MissingLocalStorage | Unknown

let getItem = {
  switch PlatformX.platform {
  | Web(_) =>
    key =>
      Web.localStorage
      ->Belt.Option.map(storage => storage->Web.getItem(key)->Js.Null.toOption)
      ->Belt.Option.mapWithDefault(Ok(None), Result.ok)
      ->Promise.resolve
      ->PResult.mapError(err => Exn(err))
  | Mobile(_) =>
    key =>
      Mobile.getItem(. key)
      ->PResult.result
      ->PResult.map(Js.Null.toOption)
      ->PResult.mapError(err => Exn(err))
  | _ => _key => Promise.resolve(Ok(None))
  }
}

let setItem = {
  switch PlatformX.platform {
  | Web(_) =>
    (key, value) =>
      Web.localStorage
      ->Belt.Option.mapWithDefault(Error(MissingLocalStorage), Result.ok)
      ->Result.map(Web.setItem(_, key, value))
      ->Promise.resolve
  | Mobile(_) => (key, value) => Mobile.setItem(. key, value)->Promise.thenResolve(Result.ok)
  | _ => (_key, _value) => Promise.resolve(Ok())
  }
}

let removeItem = {
  switch PlatformX.platform {
  | Web(_) =>
    key =>
      Web.localStorage
      ->Belt.Option.mapWithDefault(Error(MissingLocalStorage), Result.ok)
      ->Result.map(Web.removeItem(_, key))
      ->Promise.resolve
  | Mobile(_) => key => Mobile.removeItem(. key)->PResult.result->PResult.mapError(err => Exn(err))
  | _ => _ => Promise.resolve(Ok())
  }
}
