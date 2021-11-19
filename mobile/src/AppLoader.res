open ReactNative

module Transition = {
  type state = Fallback | Children
  @react.component
  let make = (~children, ~fallback) => {
    let (item, setItem) = React.useState(_ => Fallback)
    let transitions = ReactSpring.useTransition1(.
      [item],
      ReactSpring.transition1Config(
        ~from=ReactSpring.transition1Style(~a=1.),
        ~enter=ReactSpring.transition1Style(~a=1.),
        ~leave=ReactSpring.transition1Style(~a=0.),
        ~config=ReactSpring.Config.molasses,
        (),
      ),
    )

    React.useEffect0(() => {
      setItem(_ => Children)
      None
    })

    transitions(.(styles, item) =>
      switch item {
      | Fallback =>
        <ReactSpring.View
          style={[
            StyleSheet.absoluteFill,
            Style.viewStyle(~zIndex=100, ~opacity=styles.a->ReactSpring.val, ()),
          ]->Style.array}>
          fallback
        </ReactSpring.View>
      | Children =>
        <ReactSpring.View
          style={[StyleSheet.absoluteFill, Style.viewStyle(~zIndex=0, ())]->Style.array}>
          children
        </ReactSpring.View>
      }
    )->React.array
  }
}

ExpoSplashScreen.preventAutoHideAsync()->ignore

@react.component
let make = (~children) => {
  React.useEffect0(() => {
    ExpoSplashScreen.hideAsync()->ignore
    None
  })

  <React.Suspense fallback={<AppLoading />}> {children} </React.Suspense>
}
