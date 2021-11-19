open ReactNative

@react.component
let make = (~config=?, ()) =>
  <Recoil.RecoilRoot
    initializeState={({set}) => Config.recoilAtom->set(config->Option.or(Config.initialConfig))}>
    <StatusBar barStyle=#lightContent />
    <ReactNativeSafeAreaContext.SafeAreaProvider>
      <AppLoader> <Authentication> <ConversationScreen /> </Authentication> </AppLoader>
    </ReactNativeSafeAreaContext.SafeAreaProvider>
  </Recoil.RecoilRoot>
