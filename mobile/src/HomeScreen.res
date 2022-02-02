open ReactNative

module ConversationsScreen = {
  module StakeParams = {
    type params = Matrix.RoomId.t
  }
  include ReactNavigation.Stack.Make(StakeParams)

  let rooms: Jotai.Atom.t<_, Jotai.Atom.Actions.set<unit>, _> = Jotai.Atom.makeComputed(({get}) => {
    get(MatrixState.joinedRooms)
    ->Js.Dict.entries
    ->Js.Array2.map(((roomId, _)) => {
      get(MatrixState.rooms(roomId->Matrix.RoomId.fromString))
    })
  })

  @react.component
  let make = (~navigation, ~route as _) => {
    let rooms = Jotai.React.useAtomValue(rooms)
    let currentUserId =
      Jotai.React.useAtomValue(Authentication.currentUserId)->Belt.Result.getExn->Belt.Option.getExn

    <View>
      {rooms
      ->Js.Array2.map(room => {
        <ListButton
          key={room.id->Matrix.RoomId.toString}
          title={room.name->Belt.Option.getWithDefault(
            room.members
            ->Js.Dict.entries
            ->Js.Array2.filter(((userId, _)) => currentUserId->Matrix.UserId.toString != userId)
            ->Belt.Array.get(0)
            ->Option.map(((userId, _)) => userId)
            ->Option.getWithDefault(room.id->Matrix.RoomId.toString),
          )}
          onPress={_ =>
            navigation->RootStack.Navigation.navigateByName(
              ~name="Conversation",
              ~params={roomId: room.id},
            )}
        />
      })
      ->React.array}
    </View>
  }
}

module HomeTabsScreen = {
  type tabParams = unit
  include ReactNavigation.BottomTabs.Make({
    type params = tabParams
  })

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
            ->Js.Array2.mapi((key, idx) => {
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
        component=ConversationsScreen.make
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
}

@react.component
let make = () => {
  MatrixState.useSync()->ignore

  <RootStack.Navigator
    screenOptions={_ => RootStack.options(~cardStyle=Style.viewStyle(~flex=1., ()), ())}>
    <RootStack.Screen
      name="HomeTabs"
      component=HomeTabsScreen.make
      options={_ => RootStack.options(~headerShown=false, ())}
    />
    <RootStack.Screen name="Conversation" component=ConversationScreen.make />
  </RootStack.Navigator>
}
