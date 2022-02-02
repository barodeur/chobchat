open ReactNative

module Icon = {
  type makeProps = {"color": Color.t}
}

@react.component
let make = (
  ~title,
  ~onPress,
  ~color=Color.black,
  ~iconComponent: option<React.component<Icon.makeProps>>=?,
) =>
  <Pressable
    onPress
    style={({pressed}) =>
      Style.viewStyle(
        ~backgroundColor={
          if pressed {
            "rgba(0,0,0,0.05)"
          } else {
            "white"
          }
        },
        ~paddingHorizontal=18.->Style.dp,
        ~paddingVertical=10.->Style.dp,
        ~flexDirection=#row,
        ~alignItems=#center,
        (),
      )}>
    {_ => <>
      {iconComponent->Belt.Option.mapWithDefault(React.null, comp =>
        <View style={Style.viewStyle(~marginRight=10.->Style.dp, ())}>
          {React.createElement(comp, {"color": color})}
        </View>
      )}
      <TextX style={Style.textStyle(~fontSize=18., ~color, ())}> {title->React.string} </TextX>
    </>}
  </Pressable>
