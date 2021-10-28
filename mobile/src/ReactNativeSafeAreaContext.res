type edge = [#top | #right | #bottom | #left]

module SafeAreaProvider = {
  @react.component @module("react-native-safe-area-context")
  external make: (~children: React.element=?) => React.element = "SafeAreaProvider"
}

module SafeAreaView = {
  @react.component @module("react-native-safe-area-context")
  external make: (
    ~children: React.element=?,
    ~style: ReactNative.Style.t=?,
    ~edges: array<edge>=?,
  ) => React.element = "SafeAreaView"
}
