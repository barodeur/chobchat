module StackParams = {
  type params = {roomId: Matrix.RoomId.t}
}

include ReactNavigation.Stack.Make(StackParams)
