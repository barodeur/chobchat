module Option = Belt.Option

@val external encodeURIComponent: string => string = "encodeURIComponent"

type client = {
  homeserverUrl: string,
  accessToken: option<string>,
}

type err =
  | MissingHomeserverUrl
  | MissingAuthToken
  | UnknownToken({message: string})
  | Forbidden({message: string})
  | LimitExceeded({message: string, retryAfter: Duration.t})
  | Unknown

let endpoint: (client, 'a) => string = (client, path) =>
  `${client.homeserverUrl}/_matrix/client/r0${path}`

let getAndDecodeString = (dict, key) => dict->Js.Dict.get(key)->Option.flatMap(Js.Json.decodeString)

let fetch = (client, ~method_=?, ~body=?, path) =>
  Fetch.fetchWithInit(
    client->endpoint(path),
    Fetch.RequestInit.make(
      ~method_?,
      ~body?,
      ~headers=Fetch.HeadersInit.makeWithDict(
        []
        ->Js.Array2.concat(
          client.accessToken->Belt.Option.mapWithDefault([], token => [
            ("Authorization", `Bearer ${token}`),
          ]),
        )
        ->Js.Dict.fromArray,
      ),
      (),
    ),
  )
  ->Promise.then(response => {
    response
    ->Fetch.Response.json
    ->Promise.thenResolve(Fetch.Response.ok(response) ? Result.ok : Result.error)
  })
  ->Promise.thenResolve(
    Result.mapError(_, jsonErr =>
      Js.Json.decodeObject(jsonErr)
      ->Option.flatMap(dict => {
        dict
        ->Js.Dict.get("errcode")
        ->Option.flatMap(Js.Json.decodeString)
        ->Option.map(errCode =>
          switch errCode {
          | "M_UNKNOWN_TOKEN" =>
            dict
            ->getAndDecodeString("error")
            ->Option.mapWithDefault(Unknown, message => UnknownToken({message: message}))
          | "M_FORBIDDEN" =>
            dict
            ->getAndDecodeString("error")
            ->Option.mapWithDefault(Unknown, message => Forbidden({message: message}))
          | _ => Unknown
          }
        )
      })
      ->Option.getWithDefault(Unknown)
    ),
  )

let createClient = (~accessToken=?, homeserverUrl) => {
  accessToken: accessToken,
  homeserverUrl: homeserverUrl,
}

module Account = {
  module WhoAmI = {
    type payload = {userId: string}
    let payloadCodec = Jzon.object1(
      ({userId}) => userId,
      userId => {userId: userId}->Ok,
      Jzon.field("user_id", Jzon.string),
    )
  }

  let whoAmI = client =>
    switch client {
    | {accessToken: None} => Promise.resolve(Result.Error(MissingAuthToken))
    | _ =>
      client
      ->fetch("/account/whoami")
      ->PResult.flatMap(json =>
        json->Jzon.decodeWith(WhoAmI.payloadCodec)->Result.mapError(_ => Unknown)->Promise.resolve
      )
    }
}

module Login = {
  type identityProvider = {id: string, name: string}
  type flow = SSO({identityProviders: array<identityProvider>}) | Other
  type payload = array<flow>

  let payloadCodec = Jzon.object1(
    flows => flows,
    flows => flows->Ok,
    Jzon.field(
      "flows",
      Jzon.array(
        Jzon.object2(
          flow =>
            switch flow {
            | SSO({identityProviders}) => ("m.login.sso", Some(identityProviders))
            | _ => ("unknown", None)
            },
          ((type_, identityProvidersOpt)) =>
            switch (type_, identityProvidersOpt) {
            | ("m.login.sso", Some(identityProviders)) =>
              SSO({identityProviders: identityProviders})->Ok
            | _ => Other->Ok
            },
          Jzon.field("type", Jzon.string),
          Jzon.field(
            "identity_providers",
            Jzon.array(
              Jzon.object2(
                ({id, name}) => (id, name),
                ((id, name)) => {id: id, name: name}->Ok,
                Jzon.field("id", Jzon.string),
                Jzon.field("name", Jzon.string),
              ),
            ),
          )->Jzon.optional,
        ),
      ),
    ),
  )

  let getFlows = client => {
    client
    ->fetch("/login")
    ->PResult.flatMap(json =>
      json->Jzon.decodeWith(payloadCodec)->Result.mapError(_ => Unknown)->Promise.resolve
    )
  }

  let getSsoRedirectUrl = (client, ipId, ~redirectUrl) =>
    client->endpoint(`/login/sso/redirect/${ipId}?redirectUrl=${redirectUrl}`)

  module LoginWithToken = {
    type input = {token: string, deviceId: option<string>}
    let inputCodec = Jzon.object4(
      ({token, deviceId}) => ("m.login.token", token, deviceId, "ChobChat"),
      ((_, token, deviceId, _)) => {token: token, deviceId: deviceId}->Ok,
      Jzon.field("type", Jzon.string),
      Jzon.field("token", Jzon.string),
      Jzon.field("device_id", Jzon.string)->Jzon.optional,
      Jzon.field("initial_device_display_name", Jzon.string),
    )

    type payload = {accessToken: string}

    let payloadCodec = Jzon.object1(
      ({accessToken}) => accessToken,
      accessToken => {accessToken: accessToken}->Ok,
      Jzon.field("access_token", Jzon.string),
    )
  }

  let loginWithToken = (client, input) =>
    client
    ->fetch(
      "/login",
      ~method_=Post,
      ~body=Fetch.BodyInit.make(input->Jzon.encodeStringWith(LoginWithToken.inputCodec)),
    )
    ->PResult.flatMap(json =>
      json
      ->Jzon.decodeWith(LoginWithToken.payloadCodec)
      ->Result.mapError(_ => Unknown)
      ->Promise.resolve
    )
}

module RoomEvent = {
  module UnsignedData = {
    type t = {age: option<Duration.t>}

    let codec = Jzon.object1(
      ({age}) => age,
      age => {age: age}->Ok,
      Jzon.field("age", Duration.codec)->Jzon.optional,
    )
  }

  module RoomMessage = {
    type t = Text({body: string}) | Emote({body: string})

    let codec = Jzon.object2(
      message =>
        switch message {
        | Text({body}) => ("m.text", body)
        | Emote({body}) => ("m.emote", body)
        },
      ((msgtype, body)) => {
        switch msgtype {
        | "m.text" => Ok(Text({body: body}))
        | "m.emote" => Ok(Emote({body: body}))
        | _ => Error(#UnexpectedJsonValue([Field("msgtype")], msgtype))
        }
      },
      Jzon.field("msgtype", Jzon.string),
      Jzon.field("body", Jzon.string),
    )
  }

  module RoomName = {
    type t = string

    let codec = Jzon.object1(name => name, name => name->Ok, Jzon.field("name", Jzon.string))
  }

  module RoomPinedEvents = {
    type t = array<string>
  }

  type content =
    | RoomMessage(RoomMessage.t)
    | RoomName(RoomName.t)

  type t = {id: string, sender: string, content: content, unsigned: UnsignedData.t}

  let codec = Jzon.object5(
    ({id, sender, content, unsigned}) => (
      id,
      sender,
      switch content {
      | RoomMessage(_) => "m.room.message"
      | RoomName(_) => "M.room.name"
      },
      switch content {
      | RoomMessage(message) => message->Jzon.encodeWith(RoomMessage.codec)
      | RoomName(name) => name->Jzon.encodeWith(RoomName.codec)
      },
      unsigned,
    ),
    ((id, sender, type_, contentJson, unsigned)) => {
      let contentRes = switch type_ {
      | "m.room.message" =>
        contentJson->Jzon.decodeWith(RoomMessage.codec)->Belt.Result.map(m => RoomMessage(m))
      | "m.room.name" =>
        contentJson->Jzon.decodeWith(RoomName.codec)->Belt.Result.map(n => RoomName(n))
      | _ => Error(#UnexpectedJsonValue([Field("type")], type_))
      }

      contentRes->Belt.Result.map(content => {
        id: id,
        sender: sender,
        content: content,
        unsigned: unsigned,
      })
    },
    Jzon.field("event_id", Jzon.string),
    Jzon.field("sender", Jzon.string),
    Jzon.field("type", Jzon.string),
    Jzon.field("content", Jzon.json),
    Jzon.field("unsigned", UnsignedData.codec),
  )
}

module Room = {
  module GetMessages = {
    type payload = {
      start: string,
      end: string,
      chunk: array<RoomEvent.t>,
    }

    let arrayFilter: Jzon.codec<'a> => Jzon.codec<array<'a>> = codec =>
      Jzon.custom(
        array => array->Belt.Array.map(v => v->Jzon.encodeWith(codec))->Js.Json.array,
        json =>
          json
          ->Js.Json.decodeArray
          ->Belt.Option.map(arr =>
            arr->Belt.Array.keepMap(json => {
              json->Jzon.decodeWith(codec)->Belt.Result.mapWithDefault(None, v => Some(v))
            })
          )
          ->Belt.Option.mapWithDefault(Error(#UnexpectedJsonValue([], "")), v => Ok(v)),
      )

    let codec = Jzon.object3(
      ({start, end, chunk}) => (start, end, chunk),
      ((start, end, chunk)) => {start: start, end: end, chunk: chunk}->Ok,
      Jzon.field("start", Jzon.string),
      Jzon.field("end", Jzon.string),
      Jzon.field("chunk", RoomEvent.codec->arrayFilter),
    )
  }

  let getMessages = (client, roomId) =>
    client
    ->fetch(`/rooms/${roomId}/messages?dir=b`)
    ->PResult.flatMap(json =>
      json->Jzon.decodeWith(GetMessages.codec)->Result.mapError(_ => Unknown)->Promise.resolve
    )
}

module Event = {
  type t = RoomEvent((string, RoomEvent.t))
}

module Filter = {
  @deriving(abstract)
  type roomFilter = {@optional rooms: array<string>}

  @deriving(abstract)
  type t = {@optional room: roomFilter}

  let codec = Jzon.object1(
    filter => filter->roomGet,
    room => t(~room?, ())->Ok,
    Jzon.field(
      "room",
      Jzon.object1(
        roomFilter => roomFilter->roomsGet,
        rooms => roomFilter(~rooms?, ())->Ok,
        Jzon.field("rooms", Jzon.array(Jzon.string))->Jzon.optional,
      ),
    )->Jzon.optional,
  )
}

module Sync = {
  type timeline = {events: array<RoomEvent.t>}
  type joinedRoom = {timeline: timeline}
  type rooms = {join: Js.Dict.t<joinedRoom>}
  type payload = {nextBatch: string, rooms: option<rooms>}

  let timelineCodec = Jzon.object1(
    ({events}) => events,
    events => {events: events}->Ok,
    Jzon.field("events", RoomEvent.codec->Room.GetMessages.arrayFilter),
  )

  let joinedRoomCodec = Jzon.object1(
    ({timeline}) => timeline,
    timeline => {timeline: timeline}->Ok,
    Jzon.field("timeline", timelineCodec),
  )

  let roomsCodec = Jzon.object1(
    ({join}) => join,
    join => {join: join}->Ok,
    Jzon.field("join", joinedRoomCodec->Jzon.dict),
  )

  let payloadCodec = Jzon.object2(
    ({nextBatch, rooms}) => (nextBatch, rooms),
    ((nextBatch, rooms)) => {nextBatch: nextBatch, rooms: rooms}->Ok,
    Jzon.field("next_batch", Jzon.string),
    Jzon.field("rooms", roomsCodec)->Jzon.optional,
  )

  let sync = (client, ~since=?, ~timeout=10000, ~filter=?, ()) =>
    client
    ->fetch(
      "/sync?"->Js.String2.concat(
        [
          ("since", since),
          ("timeout", Some(timeout->Belt.Int.toString)),
          ("filter", filter->Belt.Option.map(filter => Filter.codec->Jzon.encodeString(filter))),
        ]
        ->Belt.Array.keepMap(((key, opt)) => opt->Belt.Option.map(v => `${key}=${v}`))
        ->Belt.Array.joinWith("&", v => v),
      ),
    )
    ->PResult.flatMap(json =>
      json->Jzon.decodeWith(payloadCodec)->Result.mapError(_ => Unknown)->Promise.resolve
    )
}

// type action = Continue(option<string>) | Break
let createSyncObservable = (client, ~filter=?, ()) => {
  Rx.Observable.make(subscriber => {
    let rec loop: option<string> => Promise.t<unit> = since => {
      client
      ->Sync.sync(~since?, ~filter?, ())
      ->Promise.then(res => {
        res->Belt.Result.mapWithDefault(Promise.resolve(), payload => {
          payload.rooms->Belt.Option.mapWithDefault((), rooms =>
            rooms.join
            ->Js.Dict.entries
            ->Belt.Array.map(((roomId, {timeline})) =>
              timeline.events->Belt.Array.map(event => Event.RoomEvent(roomId, event))
            )
            ->Belt.Array.concatMany
            ->Belt.Array.forEach(event => subscriber->Rx.Subscriber.next(event))
          )
          loop(Some(payload.nextBatch))->ignore
          Promise.resolve()
        })
      })
    }

    loop(None)->ignore

    None
  })
}

let generateTransactionId = () => Crypto.generateRandomBase58(16)

module SendMessage = {
  type input = string

  let inputCodec = Jzon.object2(
    body => ("m.text", body),
    ((_, body)) => body->Ok,
    Jzon.field("msgtype", Jzon.string),
    Jzon.field("body", Jzon.string),
  )

  let send = (client, roomId, body) => {
    let txId = generateTransactionId()
    client->fetch(
      `/rooms/${roomId->encodeURIComponent}/send/m.room.message/${txId}`,
      ~method_=Put,
      ~body=Fetch.BodyInit.make(body->Jzon.encodeStringWith(inputCodec)),
    )
  }
}
