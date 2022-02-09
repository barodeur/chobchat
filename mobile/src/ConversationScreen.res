open ReactNative
open Style

type variant = Sent | Received

type message = {
  id: string,
  body: string,
  sender: Matrix.UserId.t,
  variant: variant,
  age: Duration.t,
}

type err = AuthError(Authentication.err) | NotAuthenticated

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
        ? <TextX style={Style.textStyle(~color="#00000060", ())}>
            {sender->Matrix.UserId.toString->React.string}
          </TextX>
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
let make = (~navigation as _, ~route: RootStack.route) => {
  let roomId = route.params->Option.map(params => params.roomId)->Option.getExn // Get roomId from navigation state
  let events = Jotai.React.useAtomValue(MatrixState.roomEvents(roomId))->Ok
  let syncRes = Ok()
  let currentUserId = Jotai.React.useAtomValue(Authentication.currentUserId)
  let matrixClient = Jotai.React.useAtomValue(Authentication.matrixClient)

  let listRef = React.useRef(Js.Nullable.null)

  let messages = React.useMemo2(() => {
    currentUserId
    ->Result.mapError(err => AuthError(err))
    ->Result.flatMap(userIdOpt =>
      userIdOpt->Option.mapWithDefault(Error(NotAuthenticated), userId => {
        events->Result.map(opt =>
          opt
          ->ArrayX.keepMap(({id, sender, content, unsigned: {age}}) =>
            switch (content, age) {
            | (Message(Text({body})), Some(age)) =>
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
          ->(inverted ? ArrayX.reverse : arr => arr)
        )
      })
    )
  }, (currentUserId, events))

  React.useEffect1(() => {
    switch listRef.current->Js.Nullable.toOption {
    | None => ()
    | Some(ref) => Timeout.set(() => {
        if !inverted {
          ref->FlatList.scrollToEnd
        }
        ()
      }, 100)->ignore
    }
    None
  }, [messages])

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

  syncRes->Result.mapWithDefault(
    <Text> {"Impossible de synchroniser les messages"->React.string} </Text>,
    _ =>
      <View style={viewStyle(~flex=1., ~backgroundColor=Colors.green, ())}>
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
