open ReactNative

module SendButton = {
  @react.component
  let make = (~style) =>
    <ReactSpring.View style={style}>
      {<Image
        style={Style.imageStyle(~width=28.->Style.dp, ~height=28.->Style.dp, ~tintColor="#fff", ())}
        source={ReactNative.Image.Source.fromRequired(Packager.require("./reindeer.png"))}
      />}
    </ReactSpring.View>
}

@react.component
let make = (~value, ~onValueChange, ~onSubmit, ~sending as _) => {
  let (submitSequence, setSubmitSequence) = React.useState(_ => 0)
  let transitions = ReactSpring.useTransition3(.
    [submitSequence],
    ReactSpring.transition3Config(
      ~from=ReactSpring.transition3Style(~a=0., ~b=0., ~c=0.),
      ~enter=ReactSpring.transition3Style(~a=1., ~b=1., ~c=0.),
      ~leave=ReactSpring.transition3Style(~a=1., ~b=1., ~c=100.),
      (),
    ),
  )

  let handleSubmit = React.useCallback2(() => {
    setSubmitSequence(v => v + 1)
    onSubmit()
  }, (setSubmitSequence, onSubmit))

  let handleSubmitEditing = React.useCallback1(_ => {
    handleSubmit()
  }, [handleSubmit])

  let handleSendPress = React.useCallback1(_ => {
    handleSubmit()
  }, [handleSubmit])

  <View
    style={
      open Style
      viewStyle(
        ~backgroundColor=Colors.green,
        ~paddingVertical=5.->dp,
        ~paddingHorizontal=10.->dp,
        ~flexDirection=#row,
        ~overflow=#hidden,
        (),
      )
    }>
    <TextInput
      style={
        open Style
        [
          textStyle(
            ~flex=1.,
            ~backgroundColor=Color.white,
            ~borderRadius=30.,
            ~fontSize=14.,
            ~paddingVertical=5.->dp,
            ~paddingHorizontal=7.->dp,
            ~marginRight=10.->dp,
            (),
          ),
          {
            switch PlatformX.platform {
            | Web(_) => {"outlineStyle": "none"}
            | _ => Js.Obj.empty()
            }
          }->unsafeStyle,
        ]->Style.array
      }
      multiline={false}
      returnKeyType=#send
      onSubmitEditing=handleSubmitEditing
      value
      onChangeText={text => onValueChange(text)}
    />
    <Pressable onPress=handleSendPress>
      {({pressed: _}) => <>
        <SendButton style={Style.viewStyle(~opacity=0., ())} />
        {transitions(.(styles, item) =>
          <SendButton
            key={item->Belt.Int.toString}
            style={Style.viewStyle(
              ~position=#absolute,
              ~left=0.->Style.dp,
              ~opacity=styles.a->ReactSpring.val,
              ~transform=[
                Style.scale(~scale=styles.b->ReactSpring.val),
                Style.translateX(~translateX=styles.c->ReactSpring.val),
              ],
              (),
            )}
          />
        )->React.array}
      </>}
    </Pressable>
  </View>
}
