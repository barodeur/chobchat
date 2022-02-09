let mergeResultErrors2 = (resA, resB) =>
  [resA->Result.getErrorWithDefault([]), resB->Result.getErrorWithDefault([])]
  ->ArrayX.flatten
  ->Result.error
