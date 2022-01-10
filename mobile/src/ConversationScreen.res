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

type err = AuthError(Authentication.err) | NotAuthenticated

let roomEventsState = Jotai.Atom.Family.make(_ => Jotai.Atom.make([]), String.equal)
// let roomEventsState = Jotai.Atom.make([])
let syncObservable = Jotai.Atom.makeDerived(getter =>
  switch (
    getter->Jotai.Atom.get(Authentication.matrixClient),
    getter->Jotai.Atom.get(Authentication.roomId),
  ) {
  | (Ok(Some(client)), Ok(roomId)) =>
    client
    ->Matrix.createSyncAsyncIterator(
      ~filter=Matrix.Filter.t(~room=Matrix.Filter.roomFilter(~rooms=[roomId], ()), ()),
      (),
    )
    ->Some
    ->Ok
  | (Ok(None), _) => None->Ok
  | (matrixClientRes, mainRoomIdRes) =>
    StateUtils.mergeResultErrors2(matrixClientRes, mainRoomIdRes)
  }
)

let useSync = roomId => {
  let asyncIteratorRes = Jotai.React.useReadable(syncObservable)
  let setRoomEvents = Jotai.React.useWritable(roomEventsState(roomId))
  // let setRoomEvents = Jotai.React.useWritable(roomEventsState)

  React.useEffect3(() => {
    asyncIteratorRes
    ->Result.map(
      Option.flatMap(_, asyncIterator => {
        let canceledRef = ref(false)
        let rec loop = () =>
          asyncIterator.next()
          ->Promise.thenResolve(eventOpt =>
            eventOpt->Option.mapWithDefault((), event => {
              if !canceledRef.contents {
                switch event {
                | RoomEvent(rId, roomEvent) =>
                  if roomId == rId {
                    setRoomEvents(events => events->Belt.Array.concat([roomEvent]))
                  }
                }
                loop()
              }
            })
          )
          ->ignore

        loop()

        Some(() => canceledRef.contents = true)
      }),
    )
    ->Result.getWithDefault(None)
  }, (asyncIteratorRes, setRoomEvents, roomId))

  asyncIteratorRes->Result.map(_ => ())
}

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
  let roomId = Jotai.React.useReadable(Authentication.roomId)
  let events =
    roomId
    ->Result.map(id => Jotai.React.useReadable(roomEventsState(id)))
    ->Result.mapError(err => AuthError(err))
  let syncRes = roomId->Result.flatMap(id => useSync(id))
  let currentUserId = Jotai.React.useReadable(Authentication.currentUserId)
  let matrixClient = Jotai.React.useReadable(Authentication.matrixClient)

  let listRef = React.useRef(Js.Nullable.null)

  let messages = React.useMemo2(() => {
    currentUserId
    ->Result.mapError(err => AuthError(err))
    ->Result.flatMap(userIdOpt =>
      userIdOpt->Option.mapWithDefault(Error(NotAuthenticated), userId => {
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

  let setSessionCounter = Jotai.React.useWritable(Authentication.sessionCounterState)
  let setLoginToken = Jotai.React.useWritable(Authentication.loginTokenState)

  let handleLogoutPress = React.useCallback2(_ => {
    Confirm.confirm(`Es-tu sûr ?`, () => {
      CrossSecureStore.removeItem("accessToken")
      ->Promise.thenResolve(res => {
        if res->Result.isOk {
          setLoginToken(_ => None)
          setSessionCounter(v => v + 1)
        }
      })
      ->ignore
    })
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
