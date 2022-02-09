open ReactNative
open HomeTabs

module TabBar = {
  @react.component
  let make = (
    ~state: ReactNavigation.Core.navigationState<tabParams>,
    ~navigation: Navigation.t,
  ) => {
    let selectedIdx = state.index
    <View style={Style.viewStyle(~backgroundColor=Colors.red, ())}>
      <ReactNativeSafeAreaContext.SafeAreaView edges=[#bottom]>
        <View style={Style.viewStyle(~flexDirection=#row, ())}>
          {["threads", "settings"]
          ->ArrayX.mapi((key, idx) => {
            let isSelected = idx == selectedIdx
            <TouchableOpacity
              key
              style={Style.viewStyle(
                ~flex=1.,
                ~alignItems=#center,
                ~paddingVertical=15.->Style.dp,
                (),
              )}
              disabled=isSelected
              onPress={_ => {
                navigation->Navigation.navigate(
                  switch key {
                  | "threads" => "Threads"
                  | "settings" => "Settings"
                  | _ => ""
                  },
                )
              }}>
              <Icon.Feather
                name={switch key {
                | "threads" => "message-circle"
                | "settings" => "settings"
                | _ => ""
                }}
                color={if isSelected {
                  Color.white
                } else {
                  "rgba(255, 255, 255, 0.5)"
                }}
                size={24.->Style.dp}
              />
            </TouchableOpacity>
          })
          ->React.array}
        </View>
      </ReactNativeSafeAreaContext.SafeAreaView>
    </View>
  }
}

@react.component
let make = (~navigation as _, ~route as _) =>
  <Navigator tabBar={props => <TabBar state={props["state"]} navigation={props["navigation"]} />}>
    <Screen
      name="Threads"
      component=HomeConversationsListScreen.make
      options={_ =>
        options(
          ~title="Conversations",
          ~tabBarIcon=({color}) =>
            <Icon.Feather name="message-square" size={32.->Style.dp} color />,
          (),
        )}
    />
    <Screen
      name="Settings"
      component=SettingsScreen.make
      options={_ =>
        options(
          ~tabBarIcon=({color}) => <Icon.Feather name="settings" size={32.->Style.dp} color />,
          (),
        )}
    />
  </Navigator>
