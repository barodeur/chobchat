open ReactNative

module ConversationButton = {
  @react.component
  let make = (~roomId, ~onPress) => {
    let title = Jotai.React.useAtomValue(MatrixState.roomTitle(roomId))

    <ListButton title onPress />
  }
}

@react.component
let make = (~navigation, ~route as _) => {
  let roomIds = Jotai.React.useAtomValue(MatrixState.roomIdsBylastEventOriginServerTsDesc)

  <FlatList
    data=roomIds
    keyExtractor={(roomId, _) => roomId->Matrix.RoomId.toString}
    renderItem={({item: roomId}) =>
      <ConversationButton
        roomId
        onPress={_ =>
          navigation->RootStack.Navigation.navigateByName(
            ~name="Conversation",
            ~params={roomId: roomId},
          )}
      />}
  />
}
