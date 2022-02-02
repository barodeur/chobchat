open ReactNative

@react.component
let make = (~config=?, ()) =>
  <ReactNavigation.Native.NavigationContainer>
    <ReactNativeSafeAreaContext.SafeAreaProvider>
      <Jotai.React.Provider
        initialValues={Jotai.React.Provider.InitialValues.make1(
          config->Belt.Option.mapWithDefault([], _ => [(Config.jotaiAtom, config)]),
        )}>
        <StatusBar barStyle=#lightContent />
        <AppLoader> <Authentication> <HomeScreen /> </Authentication> </AppLoader>
      </Jotai.React.Provider>
    </ReactNativeSafeAreaContext.SafeAreaProvider>
  </ReactNavigation.Native.NavigationContainer>
