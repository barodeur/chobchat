include Js.Array2

let {concatMany: flatten, get, keepMap, make, reverse, zip} = module(Belt.Array)
let last = arr => arr->get(arr->length - 1)
