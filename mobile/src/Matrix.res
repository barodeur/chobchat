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
  | ParserError(Jzon.DecodingError.t)
  | Unknown

module UserId = {
  type t = UserId(string)

  let fromString = str => UserId(str)
  let toString = (UserId(str)) => str

  let codec = Jzon.custom(
    id => id->toString->Jzon.encodeWith(Jzon.string),
    json => json->Jzon.decodeWith(Jzon.string)->Result.map(id => UserId(id)),
  )
}

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
        [("Accept", "application/json"), ("Content-Type", "application/json")]
        ->ArrayX.concat(
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
    type payload = {userId: UserId.t}
    let payloadCodec = Jzon.object1(
      ({userId}) => userId,
      userId => {userId: userId}->Ok,
      Jzon.field("user_id", UserId.codec),
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

module RoomId = {
  type t = RoomId(string)

  let fromString = str => RoomId(str)
  let toString = (RoomId(str)) => str
  let equal = (a, b) => String.equal(a->toString, b->toString)
}

module EventContent = {
  module Name = {
    type t = {name: string}

    let typeStr = "m.room.name"

    let codec = Jzon.object1(
      ({name}) => name,
      name => {name: name}->Ok,
      Jzon.field("name", Jzon.string),
    )
  }

  module Message = {
    type t = Text({body: string}) | Emote({body: string})

    let typeStr = "m.room.message"

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

  module Member = {
    type t = {displayname: string, membership: string}

    let typeStr = "m.room.member"

    let codec = Jzon.object2(
      ({displayname, membership}) => (displayname, membership),
      ((displayname, membership)) => {displayname: displayname, membership: membership}->Ok,
      Jzon.field("displayname", Jzon.string),
      Jzon.field("membership", Jzon.string),
    )
  }

  type t = Name(Name.t) | Message(Message.t) | Member(Member.t)

  let typeStr = content =>
    switch content {
    | Name(_) => Name.typeStr
    | Message(_) => Message.typeStr
    | Member(_) => Member.typeStr
    }

  let toJson = content =>
    switch content {
    | Name(name) => name->Jzon.encodeWith(Name.codec)
    | Message(message) => message->Jzon.encodeWith(Message.codec)
    | Member(member) => member->Jzon.encodeWith(Member.codec)
    }

  let fromJson = (type_, json) =>
    switch type_ {
    | "m.room.name" => json->Jzon.decodeWith(Name.codec)->Result.map(name => Name(name))
    | "m.room.message" =>
      json->Jzon.decodeWith(Message.codec)->Result.map(message => Message(message))
    | "m.room.member" => json->Jzon.decodeWith(Member.codec)->Result.map(member => Member(member))
    | _ => Error(#UnexpectedJsonValue([Field("type")], type_))
    }
}

module SyncStateEvent = {
  type t = {
    eventId: string,
    sender: UserId.t,
    stateKey: string,
    content: EventContent.t,
    originServerTs: float,
  }

  let codec = Jzon.object6(
    ({eventId, sender, stateKey, content, originServerTs}) => (
      content->EventContent.typeStr,
      eventId,
      sender,
      stateKey,
      content->EventContent.toJson,
      originServerTs,
    ),
    ((type_, eventId, sender, stateKey, contentJson, originServerTs)) => {
      let contentRes = EventContent.fromJson(type_, contentJson)
      contentRes->Belt.Result.map(content => {
        {
          eventId: eventId,
          sender: sender,
          stateKey: stateKey,
          content: content,
          originServerTs: originServerTs,
        }
      })
    },
    Jzon.field("type", Jzon.string),
    Jzon.field("event_id", Jzon.string),
    Jzon.field("sender", UserId.codec),
    Jzon.field("state_key", Jzon.string),
    Jzon.field("content", Jzon.json),
    Jzon.field("origin_server_ts", Jzon.float),
  )
}

module UnsignedData = {
  type t = {age: option<Duration.t>}

  let codec = Jzon.object1(
    ({age}) => age,
    age => {age: age}->Ok,
    Jzon.field("age", Duration.codec)->Jzon.optional,
  )
}

module SyncRoomEvent = {
  module RoomName = {
    type t = string

    let codec = Jzon.object1(name => name, name => name->Ok, Jzon.field("name", Jzon.string))
  }

  type t = {
    id: string,
    sender: UserId.t,
    content: EventContent.t,
    unsigned: UnsignedData.t,
    originServerTs: float,
  }

  let codec = Jzon.object6(
    ({id, sender, content, unsigned, originServerTs}) => (
      id,
      sender,
      content->EventContent.typeStr,
      content->EventContent.toJson,
      unsigned,
      originServerTs,
    ),
    ((id, sender, type_, contentJson, unsigned, originServerTs)) => {
      let contentRes = EventContent.fromJson(type_, contentJson)
      contentRes->Belt.Result.map(content => {
        id: id,
        sender: sender,
        content: content,
        unsigned: unsigned,
        originServerTs: originServerTs,
      })
    },
    Jzon.field("event_id", Jzon.string),
    Jzon.field("sender", UserId.codec),
    Jzon.field("type", Jzon.string),
    Jzon.field("content", Jzon.json),
    Jzon.field("unsigned", UnsignedData.codec),
    Jzon.field("origin_server_ts", Jzon.float),
  )
}

// module Event = {
//   type t = RoomEvent((string, RoomEvent.t))
// }

module Filter = {
  module State = {
    @deriving(abstract)
    type t = {@optional includeRedundantMembers: bool}

    let codec = Jzon.object1(
      filter => filter->includeRedundantMembersGet,
      includeRedundantMembers => t(~includeRedundantMembers?, ())->Ok,
      Jzon.field("include_redundant_members", Jzon.bool)->Jzon.optional,
    )
  }

  module Room = {
    @deriving(abstract)
    type t = {@optional rooms: array<string>, @optional state: State.t}

    let codec = Jzon.object2(
      filter => (filter->roomsGet, filter->stateGet),
      ((rooms, state)) => t(~rooms?, ~state?, ())->Ok,
      Jzon.field("rooms", Jzon.array(Jzon.string))->Jzon.optional,
      Jzon.field("state", State.codec)->Jzon.optional,
    )
  }

  @deriving(abstract)
  type t = {@optional room: Room.t}

  let codec = Jzon.object1(
    filter => filter->roomGet,
    room => t(~room?, ())->Ok,
    // Jzon.field("include_redundant_members", Jzon.bool)->Jzon.optional,
    Jzon.field("room", Room.codec)->Jzon.optional,
  )
}

let arrayFilter: Jzon.codec<'a> => Jzon.codec<array<'a>> = codec =>
  Jzon.custom(
    array => array->ArrayX.map(v => v->Jzon.encodeWith(codec))->Js.Json.array,
    json =>
      json
      ->Js.Json.decodeArray
      ->Belt.Option.map(arr =>
        arr->ArrayX.keepMap(json => {
          json->Jzon.decodeWith(codec)->Belt.Result.mapWithDefault(None, v => Some(v))
        })
      )
      ->Belt.Option.mapWithDefault(Error(#UnexpectedJsonValue([], "")), v => Ok(v)),
  )

module State = {
  type t = {events: array<SyncStateEvent.t>}

  let codec = Jzon.object1(
    ({events}) => events,
    events => {events: events}->Ok,
    Jzon.field("events", SyncStateEvent.codec->arrayFilter),
  )
}

module Timeline = {
  type t = {events: array<SyncRoomEvent.t>}

  let codec = Jzon.object1(
    ({events}) => events,
    events => {events: events}->Ok,
    Jzon.field("events", SyncRoomEvent.codec->arrayFilter),
  )
}

module JoinedRoom = {
  type t = {state: State.t, timeline: Timeline.t}

  let codec = Jzon.object2(
    ({state, timeline}) => (state, timeline),
    ((state, timeline)) => {state: state, timeline: timeline}->Ok,
    Jzon.field("state", State.codec),
    Jzon.field("timeline", Timeline.codec),
  )
}

module Rooms = {
  type t = {join: Js.Dict.t<JoinedRoom.t>}

  let codec = Jzon.object1(
    ({join}) => join,
    join => {join: join}->Ok,
    Jzon.field("join", JoinedRoom.codec->Jzon.dict),
  )
}

module Sync = {
  module Payload = {
    type t = {nextBatch: string, rooms: option<Rooms.t>}

    let codec = Jzon.object2(
      ({nextBatch, rooms}) => (nextBatch, rooms),
      ((nextBatch, rooms)) => {nextBatch: nextBatch, rooms: rooms}->Ok,
      Jzon.field("next_batch", Jzon.string),
      Jzon.field("rooms", Rooms.codec)->Jzon.optional,
    )
  }

  let sync = (client, ~since=?, ~timeout=10000, ~filter=?, ~fullState=?, ()) =>
    client
    ->fetch(
      "/sync?"->Js.String2.concat(
        [
          ("since", since),
          ("timeout", Some(timeout->Belt.Int.toString)),
          ("filter", filter->Belt.Option.map(Jzon.encodeStringWith(_, Filter.codec))),
          ("full_state", fullState->Belt.Option.map(Jzon.encodeStringWith(_, Jzon.bool))),
        ]
        ->ArrayX.keepMap(((key, opt)) => opt->Belt.Option.map(v => `${key}=${v}`))
        ->ArrayX.joinWith("&"),
      ),
    )
    ->PResult.flatMap(json =>
      json
      ->Jzon.decodeWith(Payload.codec)
      ->Result.mapError(err => ParserError(err))
      ->Promise.resolve
    )
}

let createSyncAsyncIterator = (client, ~filter=?, ()) => {
  AsyncIterator.sequence()->AsyncIterator.scan((state, _) => {
    let since = state.contents
    client
    ->Sync.sync(~since?, ~filter?, ~fullState=since->Belt.Option.isNone, ())
    ->Promise.then(res => {
      res->Belt.Result.mapWithDefault(res->Promise.resolve, payload => {
        state.contents = Some(payload.nextBatch)
        res->Promise.resolve
      })
    })
  }, None)
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
      `/rooms/${roomId->RoomId.toString->encodeURIComponent}/send/m.room.message/${txId}`,
      ~method_=Put,
      ~body=Fetch.BodyInit.make(body->Jzon.encodeStringWith(inputCodec)),
    )
  }
}
