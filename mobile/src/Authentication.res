open ReactNative
// module Text = TextX

type err = NotAuthenticated

module IdentityProviderButton = {
  @react.component
  let make = (~name, ~style=?, ~redirectUrl) =>
    <Pressable
      style={({pressed}) =>
        [
          Style.viewStyle(
            ~paddingVertical=6.->Style.dp,
            ~paddingHorizontal=10.->Style.dp,
            ~borderWidth=1.,
            ~borderColor=Color.white,
            ~backgroundColor={Color.rgba(~r=255, ~g=255, ~b=255, ~a=pressed ? 0.2 : 0.)},
            ~borderRadius=5.,
            (),
          )->Option.some,
          style,
        ]->Style.arrayOption}
      onPress={_ => {
        ExpoLinking.openURL(redirectUrl)
        ()
      }}>
      {_ =>
        <TextX
          style={Style.textStyle(~color=Color.white, ~fontSize=16., ())}
          accessibilityRole=#link
          href={redirectUrl}>
          {`Se connecter avec ${name}`->React.string}
        </TextX>}
    </Pressable>
}

module Flow = {
  @react.component
  let make = (~matrixClient: Matrix.client, ~flow: Matrix.Login.flow, ~redirectUrl) =>
    switch flow {
    | SSO({identityProviders}) =>
      identityProviders
      ->Js.Array2.map(({id, name}) =>
        <IdentityProviderButton
          style={Style.viewStyle(~alignSelf=#center, ())}
          key=id
          name
          redirectUrl={matrixClient->Matrix.Login.getSsoRedirectUrl(id, ~redirectUrl)}
        />
      )
      ->React.array
    | Other => React.null
    }
}

module Flows = {
  let loginTokenCodec = Jzon.object1(
    loginToken => loginToken,
    loginToken => loginToken->Ok,
    Jzon.field("loginToken", Jzon.string)->Jzon.optional,
  )

  let redirectUrl = ExpoLinking.createURL(. "/")

  @react.component
  let make = () => {
    let url = ExpoLinking.useURL()
    let queryParams =
      url->Belt.Option.map(url => url->ExpoLinking.URL.parse->ExpoLinking.URL.queryParams)
    let router = Router.useRouter()
    let queryLoginToken =
      queryParams->Belt.Option.flatMap(params =>
        params->Jzon.decodeWith(loginTokenCodec)->Belt.Result.getWithDefault(None)
      )
    let matrixClient = Recoil.useRecoilValue(State.guestMatrixClient)
    let flows = Recoil.useRecoilValue(State.flows)
    let setLoginTokenState = Recoil.useSetRecoilState(State.loginTokenState)

    React.useEffect1(() => {
      setLoginTokenState(_ => queryLoginToken)
      router->Router.replace("/")
      None
    }, [queryLoginToken])

    <SafeAreaView
      style={Style.viewStyle(~flex=1., ~backgroundColor=Colors.green, ~justifyContent=#center, ())}>
      <Image
        style={Style.imageStyle(
          ~alignSelf=#center,
          ~width=80.->Style.dp,
          ~height=80.->Style.dp,
          ~borderRadius=12.,
          ~marginBottom=20.->Style.dp,
          (),
        )}
        source={ReactNative.Image.Source.fromRequired(Packager.require("../assets/icon.png"))}
      />
      {switch (matrixClient, flows) {
      | (Ok(client), Ok(flows)) =>
        flows
        ->Belt.Array.mapWithIndex((idx, flow) =>
          <Flow key={idx->Belt.Int.toString} flow redirectUrl matrixClient=client />
        )
        ->React.array
      | _ => <Text> {"Impossible de charger les flows"->React.string} </Text>
      }}
    </SafeAreaView>
  }
}

@react.component
let make = (~children) => {
  switch Recoil.useRecoilValue(State.currentUserId) {
  | Ok(None) => <Flows />
  | Ok(Some(_)) => children
  | _ => <Text> {"OOPS"->React.string} </Text>
  }
}
