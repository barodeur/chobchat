open ReactNative

@react.component
let make = () => {
  MatrixState.useSync()->ignore

  <RootStack.Navigator
    screenOptions={_ => RootStack.options(~cardStyle=Style.viewStyle(~flex=1., ()), ())}>
    <RootStack.Screen
      name="HomeTabs"
      component=HomeTabsNavigator.make
      options={_ => RootStack.options(~headerShown=false, ())}
    />
    <RootStack.Screen name="Conversation" component=ConversationScreen.make />
  </RootStack.Navigator>
}
