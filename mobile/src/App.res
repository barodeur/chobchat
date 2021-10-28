@react.component
let make = () => {
  <ReactNativeSafeAreaContext.SafeAreaProvider>
    <ConversationScreen />
  </ReactNativeSafeAreaContext.SafeAreaProvider>
}
