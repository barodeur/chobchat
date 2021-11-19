@module("@react-spring/native")
external animated: React.componentLike<'props, 'return> => React.componentLike<'props, 'return> =
  "animated"

type springValue<'a>
type interpolationConfig = {
  range: array<float>,
  output: array<float>,
}

@deriving(abstract)
type config = {
  @optional mass: int,
  @optional tension: int,
  @optional friction: int,
  @optional clamp: bool,
  @optional precision: float,
  @optional velocity: int,
}

module Config = {
  type t = config
  @module("@react-spring/native") @scope("config") @val external default: t = "default"
  @module("@react-spring/native") @scope("config") @val external gentle: t = "gentle"
  @module("@react-spring/native") @scope("config") @val external wobbly: t = "wobbly"
  @module("@react-spring/native") @scope("config") @val external stiff: t = "stiff"
  @module("@react-spring/native") @scope("config") @val external slow: t = "slow"
  @module("@react-spring/native") @scope("config") @val external molasses: t = "molasses"
}

@send external to_: (springValue<'a>, interpolationConfig) => 'a = "to"
@send external val: springValue<'a> => 'a = "%identity"

@deriving(abstract)
type transition1Style<'a> = {a: 'a}
type transition1StyleA<'a> = {a: springValue<'a>}

@deriving(abstract)
type transition1Config<'a> = {
  from: transition1Style<'a>,
  enter: transition1Style<'a>,
  leave: transition1Style<'a>,
  @optional config: config,
}

@module("@react-spring/native")
external useTransition1: (
  . array<'item>,
  transition1Config<'a>,
  . (transition1StyleA<'a>, 'item) => React.element,
) => array<React.element> = "useTransition"

@deriving(abstract)
type transition2Style<'a, 'b> = {
  a: 'a,
  b: 'b,
}
type transition2StyleA<'a, 'b> = {
  a: springValue<'a>,
  b: springValue<'b>,
}

@deriving(abstract)
type transition2Config<'a, 'b> = {
  from: transition2Style<'a, 'b>,
  enter: transition2Style<'a, 'b>,
  leave: transition2Style<'a, 'b>,
  @optional config: config,
}

@module("@react-spring/native")
external useTransition2: (
  . array<'item>,
  transition2Config<'a, 'b>,
  . (transition2StyleA<'a, 'b>, 'item) => React.element,
) => array<React.element> = "useTransition"

@deriving(abstract)
type transition3Style<'a, 'b, 'c> = {
  a: 'a,
  b: 'b,
  c: 'c,
}
type transition3StyleA<'a, 'b, 'c> = {
  a: springValue<'a>,
  b: springValue<'b>,
  c: springValue<'c>,
}

@deriving(abstract)
type transition3Config<'a, 'b, 'c> = {
  from: transition3Style<'a, 'b, 'c>,
  enter: transition3Style<'a, 'b, 'c>,
  leave: transition3Style<'a, 'b, 'c>,
  @optional config: config,
}

@module("@react-spring/native")
external useTransition3: (
  . array<'item>,
  transition3Config<'a, 'b, 'c>,
  . (transition3StyleA<'a, 'b, 'c>, 'item) => React.element,
) => array<React.element> = "useTransition"

module View = {
  let makeProps = ReactNative.View.makeProps
  let make = animated(ReactNative.View.make)
}
