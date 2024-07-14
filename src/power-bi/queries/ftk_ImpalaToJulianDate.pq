(binaryData) =>
let
    // Your 12-byte binary data
    // binaryData = Binary.FromText("AAAAAAAAAADBiSUA", BinaryEncoding.Base64),
    // Get the last 4 bytes
    last4Bytes = Binary.Range(binaryData, 8, 4),
    // Convert the binary to a list of numbers
    listOfNumbers = Binary.ToList(last4Bytes),
    // Reverse the list of numbers
    reversedListOfNumbers = List.Reverse(listOfNumbers),
    // Convert the list of numbers to an integer
    number = List.Accumulate(reversedListOfNumbers, 0, (state, current) => state * 256 + current)
in
    number