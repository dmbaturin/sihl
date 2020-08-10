let strip_chars s cs =
  let len = String.length s in
  let res = Bytes.create len in
  let rec aux i j =
    if i >= len then Bytes.to_string (Bytes.sub res 0 j)
    else if String.contains cs s.[i] then aux (succ i) j
    else (
      Bytes.set res j s.[i];
      aux (succ i) (succ j) )
  in
  aux 0 0
