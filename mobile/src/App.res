open ReactNative

@react.component
let make = (~config=?, ()) =>
  <ReactNativeSafeAreaContext.SafeAreaProvider>
    <Jotai.React.Provider
      initialValues={Jotai.React.Provider.InitialValues.make1(
        config->Belt.Option.mapWithDefault([], _ => [(Config.jotaiAtom, config)]),
      )}>
      <StatusBar barStyle=#lightContent />
      <AppLoader> <Authentication> <ConversationScreen /> </Authentication> </AppLoader>
    </Jotai.React.Provider>
  </ReactNativeSafeAreaContext.SafeAreaProvider>
