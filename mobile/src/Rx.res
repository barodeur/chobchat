type connectable = Connectable
type notConnectable = NotConnectable

type observable<'a, 'connectable>
type notConnectableObservable<'a> = observable<'a, notConnectable>
type connectableObservable<'a> = observable<'a, connectable>
type subscriber<'a>
type operator<'a, 'b, 'aMode, 'bMode> = observable<'a, 'aMode> => observable<'b, 'bMode>
@deriving(abstract)
type observer<'a> = {
  @optional next: 'a => unit,
  @optional error: exn => unit,
  @optional complete: unit => unit,
}
type subscription

module Observer = {
  let make = observer
}

module Subscriber = {
  @send external next: (subscriber<'a>, 'a) => unit = "next"
  @send external complete: (subscriber<'a>, unit) => unit = "complete"
}

module Subscription = {
  @send external unsubscribe: subscription => unit = "unsubscribe"
}

module Observable = {
  @new @module("rxjs")
  external make: (subscriber<'a> => option<unit => unit>) => notConnectableObservable<'a> =
    "Observable"
  @module("rxjs") @variadic external of_: array<'a> => notConnectableObservable<'a> = "of"
  @module("rxjs") external range: int => notConnectableObservable<'int> = "range"
  @send external subscribe: (observable<'a, _>, observer<'a>) => subscription = "subscribe"
  @send
  external pipe: (
    observable<'a, 'mode>,
    operator<'a, 'b, 'aMode, 'bMode>,
  ) => observable<'b, notConnectable> = "pipe"
}

module Subject = {
  type t<'a>

  @new @module("rxjs") external make: unit => t<'a> = "Subject"
}

module Operator = {
  @module("rxjs")
  external pipe: (
    operator<'a, 'b, 'aMode, 'bMode>,
    operator<'b, 'c, 'bMode, 'cMode>,
  ) => operator<'a, 'c, 'aMode, notConnectable> = "pipe"
  @module("rxjs/operators")
  external filter: ('a => bool) => operator<'a, 'a, 'aMode, 'aMode> = "filter"
  @module("rxjs/operators") external map: ('a => 'b) => operator<'a, 'b, 'aMode, 'bMode> = "map"
  @module("rxjs/operators") external first: ('a => 'a) => operator<'a, 'a, 'aMode, 'aMode> = "first"
  @module("rxjs/operators")
  external concatAll: unit => operator<observable<'a, 'mode>, 'a, 'mode, 'mode> = "concatAll"
  @module("rxjs/operators")
  external share: unit => operator<'a, 'a, 'aMode, 'aMode> = "share"
}
