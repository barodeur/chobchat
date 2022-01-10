let mergeResultErrors2 = (resA, resB) =>
  [resA->Result.getErrorWithDefault([]), resB->Result.getErrorWithDefault([])]
  ->Belt.Array.concatMany
  ->Result.error
