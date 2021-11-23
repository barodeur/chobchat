type url = string

@module("expo-linking") external openURL: string => unit = "openURL"
@module("expo-linking") external createURL: (. string) => string = "createURL"
@return(nullable) @module("expo-linking") external useURL: unit => option<string> = "useURL"

type parseResponse = {
  path: string,
  queryParams: Js.Dict.t<string>,
}
@module("expo-linking") external parse: url => parseResponse = "parse"

module URL = {
  type t = url

  @module("expo-linking") external parse: string => t = "parse"
  @get external queryParams: t => Js.Dict.t<string> = "queryParams"
  @get external path: t => string = "path"
}
