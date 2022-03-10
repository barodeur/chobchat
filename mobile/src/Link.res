open ReactNative

let openURL = url =>
  switch PlatformX.platform {
  | Web(Electron) => ElectronRendererIPC.sendSync(OpenExternal(url))->ignore
  | _ => ExpoLinking.openURL(url)
  }

@react.component
let make = (~href, ~children, ~textStyle=?, ()) => {
  let handlePress = React.useCallback1(e => {
    e->ReactNative.Event.PressEvent.preventDefault
    openURL(href)
  }, [href])

  <TouchableOpacity onPress=handlePress>
    {
      let style = textStyle
      <TextX accessibilityRole=#link href ?style> {children} </TextX>
    }
  </TouchableOpacity>
}
