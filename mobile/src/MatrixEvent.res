open ReactNative

type variant = Sent | Received

@react.component
let make = (~eventId) => {
  switch (
    Jotai.React.useAtomValue(MatrixState.event(eventId)),
    Jotai.React.useAtomValue(Authentication.currentUserId),
  ) {
  | (Some(event), Ok(Some(currentUserId))) => {
      let variant = if event.sender == currentUserId {
        Sent
      } else {
        Received
      }

      <View
        style={Style.viewStyle(
          ~paddingVertical=8.->Style.dp,
          ~paddingHorizontal=10.->Style.dp,
          ~alignItems=switch variant {
          | Sent => #flexEnd
          | Received => #flexStart
          },
          (),
        )}>
        {variant == Received
          ? <TextX style={Style.textStyle(~color="#00000060", ())}>
              {event.sender->Matrix.UserId.toString->React.string}
            </TextX>
          : React.null}
        <View
          style={Style.viewStyle(
            ~borderRadius=10.,
            ~paddingVertical=10.->Style.dp,
            ~paddingHorizontal=18.->Style.dp,
            ~backgroundColor=switch variant {
            | Sent => Colors.red
            | Received => j`#DEDEDE`
            },
            (),
          )}>
          <TextX
            style={Style.textStyle(
              ~fontFamily="Sniglet",
              ~fontSize=16.,
              ~color=switch variant {
              | Sent => Color.white
              | Received => Color.black
              },
              (),
            )}>
            {switch event.content {
            | Message(Text({body})) => body->React.string
            | _ => React.null
            }}
          </TextX>
        </View>
        {event.unsigned.age->Option.mapWithDefault(React.null, age =>
          <Duration
            duration=age
            style={Style.textStyle(~color="#00000060", ~fontSize=12., ~marginTop=2.->Style.dp, ())}
          />
        )}
      </View>
    }
  | _ => <View> <TextX> {"Could not load message"->React.string} </TextX> </View>
  }
}
