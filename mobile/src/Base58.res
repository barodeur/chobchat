include BaseX.Make({
  type digit = char
  let hash = Char.code
  let eq = Char.equal
  let alphabet =
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    ->Js.String2.split("")
    ->ArrayX.map(String.get(_, 0))
})
