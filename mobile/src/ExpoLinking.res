// module Mobile = {
@module("expo-linking") external openURL: string => unit = "openURL"
@module("expo-linking") external createURL: (. string) => string = "createURL"
@module("expo-linking") @return(nullable) external useURL: unit => option<string> = "useURL"

module URL = {
  type t

  @module("expo-linking") external parse: string => t = "parse"
  @get external queryParams: t => Js.Json.t = "queryParams"
  @get external path: t => string = "path"
}
