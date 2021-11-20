open ReactNative
open Style

type variant = Sent | Received

type message = {
  id: string,
  body: string,
  variant: variant,
}

type err = AuthError(Authentication.err) | StateError(State.err)

module Message = {
  @react.component
  let make = (~text: string, ~variant: variant) =>
    <View style={viewStyle(~paddingVertical=5.->dp, ~paddingHorizontal=10.->dp, ())}>
      <View
        style={viewStyle(
          ~alignSelf=switch variant {
          | Sent => #flexEnd
          | Received => #flexStart
          },
          ~borderRadius=10.,
          ~paddingVertical=10.->dp,
          ~paddingHorizontal=18.->dp,
          ~marginLeft=10.->dp,
          ~backgroundColor=switch variant {
          | Sent => Colors.red
          | Received => j`#DEDEDE`
          },
          (),
        )}>
        <TextX
          style={textStyle(
            ~fontFamily="Sniglet",
            ~fontSize=16.,
            ~color=switch variant {
            | Sent => Color.white
            | Received => Color.black
            },
            (),
          )}>
          {React.string(text)}
        </TextX>
      </View>
    </View>
}

@val external setTimeout: (unit => unit, int) => float = "setTimeout"

@react.component
let make = () => {
  let roomId = Recoil.useRecoilValue(State.roomId)
  let events =
    roomId
    ->Result.map(id => Recoil.useRecoilValue(State.roomEventsState(id)))
    ->Result.mapError(err => StateError(err))
  let syncRes = roomId->Result.flatMap(id => State.useSync(id))
  let currentUserId = Recoil.useRecoilValue(State.currentUserId)
  let matrixClient = Recoil.useRecoilValue(State.matrixClient)

  let listRef = React.useRef(Js.Nullable.null)

  let messages = React.useMemo2(() => {
    currentUserId
    ->Result.mapError(err => StateError(err))
    ->Result.flatMap(userIdOpt =>
      userIdOpt->Option.mapWithDefault(Error(AuthError(NotAuthenticated)), userId => {
        events->Result.map(opt =>
          opt->Belt.Array.keepMap(event =>
            switch event.content {
            | RoomMessage(Text(message)) =>
              Some({
                variant: event.sender == userId ? Sent : Received,
                id: event.id,
                body: message.body,
              })
            | _ => None
            }
          )
        )
      })
    )
  }, (currentUserId, events))

  React.useEffect1(() => {
    switch listRef.current->Js.Nullable.toOption {
    | None => ()
    | Some(ref) => setTimeout(() => {
        ref->FlatList.scrollToEnd
        ()
      }, 100)->ignore
    }
    None
  }, [messages])

  let (text, setText) = React.useState(_ => "")

  let handleSubmit = React.useCallback2(_ => {
    switch (matrixClient, roomId) {
    | (Ok(Some(client)), Ok(roomId)) =>
      client
      ->Matrix.SendMessage.send(roomId, text)
      ->Promise.thenResolve(_ => setText(_ => ""))
      ->ignore
    | _ => ()
    }
    ()
  }, (text, matrixClient))

  syncRes->Result.mapWithDefault(
    <Text> {"Impossible de synchroniser les messages"->React.string} </Text>,
    _ =>
      <View style={viewStyle(~flex=1., ~backgroundColor=Colors.green, ())}>
        <ReactNativeSafeAreaContext.SafeAreaView
          edges=[#top] style={viewStyle(~paddingBottom=5.->dp, ())}>
          <TextX
            style={textStyle(
              ~color=Color.white,
              ~textAlign=#center,
              ~fontSize=24.,
              ~fontFamily="Sniglet",
              (),
            )}>
            {"ChobChat"->React.string}
          </TextX>
        </ReactNativeSafeAreaContext.SafeAreaView>
        <KeyboardAvoidingView
          behavior=#padding
          enabled={PlatformX.platform == Mobile(Ios)}
          style={viewStyle(~flex=1., ())}>
          {messages->Result.mapWithDefault(
            <TextX> {"Impossible de charger les messages"->React.string} </TextX>,
            messages =>
              <FlatList
                ref={Ref.value(listRef)}
                style={viewStyle(~flex=1., ~backgroundColor=Colors.grey, ())}
                contentContainerStyle={viewStyle(~paddingVertical=10.->dp, ())}
                data=messages
                renderItem={({item: {variant, body}}) => <Message variant text=body />}
                keyExtractor={({id}, _) => id}
              />,
          )}
          <Composer
            value={text}
            onValueChange={val => setText(_ => val)}
            onSubmit={handleSubmit}
            sending={true}
          />
        </KeyboardAvoidingView>
        <ReactNativeSafeAreaContext.SafeAreaView edges=[#bottom] />
      </View>,
  )
}
