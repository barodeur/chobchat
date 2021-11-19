open ReactNative

module Web = {
  @react.component
  let make = () =>
    <View
      style={
        open Style
        viewStyle(~backgroundColor=Colors.green, ~flex=1., ~justifyContent=#center, ())
      }
    />
}

@react.component
let make = () =>
  switch PlatformX.currentAdapter {
  | _ => <Web />
  }
