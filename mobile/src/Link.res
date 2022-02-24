open ReactNative

@react.component
let make = (~href, ~children, ~textStyle=?, ()) => {
  let handlePress = React.useCallback1(_ => {
    switch PlatformX.platform {
    | Mobile(_) => Linking.openURL(href)->ignore
    | _ => ()
    }
  }, [href])

  <TouchableOpacity onPress=handlePress>
    {
      let style = textStyle
      <TextX accessibilityRole=#link href ?style> {children} </TextX>
    }
  </TouchableOpacity>
}
