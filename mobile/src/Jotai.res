module Atom = {
  module Permissions = {
    type w = [#writable]
    type r = [#readable]
    type rw = [r | w]
  }
  type atom<'value, 'setValue, 'permissions> constraint 'permissions = [< Permissions.rw]
  type t<'value, 'setValue, 'permissions> = atom<'value, 'setValue, 'permissions>

  @module("jotai") external make: 'value => t<'value, 'value => 'value, Permissions.rw> = "atom"

  type getter
  let get = (type value, get: getter, atom: t<value, 'value, [> Permissions.r]>): value =>
    Obj.magic(get, atom)

  type void
  @module("jotai")
  external makeDerived: (getter => 'derivedValue) => t<'derivedValue, void, Permissions.r> = "atom"

  @module("jotai")
  external makeAsyncDerived: (getter => Js.Promise.t<'derivedValue>) => t<
    'derivedValue,
    void,
    Permissions.r,
  > = "atom"

  type setter

  let set = (
    type value,
    set: setter,
    atom: t<value, 'arg, [> Permissions.w]>,
    newValue: value,
  ): unit => Obj.magic(set, atom, newValue)

  @module("jotai")
  external makeWritableDerived: (
    getter => 'derivedValue,
    (getter, setter, 'arg) => unit,
  ) => t<'derivedValue, 'arg, Permissions.rw> = "atom"

  module Family = {
    type t<'param, 'value, 'setValue, 'permission> = 'param => atom<'value, 'setValue, 'permission>

    @module("jotai/utils")
    external make: (
      'param => atom<'value, 'setValue, 'permission>,
      ('param, 'param) => bool,
    ) => t<'param, 'value, 'setValue, 'permission> = "atomFamily"
  }
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
  external use: Atom.t<'value, 'setValue, Atom.Permissions.rw> => ('value, 'setValue => unit) =
    "useAtom"

  @module("jotai")
  external useReadableInternal: Atom.t<'value, 'setValue, [> Atom.Permissions.r]> => (
    'value,
    Atom.void,
  ) = "useAtom"

  @module("jotai")
  external useWritableInternal: Atom.t<'value, 'setValue, [> Atom.Permissions.w]> => (
    Atom.void,
    'setValue => unit,
  ) = "useAtom"

  let useReadable = atom => {
    let (value, _: Atom.void) = useReadableInternal(atom)
    value
  }

  let useWritable = atom => {
    let (_: Atom.void, setValue) = useWritableInternal(atom)
    setValue
  }
}
