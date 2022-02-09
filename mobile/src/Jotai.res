module Atom = {
  module Tags = {
    type w = [#writable]
    type r = [#readable]
    type p = [#primitive]
    type re = [#resettable]
    type all = [r | w | p | re]
  }

  module Actions = {
    type t<'action>
    type set<'value> = t<('value => 'value) => unit>
    type update<'value> = t<'value => unit>
    type dispatch<'action> = t<'action => unit>
  }

  type atom<'value, 'action, 'tags>
    constraint 'tags = [< Tags.all] constraint 'action = Actions.t<'setValue>
  type t<'value, 'action, 'tags> = atom<'value, 'action, 'tags>
    constraint 'tags = [< Tags.all] constraint 'action = Actions.t<'setValue>

  type void // used for readonly atoms without setter

  type set<'value, 'action, 'tags> = t<'value, 'action, 'tags> constraint 'tags = [> Tags.w]

  type get<'value, 'action, 'tags> = t<'value, 'action, 'tags> constraint 'tags = [> Tags.r]

  type getter = {get: 'value 'action 'tags. get<'value, Actions.t<'action>, 'tags> => 'value}
  type setter = {
    get: 'value 'action 'tags. get<'value, Actions.t<'action>, 'tags> => 'value,
    set: 'value 'setValue 'action 'tags. (
      set<'value, Actions.t<'action>, 'tags>,
      'setValue,
    ) => unit,
  }

  type getValue<'value> = getter => 'value
  type getValueAsync<'value> = getter => Js.Promise.t<'value>
  type setValue<'args> = (setter, 'args) => unit
  type setValueAsync<'args> = (setter, 'args) => Js.Promise.t<unit>

  @module("jotai")
  external make: 'value => t<'value, Actions.set<'value>, [Tags.r | Tags.w | Tags.p]> = "atom"

  @module("./jotai_wrapper")
  external makeComputed: getValue<'value> => t<'value, _, [Tags.r]> = "atomWrapped"
  @module("./jotai_wrapper")
  external makeComputedAsync: getValueAsync<'value> => t<'value, _, [Tags.r]> = "atomWrapped"

  @module("./jotai_wrapper")
  external makeWritableComputed: (
    getValue<'value>,
    setValue<'args>,
  ) => t<'value, Actions.update<'args>, [Tags.r | Tags.w]> = "atomWrapped"

  module Family = {
    type t<'param, 'value, 'action, 'tags> = 'param => atom<'value, 'action, 'tags>

    @module("jotai/utils")
    external make: (
      'param => atom<'value, 'action, 'permission>,
      ('param, 'param) => bool,
    ) => t<'param, 'value, 'action, 'permission> = "atomFamily"
  }

  @module("jotai/utils")
  external waitForAll: array<t<'value, _, _>> => t<array<'value>, _, _> = "waitForAll"

  @module("jotai/utils")
  external waitForAll2: (t<'a, _, _>, t<'b, _, _>) => t<('a, 'b), _, _> = "waitForAll"

  @module("jotai/utils")
  external waitForAll3: (t<'a, _, _>, t<'b, _, _>, t<'c, _, _>) => t<('a, 'b, 'c), _, _> =
    "waitForAll"
}

module React = {
  module Provider = {
    module InitialValues = {
      type t

      external make0: unit => t = "[]"
      external make1: array<(Atom.t<'v, _, _>, 'v)> => t = "%identity"
      external make2: (((Atom.t<'v1, _, _>, 'v1), (Atom.t<'v2, _, _>, 'v2))) => t = "%identity"
      external make3: (
        ((Atom.t<'v1, _, _>, 'v1), (Atom.t<'v2, _, _>, 'v2), (Atom.t<'v3, _, _>, 'v3))
      ) => t = "%identity"
    }

    @react.component @module("jotai")
    external make: (~initialValues: InitialValues.t=?, ~children: React.element) => React.element =
      "Provider"
  }

  @module("jotai")
  external use: Atom.t<'value, Atom.Actions.t<'action>, [> Atom.Tags.r | Atom.Tags.w]> => (
    'value,
    'action,
  ) = "useAtom"

  @module("jotai/utils")
  external useUpdateAtom: Atom.t<'value, Atom.Actions.t<'action>, [> Atom.Tags.w]> => 'action =
    "useUpdateAtom"

  @module("jotai/utils")
  external useAtomValue: Atom.t<'value, _, [> Atom.Tags.r]> => 'value = "useAtomValue"

  type callbackWithSetter<'args, 'result> = (Atom.setter, 'args) => 'result
  type callbackAsync<'args, 'result> = 'args => Js.Promise.t<'result>

  @module("./jotai_wrapper")
  external useAtomCallback: callbackWithSetter<'args, 'result> => callbackAsync<'args, 'result> =
    "useAtomCallback"
}
