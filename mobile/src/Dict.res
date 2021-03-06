type t<'a> = Js.Dict.t<'a>

let add = (dict, key, value) =>
  dict->Js.Dict.entries->ArrayX.concat([(key, value)])->Js.Dict.fromArray
let has = (dict, key) => dict->Js.Dict.get(key)->Belt.Option.isSome
let remove = (dict, key) =>
  dict->Js.Dict.entries->ArrayX.filter(((k, _)) => key != k)->Js.Dict.fromArray
