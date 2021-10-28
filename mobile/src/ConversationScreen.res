open ReactNative
open Style

type variant = Sent | Received

let messages = Belt.Array.reverse([
  (
    Sent,
    `Hello 👋,
Ça route.`,
  ),
  (Received, `Deuxième Message`),
  (Received, "3eme Message"),
  (Received, "4eme Message"),
])

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
          | Sent => Colors.primary
          | Received => j`#DEDEDE`
          },
          (),
        )}>
        <Text
          style={textStyle(
            ~fontSize=16.,
            ~color=switch variant {
            | Sent => Color.white
            | Received => Color.black
            },
            (),
          )}>
          {React.string(text)}
        </Text>
      </View>
    </View>
}

@react.component
let make = () => {
  let (text, setText) = React.useState(_ => "")

  <View style={viewStyle(~flex=1., ~backgroundColor=Color.plum, ())}>
    <ReactNativeSafeAreaContext.SafeAreaView edges=[#top] />
    <KeyboardAvoidingView behavior=#padding style={viewStyle(~flex=1., ())}>
      <FlatList
        style={viewStyle(~flex=1., ~backgroundColor=Color.white, ())}
        contentContainerStyle={viewStyle(~paddingVertical=10.->dp, ())}
        data={messages}
        renderItem={({item: (variant, text)}) => <Message variant text />}
        keyExtractor={((_, message), _) => message}
      />
      <View
        style={viewStyle(
          ~backgroundColor=Color.plum,
          ~paddingVertical=5.->dp,
          ~flexDirection=#row,
          (),
        )}>
        <TextInput
          style={textStyle(
            ~flex=1.,
            ~backgroundColor=Color.white,
            ~borderRadius=5.,
            ~fontSize=14.,
            ~marginHorizontal=10.->dp,
            ~paddingVertical=5.->dp,
            ~paddingHorizontal=7.->dp,
            (),
          )}
          multiline={true}
          value={text}
          onChangeText={text => setText(_ => text)}
        />
        <Icon.Feather name="send" size={24.->dp} style={viewStyle(~marginRight=10.->dp, ())} />
      </View>
    </KeyboardAvoidingView>
    <ReactNativeSafeAreaContext.SafeAreaView edges=[#bottom] />
  </View>
}
