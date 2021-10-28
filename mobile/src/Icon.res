module Feather = {
  @react.component @module("@expo/vector-icons")
  external make: (
    ~name: string,
    ~size: ReactNative.Style.size=?,
    ~style: ReactNative.Style.t=?,
    ~color: ReactNative.Color.t=?,
  ) => React.element = "Feather"
}
