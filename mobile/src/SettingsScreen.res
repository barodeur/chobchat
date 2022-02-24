open ReactNative

@react.component
let make = (~navigation as _, ~route as _) => {
  let setSessionCounter = Jotai.React.useUpdateAtom(Authentication.sessionCounterState)
  let setLoginToken = Jotai.React.useUpdateAtom(Authentication.loginTokenState)

  let handleLogoutPress = React.useCallback2(_ => {
    Confirm.confirm(`Es-tu sûr ?`, () => {
      CrossSecureStore.removeItem("accessToken")
      ->Promise.thenResolve(res => {
        if res->Result.isOk {
          setLoginToken(_ => None)
          setSessionCounter(v => v + 1)
        }
      })
      ->ignore
    })
  }, (setLoginToken, setSessionCounter))

  <View>
    <ListButton
      title="Se deconnecter"
      onPress=handleLogoutPress
      color=Colors.red
      iconComponent={props =>
        <Icon.Feather name="power" color={props["color"]} size={16.->Style.dp} />}
    />
    <View style={Style.viewStyle(~marginTop=10.->Style.dp, ~alignItems=#center, ())}>
      <Version color="rgba(255, 255, 255, 0.2)" />
    </View>
  </View>
}
