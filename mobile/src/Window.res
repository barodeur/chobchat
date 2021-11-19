type t
let window: option<t> =
  %raw(`typeof window === "undefined" ? undefined : window`)->Js.Undefined.toOption
