open ReactNative
open Style

type err = AuthError(Authentication.err) | NotAuthenticated

let inverted = switch PlatformX.platform {
| Mobile(_) => true
| _ => false
}

@react.component
let make = (~navigation as _, ~route: RootStack.route) => {
  let roomId = route.params->Option.map(params => params.roomId)->Option.getExn // Get roomId from navigation state
  let eventIds = Jotai.React.useAtomValue(MatrixState.roomEventIds(roomId))->Ok
  let matrixClient = Jotai.React.useAtomValue(Authentication.matrixClient)
  let listRef = React.useRef(Js.Nullable.null)

  React.useEffect1(() => {
    switch listRef.current->Js.Nullable.toOption {
    | None => ()
    | Some(ref) => Timeout.set(() => {
        if !inverted {
          ref->FlatList.scrollToEnd
        }
        ()
      }, 200)->ignore
    }
    None
  }, [eventIds])

  let (text, setText) = React.useState(_ => "")

  let handleSubmit = React.useCallback2(_ => {
    switch matrixClient {
    | Ok(Some(client)) =>
      client
      ->Matrix.SendMessage.send(roomId, text)
      ->Promise.thenResolve(_ => setText(_ => ""))
      ->ignore
    | _ => ()
    }
    ()
  }, (text, matrixClient))

  let markEventAsRead = Jotai.React.useAtomCallback(({get}, eventId) => {
    switch matrixClient {
    | Ok(Some(client)) =>
      if !get(MatrixState.eventIsRead(eventId)) {
        client
        ->Matrix.ReadMarker.update(
          ~roomId,
          ~inputPayload=Matrix.ReadMarker.inputPayload(~fullyRead=eventId, ~read=eventId, ()),
        )
        ->ignore
      }
    | _ => ()
    }
  })

  let handleViewableItemsChanged = React.useCallback0((
    event: VirtualizedList.viewableItemsChanged<Matrix.EventId.t>,
  ) => {
    event.viewableItems
    ->ArrayX.filter(({isViewable}) => isViewable)
    ->ArrayX.last
    ->Option.map(({item: eventId}) => markEventAsRead(eventId))
    ->ignore
  })

  let renderHeader = _ =>
    <View style={Style.viewStyle(~flex=1.0, ~alignItems=#center, ())}>
      <TextX style={Style.textStyle(~color="rgba(0, 0, 0, 0.2)", ())}>
        {roomId->Matrix.RoomId.toString->React.string}
      </TextX>
    </View>

  <View style={viewStyle(~flex=1., ~backgroundColor=Colors.green, ())}>
    <KeyboardAvoidingView
      behavior=#padding enabled={PlatformX.platform == Mobile(Ios)} style={viewStyle(~flex=1., ())}>
      {eventIds->Result.mapWithDefault(
        <TextX> {"Impossible de charger les messages"->React.string} </TextX>,
        eventIds =>
          <FlatList
            ref={Ref.value(listRef)}
            style={viewStyle(~flex=1., ~backgroundColor=Colors.grey, ())}
            _ListHeaderComponent=?{if inverted {
              None
            } else {
              Some(renderHeader)
            }}
            _ListFooterComponent=?{if inverted {
              Some(renderHeader)
            } else {
              None
            }}
            contentContainerStyle={viewStyle(~paddingVertical=10.->dp, ())}
            data={eventIds->ArrayX.reverse}
            renderItem={({item: eventId}) => <MatrixEvent eventId />}
            keyExtractor={(eventId, _) => eventId->Matrix.EventId.toString}
            inverted
            onViewableItemsChanged=handleViewableItemsChanged
          />,
      )}
      <Composer
        value={text} onValueChange={val => setText(_ => val)} onSubmit={handleSubmit} sending={true}
      />
    </KeyboardAvoidingView>
    <ReactNativeSafeAreaContext.SafeAreaView edges=[#bottom] />
  </View>
}
