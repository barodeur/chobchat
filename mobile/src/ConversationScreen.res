open ReactNative
open Style

type variant = Sent | Received

type message = {
  id: string,
  body: string,
  sender: string,
  variant: variant,
  age: Duration.t,
}

type err = AuthError(Authentication.err) | StateError(State.err)

module Message = {
  @react.component
  let make = (~text, ~sender, ~variant, ~age) =>
    <View
      style={viewStyle(
        ~paddingVertical=8.->dp,
        ~paddingHorizontal=10.->dp,
        ~alignItems=switch variant {
        | Sent => #flexEnd
        | Received => #flexStart
        },
        (),
      )}>
      {variant == Received
        ? <TextX style={Style.textStyle(~color="#00000060", ())}> {sender->React.string} </TextX>
        : React.null}
      <View
        style={viewStyle(
          ~borderRadius=10.,
          ~paddingVertical=10.->dp,
          ~paddingHorizontal=18.->dp,
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
      <Duration
        duration=age
        style={Style.textStyle(~color="#00000060", ~fontSize=12., ~marginTop=2.->Style.dp, ())}
      />
    </View>
}

let inverted = switch PlatformX.platform {
| Mobile(_) => true
| _ => false
}

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
          opt
          ->Belt.Array.keepMap(({id, sender, content, unsigned: {age}}) =>
            switch (content, age) {
            | (RoomMessage(Text({body})), Some(age)) =>
              Some({
                variant: sender == userId ? Sent : Received,
                id: id,
                body: body,
                sender: sender,
                age: age,
              })
            | _ => None
            }
          )
          ->(inverted ? Belt.Array.reverse : arr => arr)
        )
      })
    )
  }, (currentUserId, events))

  React.useEffect1(() => {
    switch listRef.current->Js.Nullable.toOption {
    | None => ()
    | Some(ref) => Timeout.set(() => {
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

  let (_, setSessionCounter) = Recoil.useRecoilState(State.sessionCounterState)
  let (_, setLoginToken) = Recoil.useRecoilState(State.loginTokenState)

  let handleLogoutPress = React.useCallback2(_ => {
    if Confirm.confirm(`Es-tu sûr ?`) {
      CrossSecureStore.removeItem("accessToken")
      ->Promise.thenResolve(res => {
        if res->Result.isOk {
          setLoginToken(_ => None)
          setSessionCounter(v => v + 1)
        }
      })
      ->ignore
    }
  }, (setLoginToken, setSessionCounter))

  syncRes->Result.mapWithDefault(
    <Text> {"Impossible de synchroniser les messages"->React.string} </Text>,
    _ =>
      <View style={viewStyle(~flex=1., ~backgroundColor=Colors.green, ())}>
        <ReactNativeSafeAreaContext.SafeAreaView
          edges=[#top] style={viewStyle(~paddingBottom=5.->dp, ~flexDirection=#row, ())}>
          <View style={viewStyle(~flex=1., ())} />
          <TextX
            style={textStyle(
              ~flex=1.,
              ~marginVertical=10.->Style.dp,
              ~color=Color.white,
              ~textAlign=#center,
              ~fontSize=24.,
              ~fontFamily="Sniglet",
              (),
            )}>
            {"ChobChat"->React.string}
          </TextX>
          <View
            style={viewStyle(
              ~flex=1.,
              ~alignItems=#flexEnd,
              ~justifyContent=#center,
              ~paddingRight=10.->Style.dp,
              (),
            )}>
            <TouchableOpacity onPress={handleLogoutPress}>
              <TextX style={textStyle()}> {"Logout"->React.string} </TextX>
            </TouchableOpacity>
          </View>
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
                renderItem={({item: {variant, body, sender, age}}) =>
                  <Message variant sender text=body age />}
                keyExtractor={({id}, _) => id}
                inverted
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
