open ReactNative

@react.component
let make = () => <>
  <Recoil.RecoilRoot>
    <StatusBar barStyle=#lightContent />
    <ReactNativeSafeAreaContext.SafeAreaProvider>
      <AppLoader> <Authentication> <ConversationScreen /> </Authentication> </AppLoader>
    </ReactNativeSafeAreaContext.SafeAreaProvider>
  </Recoil.RecoilRoot>
</>
