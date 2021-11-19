module Router = {
  type t
  type query = Js.Json.t

  @module("next/router") external useRouter: unit => t = "useRouter"
  @send external replace: (t, string) => unit = "replace"

  @get external getQuery: t => query = "query"
}
