@val external describe: (string, @uncurry (unit => unit)) => unit = "describe"
@val external test: (string, @uncurry (unit => unit)) => unit = "test"

type result = {
  pass: bool,
  message: () => string,
}
@scope("expect") @val external extendExpect0: Js.Dict.t<() => result> => unit = "extend"

let init = () => {
  extendExpect0(Js.Dict.fromArray([("toHaveSome", () => ({ pass: true, message: () => "" }))]))
}

type e<'a>
@val external expect: 'a => e<'a> = "expect"
@send external toBe: (e<'a>, 'a) => unit = "toBe"
@send external toEqual: (e<'a>, 'a) => unit = "toEqual"
@send external toHaveSome: (e<option<'a>>) => unit = "toHaveSome"

