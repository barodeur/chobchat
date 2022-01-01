module Web = {
  @val external confirm_: string => bool = "confirm"

  let confirm = (title, onOkPress) => {
    if confirm_(title) {
      onOkPress()
    }
  }
}

module Mobile = {
  open ReactNative

  let confirm = (title, onOkPress) =>
    Alert.alert(
      ~title,
      ~buttons=[Alert.button(~text="Cancel", ()), Alert.button(~text="Ok", ~onPress=onOkPress, ())],
      (),
    )
}

let confirm = switch PlatformX.platform {
| Web(_) => Web.confirm
| Mobile(_) => Mobile.confirm
| _ => (_, _) => ()
}
