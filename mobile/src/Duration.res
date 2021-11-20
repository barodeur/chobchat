type t = Ms(int)

let ms: int => t = ms => Ms(ms)
let s: int => t = x => ms(x * 1000)
let m: int => t = x => s(x * 60)
let h: int => t = x => m(x * 60)
let d: int => t = x => h(x * 24)

let toMsInt = duration =>
  switch duration {
  | Ms(ms) => ms
  }

let codec = Jzon.custom(
  (Ms(durationMs)) => durationMs->Belt.Int.toFloat->Js.Json.number,
  json =>
    json
    ->Js.Json.decodeNumber
    ->Option.mapWithDefault(Error(#UnexpectedJsonType([], "number", json)), number =>
      number->Belt.Float.toInt->Ms->Ok
    ),
)

@react.component
let make = (~duration, ~style=?) =>
  <TextX ?style>
    {switch duration {
    | Ms(ms) if ms < 30 * 1000 => "à l'instant"
    | Ms(ms) if ms < 1000 * 60 * 60 => `il y a ${(ms / (1000 * 60) + 1)->Belt.Int.toString} minutes`
    | Ms(ms) if ms < 1000 * 60 * 60 * 24 =>
      `il y a ${(ms / (1000 * 60 * 60))->Belt.Int.toString} heures`
    | Ms(ms) => (Js.Date.now() -. ms->Belt.Int.toFloat)->Js.Date.fromFloat->Js.Date.toLocaleString
    }->React.string}
  </TextX>
